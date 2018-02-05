
=head1 NAME
 
 geoss_bulk_configurator - facilitates bulk configuration of geoss data

=head1 SYNOPSIS
./geoss_bulk_configurator  --userpath <path (login id for a GEOSS user)> |
                           --path <path (containing subdirs for users)> 
                           [--readonly|--debug |--nolock]

=head1 DESCRIPTION

geoss_bulk_configurator will create studies and orders based on an 
input directory stucture and a set of input files.   A specific directory
structure, file naming conventions, and file content provide necessary 
information to configure studies, orders, experimental conditions, samples, 
and hybridizations.  In addition to this critical information, optional 
text files can be used to provide specific descriptive information.    
Please see GEOSS documentation for complete information and examples.  

=head1 OPTIONS

=item 
--readonly - lists all the studies and orders that would be created but
  does not create them

=item 
--debug - prints verbose messages while running

=item
--path <path> - path containing user subdirectories, which in turn contain
study subdirectories.  Used to load data for multiple users.

=item
--userpath <path (login ID)> - path containing study subdirectories.  Used to
load data for a single user.

=item
--nolock -  do not lock newly created orders


=cut

use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::Experiment::Study;
use GEOSS::Experiment::Arraylayout;
use GEOSS::User::User;
use GEOSS::Arraycenter::Order;

use Getopt::Long 2.13;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_insert_lib";

my ($nolock, $readonly, $debug, $path, $userpath);

getOptions();
$readonly = (! $readonly);

# for each subdirectory of the path
# each subdirectory represents a user - get the us_pk

my @subdirs;
if ($path)
{
  opendir (TOPDIR, "$path") || die "Unable to open $path: $!";
  @subdirs = readdir(TOPDIR);
  print "Subdirs are: @subdirs\n" if ($debug);
  closedir (TOPDIR);
}
if ($userpath)
{
  my $subdir = basename($userpath);
  $userpath =~ /(.*)\/$subdir\/?$/;
  $path = $1;
  push @subdirs, $subdir if $userpath;
}

foreach my $login (@subdirs)
{
  next if (($login eq ".") || ($login eq "..") || (! -d "$path/$login")) ;

  my $owner = GEOSS::User::User->new(login=>$login) or 
    warn "User $login does not exist.  $DBI::errstr\n" and next;
  warn "Unable to process $login.  User is not a PI" and next 
    if (! $owner->is_pi);
  print "Processing $owner.\n" if ($debug);

# get all subdirectories - these represent a study/order
  opendir(SUBDIR, "$path/$login") || die "Unable to open $path/$login: $!";
  my @studies = readdir(SUBDIR);
  closedir(SUBDIR);
  my $study;
  foreach $study (@studies)
  {
    next if (($study eq ".") || ($study eq "..") 
        || (! -d "$path/$login/$study"));
    eval { 
      process_study($owner->pk, $path, $login, $study);
    };
    if ($@)
    {
      $dbh->rollback();
      warn "Unable to process $study: $@\n\n\n";
    }
    else
    {
      $dbh->commit();
    }
  }
} 
$dbh->disconnect(); 

