
=head1 NAME
 
 geoss_bulk_load - facilitates bulk loading of geoss studies

=head1 SYNOPSIS
./geoss_bulk_load  --userpath <path (login id for a GEOSS user)> |
                   --path <path (containing subdirs for users)>  |
                   [--readonly|--debug ]

=head1 DESCRIPTION

geoss_bulk_load load studies based on an input directory structure.

=head1 OPTIONS

=item 
--readonly - list studies to load and parses data files, but does not 
  commit changes to the db

=item 
--debug - prints verbose messages while running

=item
--path <path> - path containing user subdirectories, which in turn contain
study subdirectories.  Used to load studies owned by multiple users.

=item
--userpath <path (login ID)> - path containing study subdirectories.  Used to
load studies for a single user.

=cut

use strict;
use File::Path;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::Experiment::Study;
use GEOSS::Experiment::Arraylayout;
use GEOSS::User::User;
use GEOSS::Arraycenter::Order;

use Getopt::Long 2.13;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_insert_lib";

my ($readonly, $debug, $path, $userpath);

getOptions();

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

  my $owner_pk = GEOSS::User::User->new(login=>$login)->pk or 
    warn "Unable to get us_pk for user $login.  Verify existence of " . 
      "$login in the usersec table.  $DBI::errstr\n" and next;
  print "Processing $login.  Us_pk is $owner_pk\n" if ($debug);

# get all subdirectories - these represent a study/order
  opendir(SUBDIR, "$path/$login") || die "Unable to open $path/$login: $!";
  my @studies = readdir(SUBDIR);
  closedir(SUBDIR);
  my $study;
  foreach $study (@studies)
  {
    next if (($study eq ".") || ($study eq "..") 
        || (! -d "$path/$login/$study"));
    
    my $obj = GEOSS::Experiment::Study->new(name => $study);
    print "Unable to process $study.  It is not configured in the db.\n" 
      and next if (! $obj);
    my $status = $obj->status;
    print "Unable to process $study ($status) as status is not COMPLETE.\n"
      and next if ($status ne "COMPLETE");
    print "Processing $study\n";
    $obj->set_loading_flag;
    opendir (my $datadir, "$path/$login/$study/data") 
      or die "Unable to open $path/$login/$study/data : $!\n";
    my @files = readdir $datadir;
    closedir $datadir;
    
    my $ret;
    eval { 
      if (@files == 3)
      {
        $ret = $obj->load_from_file("$path/$login/$study/data/" 
          . $files[2]);
      } 
      else
      {
        $ret = $obj->load_from_directory("$path/$login/$study/data");
      }
    };
    if ($@)
    {
      $obj->clear_loading_flag;
      $dbh->rollback();
      chomp($@);
      warn "Unable to process $study.\n$@\n";
    }
    else
    {
      $readonly ?  $dbh->rollback(): $dbh->commit();
      print "Not committing changes as readonly flag is set.\n"
        if ($readonly); 
    }
    if ($ret != 1)
    {
      my $logpath = "$GEOSS::BuildOptions::USER_DATA_DIR/" .
        $obj->owner->login() .  "/Data_Files/" . $obj->{name};
      mkpath $logpath, 0, 0770 or die "Unable to make $logpath: $!" 
        if (! -e $logpath);
      open (my $log, ">> $logpath/load_log.txt") 
        or die "Unable to open $logpath/load_log.txt: $!";
      close($log);
    }
  }
} 
$dbh->disconnect(); 

sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
        'readonly!' => \$readonly,
        'debug!' => \$debug,
        'path=s' => \$path,
        'userpath=s' => \$userpath,
        'help|?'      => \$help,
        );
  }
  usage() if $help;

  print "Running geoss_bulk_load with the following options:\n" 
    if ($debug);
  print "  readonly\n" if (($debug) && ($readonly));
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

sub usage
{
  print "Usage: \n";
  print "./geoss_bulk_load --path=<path> | --userpath=<path> [--readonly] [--debug] \n";
  exit;
} # usage

=head1 NOTES

=head1 AUTHOR

Teela James
