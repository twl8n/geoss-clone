
=head1 NAME
 
 geoss_load_available - loads array orders that have data files available

=head1 SYNOPSIS

 ./geoss_load_available [--interactive] [--chip_data_path=<chip_data_path>]
   [--readonly] [--debug]

=head1 DESCRIPTION

geoss_load_available can be used to load data for multiple orders.  It
only loads data for orders that are complete and locked (submitted)
and have data available in the specified chip_data_path.

=head1 OPTIONS

=item 
--interactive - prompts before loading each order

=item 
--readonly - lists all orders that would be loaded but does not
   actually load the orders

=item 
--debug - prints verbose messages while running

=item 
--chip_data_path - the script uses the chip data path from the configuration
table, but that path can be over-ridden using this option.  This allows
users to make data available from a different path.  


=cut

  use strict;
  use GEOSS::Database;
  use GEOSS::Terminal;
  use Getopt::Long 2.13;
  require "$LIB_DIR/geoss_session_lib";

  my $interactive; 
  my $readonly;
  my $debug;
  my $chip_data_path;

  getOptions();

  # set the chip_data_path if necessary
  if (! $chip_data_path)
  {
    $chip_data_path = get_config_entry($dbh, "chip_data_path");
  }
  print "Chip data path is: $chip_data_path\n" if ($debug);

  # determine the SUBMITTED orders
  my $sql = "select distinct(order_number), oi_pk from arraymeasurement,
  sample, order_info where smp_pk=smp_fk and oi_fk=oi_pk and (is_loaded='f'
   or is_loaded is NULL) and is_approved='t'";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql\n$DBI::errstr\n";
  $sth->execute() || die "Execute $sql\n$DBI::errstr\n";

  # foreach unloaded SUBMITTED order
  while (my ($order_num, $oi_pk) = $sth->fetchrow_array)
  {
    print "Processing $order_num (PK: $oi_pk)\n" if ($debug);
    # check if data files exist
    my $have_files = 1;
    # get all the hybridization names
    my $sth2 = getq("am_sample_order_info_unloaded", $dbh);
    $sth2->execute($oi_pk) || die "execute
      am_sample_order_info\n$DBI::errstr\n";
    my $hr;
    my @hybs_to_load;
    my %hybs_to_load_str;
    my $filesref;
    my %all_filesref;

    while ($hr = $sth2->fetchrow_hashref())
    {
      my $success;
      print "Processing am_pk: $hr->{am_pk}\n" if ($debug);
      push @hybs_to_load, $hr->{am_pk};
      $hybs_to_load_str{$hr->{am_pk}} = $hr->{hybridization_name};
      ($filesref, $success) = get_file_hash($dbh, "command", 
                $hr->{hybridization_name}, $chip_data_path);
      $all_filesref{$hr->{am_pk}} = $filesref;
      print "success for am_pk $hr->{am_pk} is $success\n" if ($debug);
      $have_files = 0 if ($success ne "");
    }

    # if all data files exist 
    if ($have_files)
    {
      print "Have files for $order_num.  Proceeding with load\n" if ($debug);
      # if readonly, print the order_number(oi_pk)
      my $proceed = 1;
      if ($readonly)
      {
         print "READONLY: Files available for data load of order $order_num
           (PK: $oi_pk)\n";
         $proceed = 0;
      }
      else
      {
         # if interactive, ask the user whether to load the order
         if ($interactive)
         {
           print "Would you like to load $order_num (PK: $oi_pk)?\n";
           print "(Y or N - default Y)\n";
           my $answer = <STDIN>;
           chomp($answer);
           if ((lc($answer) eq "n") ||
               (lc($answer) eq "no")) 
           {
             $proceed = 0;
           }
         }
      }
      print "Hybs to load: @hybs_to_load\n";
      if ($proceed)
      {
           my $success;
           print "Loading data for order $order_num (PK: $oi_pk)\n";
           my $new_filesref;
           my $am_pk;
           foreach $am_pk (@hybs_to_load)
           {
              ($success, $new_filesref) = prepare_load_brf($dbh, "command", 
                 {
                 "oi_pk" => $oi_pk,
                 "am_pk" => $am_pk, 
                 }, $all_filesref{$am_pk});

               if ($success eq "")
               {
                  my $startdate = `date +%s`;
                  chomp($startdate);
                  print "data load starts at $startdate\n";
                  doq($dbh, "set_is_loaded", $am_pk);
                  $dbh->commit();
                  print "Loading am_pk: $am_pk from txt $new_filesref->{txt} rpt
                  $new_filesref->{rpt} exp $new_filesref->{exp}\n" if ($debug);
                  $success = load_brf_data($dbh, "command", {
                    "am_pk" => $am_pk,
                    "rpt_file" => $new_filesref->{rpt},
                    "txt_file" => $new_filesref->{txt},
                    "exp_file" => $new_filesref->{exp},
                   });
                 my $endseconds = `date +%s`;
                 chomp($endseconds);
                 printf("Total time was %s seconds.\n", $endseconds -
                    $startdate);
              }
              else
              {
                print "Unable to load data: $success\n";
              }
           }
       }
       else
       {
           print "Not loading data for order $order_num due to user request.\n";
       }
     }  
     else
     {
        print "Do not have files to load $order_num.  Please place files in
        chip data path ($chip_data_path)\n";
     }
  }
  $dbh->disconnect(); 


### SUBROUTINES ###
sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
      'interactive!' => \$interactive,
      'readonly!' => \$readonly,
      'debug!' => \$debug,
      'chip_data_path=s' => \$chip_data_path,
      'help|?'      => \$help,
    );
  }
  usage() if $help;

  print "Running geoss_load_available with the following options:\n" if ($debug);
  print "  interactive\n" if (($debug) && ($interactive));
  print "  readonly\n" if (($debug) && ($readonly));
  print "  debug\n" if ($debug);
  print "  chip_data_path $chip_data_path\n" if (($debug) && ($chip_data_path));

  if ($chip_data_path)
  {
    if (! -r $chip_data_path)
    {
      die "Unable to read $chip_data_path :$!.  
        Please specify a valid chip data path.\n";
    }
  }

}

sub usage
{
      print "Usage: \n";
      print "./geoss_load_available [--interactive] [--readonly] [--debug]
        [--chip_data_path=<chip_data_path>] \n";
      exit;
} # usage

=head1 NOTES

=head1 AUTHOR

Teela James