sub process_study
{
  my ($owner_pk, $path, $login, $study) = @_;

  my %ec; 
  print "\nSkipping $study - already exists in database\n" and next 
    if (GEOSS::Experiment::Study->new(name => $study));
  print "\nProcessing study: $study\n";

  opendir (my $studydir, "$path/$login/$study") 
    or die "Unable to open $path/$login/$study : $!\n";
  my @files = readdir $studydir;
  closedir $studydir;

  my (@hyb_names, %additional_info);
  foreach my $file (@files)
  {
    next if (($file eq ".") || ($file eq ".."));
    if (($file =~ /study.txt/i) ||
        ($file =~ /exp_condition.txt/i) ||
        ($file =~ /arraymeasurement.txt/i) ||
        ($file =~ /order_info.txt/i) ||
        ($file =~ /chip_name.txt/i) ||
        ($file =~ /disease.txt/i) ||
        ($file =~ /sample.txt/i))
    {
      $additional_info{$file} = "$path/$login/$study/$file";;
      next;
    }
    else
    {
      warn "Unrecognized meta-data file: $path/$login/$study/$file" . 
        " won't be processed." if $file ne "data";
    }
  }

  opendir (my $datadir, "$path/$login/$study/data") 
    or die "Unable to open $path/$login/$study/data : $!\n";
  @files = readdir $datadir;
  closedir $datadir;

  if (@files == 3) # enteries for . and ..
  {
    @hyb_names = parse_data_headers(
        "$path/$login/$study/data/$files[2]");
  }
  else
  {
    @hyb_names = grep {
        s/((.*)_([A-Za-z]+)(_\d+)?)\.(txt)$/\1/i;
    } @files;
  }
  print "Hybridizations found are: @hyb_names\n" if ($debug);

  my $al_fk;
  if ($additional_info{"chip_name.txt"}) 
  {
    open (my $chip, "$path/$login/$study/chip_name.txt") 
      or die "Unable to open $path/$login/$study/chip_name.txt $!";
    my $name = <$chip>; chomp($name);
    my $layout = GEOSS::Experiment::Arraylayout->new(name => $name);
    print "Set layout to $layout" if ($debug);
    $al_fk = $layout->pk;
  }

  my $ord_num;
  if ($additional_info{"order_info.txt"}) 
  {
    my ($error, $info_ref) = read_txt($additional_info{'order_info.txt'});  
    $ord_num = $info_ref->{1}->{order_number};
    print "Set order_number to $ord_num\n";
  }

  foreach my $n (@hyb_names)
  {
    my ($exp_cond, $bio_rep, $chip_rep);
    if ($ord_num)
    { 
      $n =~ /^${ord_num}_(.*)_([A-Za-z]+)(_\d+)?/i or
        die "Unexpected format for order hybridization name ($n)" ;
      $exp_cond = $1; 
      $bio_rep = $2; 
      $chip_rep= $3; 
    } else 
    {
      $n =~ /^(.*)_([A-Za-z]+)(_\d+)?/i or
        die "Unexpected format for hybridization name ($n)";
      $exp_cond = $1; 
      $bio_rep = $2; 
      $chip_rep= $3; 
    }

# each sample must have at least one chip replicate, so 
# supply a default if required
    $chip_rep = "1" if (! $chip_rep);

    my (%smps, %hybs); 
    my ($smps_ref, $hybs_ref);

    if (exists $ec{$exp_cond})
    {
      $smps_ref= $ec{$exp_cond};
      %smps = %$smps_ref;
    }
    if (exists $smps{$bio_rep})
    {
      $hybs_ref = $smps{$bio_rep};
      %hybs = %$hybs_ref;
    }
    if ($chip_rep) 
    {
      $hybs{$chip_rep} = $al_fk? $al_fk : get_al_fk( 
          "$path/$login/$study/data", $n);
    }
    $smps{$bio_rep} = \%hybs;
    $ec{$exp_cond} = \%smps;
    print "\t exp_cond: $exp_cond\t" if ($debug);
    print "\t bio_rep: $bio_rep \t" if ($debug); 
    print "\t chip_rep: $chip_rep \n" if ($debug);
  } 
  print "\n" if ($debug);
  insert_data($owner_pk, $study, $ord_num,
      \%ec, \%additional_info, $readonly, $debug);
} # processStudy

sub parse_data_headers {
  my $file = shift;

  open(my $fh, "$file") or die "Unable to open $file: $!";
  chomp(my $line = <$fh>);
  $line =~ s/^Probesets\t//i or
    $line =~ s/^probe_set_name\t//i or
    warn "Expected first column header of $file to be 'Probesets' " . 
    "or 'probe_set_name'";
  return map {
    die "Bad chip name format: $_" if ($_ !~ /(.*)_([A-Za-z]+)(_\d+)?/); 
    $_;
  } split /\t/, $line;
}

sub get_al_fk
{
  my ($sty_path, $file) = @_;
  my $al_fk = 0;

# the chip type is in the rpt file.  Rpt file should be named the same
# as the txt file with different extension.
  my $rpt = `find $sty_path -iname '$file.rpt'`;
  chomp($rpt);
  my $file_chip = get_file_chip($rpt);

  my $sql = "select al_pk from arraylayout where name = '$file_chip'";
  my $sth = $dbh->prepare($sql) || die "get_al_fk prepare
    $sql\n$DBI::errstr\n";
  $sth->execute() || die "get_al_fk execute $sql\n$DBI::errstr\n";

  ($al_fk) = $sth->fetchrow_array();
  if (! $al_fk > 0)
  {
    die "Unable to determine al_pk for the chip type ($file_chip) specified
      in $sty_path/$rpt.  Inserting into arraymeasurement will fail.\n";
  }
  return($al_fk);
} # get_al_fk

