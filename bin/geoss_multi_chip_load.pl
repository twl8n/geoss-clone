
=head1 NAME
 
 geoss_multi_chip_load - loads muliple chips from a  file

=head1 SYNOPSIS

 ./geoss_multi_chip_load --chip_data_file=<chip_data_file> 
 --chip <al_pk | name> [--readonly] [--debug]

=head1 DESCRIPTION

geoss_multi_chip_load can be used to load data for mutliple chips 
from one file.  It only loads data for orders that are complete and locked
(submitted) and have data available in the specified chip_data_file.  The
data file should contain tab separated data.  The first column is the
probe set id.  Subsequent columns are chip data.  Each column must have a
valid hybridization name for a hybridization that has not yet been loaded.
Note that only signal data is provided/loaded.  This means there will be no
quality control information available for chips loaded using this script.

=head1 OPTIONS


=item 
--readonly - lists  hybridizations that will be loaded but does not load them

=item 
--debug - prints verbose messages while running

=item 
--chip_data_file - the file that contains the input data

=item 
--chip - the layout associated with the data.  Takes either an al_pk or a
name from the arraylayout table.

=cut

  use strict;
  use GEOSS::Database;
  use GEOSS::Terminal;
  use Getopt::Long 2.13;
  require "$LIB_DIR/geoss_session_lib";

  my $readonly;
  my $debug;
  my $chip;
  my $chip_data_file;

  getOptions();
  # open handle to database
  my $us_fk = "command";

  my $al_pk;
  if ($chip =~ /^\d+$/)
  {
    $al_pk = $chip;
  }
  else
  {
    $al_pk = getq_al_pk_by_name($dbh, $us_fk, $chip);
  }
  die "Invalid pk: $al_pk for $chip" if (! doq_exists_chip($dbh, $us_fk, $al_pk));

  open (INFILE, "$chip_data_file") || 
    die "Unable to open $chip_data_file:$!";
  my $firstline = <INFILE>; chomp $firstline;
  my @headers = split(/\t/, $firstline);
  my $i;
  my @headers_pk = ();
  for ($i = 1; $i <= $#headers; $i++)
  {
    my $am_pk = getq_am_pk_by_name($dbh, $us_fk, $headers[$i]); 
    die "Hybridization $headers[$i] doesn't exist.  Please fix input file." 
      if ($am_pk < 1);
    if (doq($dbh, "am_used_by_ams", $am_pk))
    {
       print "Hybridization $am_pk is already loaded. Aborting load.\n";
       $dbh->rollback();
       $dbh->disconnect();
    }
    push @headers_pk, $am_pk;
    print "Scheduling load for $headers[$i] ($am_pk)\n" if ($debug);
  }
  my $am_pk;
  foreach $am_pk (@headers_pk)
  {
     doq($dbh, "set_is_loaded", $am_pk);
  }

  my $line;
  my $num_lines;
  while ($line = <INFILE>)
  {
    chomp $line;
    $num_lines++;
    my @input = split(/\t/, $line);
    my $probe_id = shift @input;
    my $als_fk = getq_als_pk_by_al_fk_and_spot_id($dbh, $us_fk, $al_pk,
        $probe_id);
    my $signal;
    my $i =0;
    foreach $signal (@input)
    {
      my $am_pk = $headers_pk[$i];
      doq_insert_am_spots_mas5($dbh, $us_fk, $als_fk, $am_pk, $signal);
      $i++;
    }
    
    print "Processed $num_lines lines\n" if (($num_lines % 1000) == 0);
  }

  foreach $am_pk (@headers_pk)
  {
     doq($dbh, "set_date_loaded", $am_pk);
  }

  if ($readonly)
  {
    print "Rolling back changes due to readonly flag\n" if ($debug);
    $dbh->rollback();
  }
  else
  {
    print "Committing changes\n" if ($debug);
    $dbh->commit();
  }
  $dbh->disconnect();


### SUBROUTINES ###
sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
      'readonly!' => \$readonly,
      'debug!' => \$debug,
      'chip_data_file=s' => \$chip_data_file,
      'chip=s' => \$chip,
      'help|?'      => \$help,
    );
  }
  usage() if $help;
  usage() if (! $chip);
  usage() if (! $chip_data_file);

  print "Running geoss_multi_chip_load with the following options:\n" if ($debug);
  print "  readonly\n" if (($debug) && ($readonly));
  print "  debug\n" if ($debug);
  print "  chip_data_file $chip_data_file\n" if (($debug) && ($chip_data_file));
  print "  chip\n" if (($debug) && ($chip));

  if ($chip_data_file)
  {
    if (! -r $chip_data_file)
    {
      die "Unable to read $chip_data_file :$!.  
        Please specify a valid chip data path.\n";
    }
  }

}

sub usage
{
      print "Usage: \n";
      print "./geoss_multi_chip_load --chip_data_file=<chip_data_file> \
        --chip <al_pk | name> [--readonly] [--debug]\n";
      exit;
} # usage

=head1 NOTES

=head1 AUTHOR

Teela James
