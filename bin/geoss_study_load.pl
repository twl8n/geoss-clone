
=head1 NAME
 
 geoss_study_load - loads data for one study

=head1 SYNOPSIS

 ./geoss_study_load  --sty_pk <sty_pk> --fi_pk <input_file_pk>

=head1 DESCRIPTION

geoss_study_load can be used to load data for one study from a single input
file that contains data for all chips in the study

=head1 OPTIONS

=item 
--fi_pk - filename for chip data - can be a tar file containing
multiple files (rpt, exp, txt), or a single txt file containing all the data

=cut

use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::Experiment::Study;
use GEOSS::Experiment::Arraymeasurement;
use GEOSS::Experiment::Arraylayout;
use Getopt::Long 2.13;
require "$LIB_DIR/geoss_session_lib";

my $sty_pk;
my $fi_pk;

getOptions();

my $study = GEOSS::Experiment::Study->new(pk => $sty_pk) 
  or die "Study ($sty_pk) does not exist";
my $file = GEOSS::Fileinfo->new(pk => $fi_pk) 
  or die "Study ($fi_pk) does not exist";
print "Loading $study from $file\n";

my $ret = $study->load_from_file($file->name);
if ($ret)
{
  my $logname = "$GEOSS::BuildOptions::USER_DATA_DIR/" .
    $study->owner->login() .  "/Data_Files/" . $study->{name} .
    "/load_log.txt";
  open (my $log, ">>", "$logname") or die "Unable to open $logname: $!";
  print $log "Return from load: $ret\n";
  close($log);
}

### SUBROUTINES ###
sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
        'sty_pk=s' => \$sty_pk,
        'fi_pk=s' => \$fi_pk,
        'help|?'      => \$help,
        );
  }
  $sty_pk or usage();
  $fi_pk or usage();
  $help and usage();
}

sub usage
{
  print "Usage: \n";
  print "./geoss_study_load --sty_pk <pk> --fi_pk <input_file>\n";
  exit;
} # usage

=head1 NOTES

=head1 AUTHOR

Teela James