sub insert_data
{
  my ($owner_pk, $study, $ord_num,
      $ec_ref, $add_info_ref, $commit, $debug) = @_;

  my $us_fk = GEOSS::Session->user;
  print "Inserting order: $ord_num\n" if ($debug);
  my ($error, $oi_pk) = insert_order_bulk($ord_num, $us_fk,
      $owner_pk, $add_info_ref->{"order_info.txt"}, $commit, $debug) 
    if ($ord_num);

  my $sty_pk;
  if (! $error)
  { 
    print "Inserting study: $study\n";
    ($error, $sty_pk) = insert_study_bulk($dbh, $us_fk,
        $study, $owner_pk,
        $add_info_ref->{"study.txt"}, $add_info_ref->{"disease.txt"},
        $commit, $debug);
    if (! $error)
    {
      my $ec;
      ($error, my $info_ec_ref)=read_txt($add_info_ref->{"exp_condition.txt"}) 
        if (exists $add_info_ref->{"exp_condition.txt"});
      foreach $ec (keys(%$ec_ref))
      {
        print "\tInserting exp_cond: $ec\n";
        ($error, my $ec_pk) = insert_exp_condition_bulk($dbh, 
            $us_fk, $ec, 
            $sty_pk, $owner_pk, $info_ec_ref->{$ec}, $commit, $debug); 

        if (! $error)
        {
          my $smp_ref = $ec_ref->{$ec};
          my $smp;

          ($error, my $info_smp_ref) = read_txt($add_info_ref->{"sample.txt"}) 
            if (exists $add_info_ref->{"sample.txt"});
          if (!$error)
          {
            foreach $smp (keys(%$smp_ref))
            { 
              my $key = $ec . "_" . $smp;
              print "\t\tInserting smp: $key\n";
              my ($error, $smp_pk) = insert_sample_bulk($dbh,  
                  $us_fk, $oi_pk, 
                  $ec_pk, $smp, $owner_pk, $info_smp_ref->{$key}, $commit,
                  $debug);
              if (! $error)
              {         
                my $hyb_ref = $smp_ref->{$smp};
                my $hyb;
                ($error, my $info_am_ref) = read_txt(
                    $add_info_ref->{"arraymeasurement.txt"}) 
                  if (exists $add_info_ref->{"arraymeasurement.txt"});
                foreach $hyb (keys(%$hyb_ref))
                {
                  print "\t\t\tInserting hyb: $hyb\n";
                  my $hyb_key = $key . $hyb;
                  if (! exists($info_am_ref->{$hyb_key}))
                  {
                    $hyb_key = $key;
                  }
                  ($error, my $am_pk) = insert_arraymeasurement_bulk($dbh, 
                      $us_fk, $oi_pk, $smp_pk, $hyb, $hyb_ref->{$hyb}, 
                      $owner_pk, $info_am_ref->{$hyb_key}, $commit, $debug);
                }
              }
            }
          } 
        } 
      } 
    } # foreach $ec
  }

  if ($error)
  {
    print "Unable to insert study: $study\n$error\n";
    my $msg = get_message($error);
    GEOSS::Session->set_return_message("errmessage", $msg);
    $dbh->rollback();
  }
  else
  {
    my $sth = getq("select_sample_by_sty_pk", $dbh);
    $sth->execute($sty_pk);
    my $smps;
    my $x;

    while ($x = $sth->fetchrow_array())
    {
      $smps .= "$x,";
    }
    chop($smps);

    update_hn($smps);
    if ($commit)
    {
      print "Committing study $study and associated values.\n" if ($debug);
      my $order = GEOSS::Arraycenter::Order->new(pk => $oi_pk) if ($oi_pk);
      if (($oi_pk) && ($order->status eq "COMPLETE") &&
          (! $nolock))
      {
        lock_order($dbh, $oi_pk);
        doq_approve_order($oi_pk);
      }
      $dbh->commit();
    }
    else
    {
      print "Not committing study $study and associated values as the readonly flag is set.\n" if ($debug);
      $dbh->rollback();
    }
  }
} #insert_data

sub insert_order_bulk
{
  my ($ord_name, $us_fk, $owner_pk, $add_file, $commit, $debug) = @_;
  my $error = 0;
  my $oi_pk;

  die "Unable to create order $ord_name as that order number is " .
    "already in use" 
    if (GEOSS::Arraycenter::Order->new(name => $ord_name));

  my ($error, $info_ref) = read_txt($add_file)  
    if (($add_file ne "")&&(!$error));

  if (!$error)
  {
    my $oi_ref = $info_ref->{1};
    $oi_ref->{order_number} = $ord_name; 
    $oi_ref->{created_by} = doq($dbh, "get_us_pk", "admin") 
      if (! $oi_ref->{created_by});
    ($error, $oi_pk) = insert_row_generic($dbh, $us_fk, 
        "order_info", 
        $oi_ref, 
        {
        "owner_us_pk", $owner_pk,
        "owner_gs_pk", $owner_pk,
        },
        \&err_insert_order_info,
        \&pre_insert_order_info,
        \&post_insert_order_info,
        $commit, $debug);
  }

  print "Ret: insert_order_bulk: $error oi_pk: $oi_pk\n" if ($debug); 
  return($error, $oi_pk);
}

sub insert_sample_bulk
{
  my ($dbh, $us_fk, $oi_pk, $ec_fk, $smp, $owner_pk, $smp_ref, $commit,
      $debug) = @_;
  my $error = 0;
  my $smp_pk;

  $smp_ref->{ec_fk} = $ec_fk;
  $smp_ref->{oi_fk} = $oi_pk if $oi_pk;
  ($error, $smp_pk) = insert_row_generic($dbh, $us_fk, "sample", $smp_ref, 
      {
      "owner_us_pk", $owner_pk,
      "owner_gs_pk", $owner_pk,
      },
      \&err_insert_sample,
      \&pre_insert_sample,
      \&post_insert_sample,
      $commit, $debug);

  return($error, $smp_pk);
}

sub insert_arraymeasurement_bulk
{
  my ($dbh, $us_fk, $oi_pk, $smp_fk, $am, $al_fk, $owner_pk, $am_ref, $commit, 
      $debug) = @_;
  my $error = 0;
  my $am_pk;

  $am_ref->{smp_fk} = $smp_fk;
  $am_ref->{al_fk} = $al_fk;
  $am_ref->{description}="Created via bulk configuration"
    if (! exists ($am_ref->{description} ));

  ($error, $am_pk) = insert_row_generic($dbh, $us_fk, "arraymeasurement", 
      $am_ref, 
      {
      "owner_us_pk", $owner_pk,
      "owner_gs_pk", $owner_pk,
      },
      \&err_insert_arraymeasurement,
      \&pre_insert_arraymeasurement,
      \&post_insert_arraymeasurement,
      $commit, $debug);

  return($error, $am_pk);
}

sub insert_exp_condition_bulk
{
  my ($dbh, $us_fk, $ec, $sty_pk, $owner_pk, $exp_ref, $commit, $debug) = @_; 
  my $error = 0;

  $exp_ref->{abbrev_name} = $ec;
  $exp_ref->{sty_fk} = $sty_pk;
  $exp_ref->{name} = $exp_ref->{abbrev_name} 
  if (! exists($exp_ref->{name}));
  $exp_ref->{description}="Created via bulk configuration"
    if (! exists($exp_ref->{description}));
  ($error, my $ec_pk) = insert_row_generic($dbh, $us_fk, "exp_condition", 
      $exp_ref, 
      {
      "owner_us_pk", $owner_pk,
      "owner_gs_pk", $owner_pk,
      },
      \&err_insert_exp_condition,
      \&pre_insert_exp_condition,
      \&post_insert_exp_condition,
      $commit, $debug);
  print "Ret: insert_exp_condition_bulk $error ec_pk: $ec_pk\n" if ($debug);
  return ($error, $ec_pk);
}  # insert_exp_condition_bulk

sub insert_study_bulk
{
  my ($dbh, $us_fk, $study, $owner_pk, $add_file, $dis_file, 
      $commit, $debug) = @_;

  my ($error, $info_ref) = read_txt($add_file) if (defined $add_file);
  my $sty_ref = $info_ref->{1};
  $sty_ref->{sty_comments} = "Created via bulk configuration"
    if (!exists $sty_ref->{sty_comments});
  $sty_ref->{study_name} = $study;
# get the us_pk of the admin user--can't assume 1
  my $created_by = doq($dbh, "get_us_pk", "admin");
  $sty_ref->{created_by} = $created_by if (! exists($sty_ref->{created_by}));
  ($error, my $sty_pk) = insert_row_generic($dbh, $us_fk, "study", $sty_ref, 
      {
      "owner_us_pk", $owner_pk,
      "owner_gs_pk", $owner_pk,
      },
      \&err_insert_study,
      \&pre_insert_study,
      \&post_insert_study,
      $commit, $debug);
  print "Ret: insert_study_bulk $error sty_pk: $sty_pk\n" if ($debug);
  if (-r $dis_file)
  {
    open (DISEASE, "$dis_file") || die "Unable to open $dis_file";
    my $dis_name;
    while ($dis_name = <DISEASE>)
    {
      chomp $dis_name;
      my $dis_pk = getq_dis_pk_by_dis_name($dbh, $us_fk, $dis_name);
      my $sql = "insert into disease_study_link (dis_fk, sty_fk)" .
        " values ($dis_pk, $sty_pk)";
      print "SQL is $sql\n" if ($debug);
      $dbh->do($sql) if ($dis_pk);
    }
    close(DISEASE);
  }
  return ($error, $sty_pk);
} # insert_study_bulk 

### SUBROUTINES ###
sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
        'readonly!' => \$readonly,
        'nolock!' => \$nolock,
        'debug!' => \$debug,
        'path=s' => \$path,
        'userpath=s' => \$userpath,
        'help|?'      => \$help,
        );
  }
  usage() if $help;

  print "Running geoss_bulk_configurator with the following options:\n" 
    if ($debug);
  print "  readonly\n" if (($debug) && ($readonly));
  print "  nolock\n" if (($debug) && ($nolock));
  print "  debug\n" if ($debug);
  print "  userpath $userpath\n" if ($debug);
  print "  path $path\n" if ($debug);

  print "Please specify either a path or a userpath" and usage()
    if ((! ($path || $userpath)) || ($path && $userpath));

  if ( $path && (! -r $path))
  {
    print "Unable to read $path :$!. "; 
    print "Please specify a valid path.\n";
  }

  if ( $userpath && (! -r $userpath))
  {
    print "Unable to read $userpath :$!. ";
    print "Please specify a valid path.\n";
  }

}


# this function reads additional attributes for a table from a text file
# INPUTS:
#   $filename - filename of the file to get values from
# OUTPUTS:
#   $success - 0 for success, other number indicates an error
#   $key_field - field containing the key name - data is likely to be keyed
#   by name. 
#   \%info - hash containing values from the file
#
#   Expected file format:
#
#   <name of key field>\t<field1>\t<field2>...\t<fieldn>
#   <value of key field>\t<value1>\t<value2>...\t<valuen>
#
#   For example: (for exp_condition table)
#
#   abbrev_name name  description spc_fk
#   abc123  cond1 this is abc cond  11
#   def123  cond2 this is def cond  11
#
sub read_txt
{
  my ($filename) = @_;
  my %info;
  my $success = 0;

  print "Reading $filename for additional information\n" if ($debug);

  if (! -r $filename)
  {
    warn "Can't read $filename: $!.  Ignoring additional values " .
      "specified in the file.\n";
  }
  else
  {
    open(INFILE, "$filename") or die "Unable to open $filename: $!\n";
    my $headers=<INFILE>;
    chomp($headers);
    my @headers = split(/\t/, $headers);
    shift @headers;
    my $line;
    while ($line = <INFILE>)
    {
      chomp($line);
      my @line = split(/\t/, $line);
      my $key= shift(@line);
      my %fields;
      foreach (@headers)
      {
        $fields{$_} = shift(@line);
#  print "Adding $fields{$_} as $_\n";
      }
      $key = 1 if ((basename($filename) =~ /study/i) || 
          (basename($filename) =~ /order_info/));
      $info{$key} = \%fields;
    }
    close(INFILE);
  }

  return($success, \%info);
}

sub usage
{
  print "Usage: \n";
  print "./geoss_bulk_configurator --path=<path> | --userpath=<path> [--readonly] [--debug] [--nolock]\n";
  exit;
} # usage

=head1 NOTES

=head1 AUTHOR

Teela James
