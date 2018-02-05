=head1 NAME
  
geoss_rm_inactive_users - removes accounts that have not 
  been confirmed (user has not logged in) within a specific number
  of days

=head1 SYNOPSIS

geoss_rm_inactive_users  
  [--type=<administrator|curator|experiment_set_provider|public|all>]
   
=head1 DESCRIPTION
  
This script is intended for use as part of the geoss system.  It is
intended to be run on a daily basis via cron, but can also be run 
from the command line.  If no type is specified, public users
will be cleaned up.  If type is set to 'all', all user types will
be cleaned up.  No user will be cleaned up if they are referenced
in any way (for instance if they own data, even though they have never 
logged on). 

=cut
    
use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use Getopt::Long 2.13;
require "$LIB_DIR/geoss_session_lib";

my %ch;

main:
{
    getOptions();

    my $us_fk = "command";
 
    my $success = rm_inactive_users($dbh, $us_fk, \%ch);
    print "$success\n";
    $dbh->disconnect();
}

sub getOptions
{
    my $help;

    if (@ARGV > 0 )
    {
      # format
      # string : 'var=s' => \$var,
      # boolean : 'var!' => \$var,
       
           GetOptions(
                  'type=s' => \$ch{type},
                  'help|?' => \$help,
                  );
    } #have command line args
    usage() if ($help); 
    if ($ch{type} eq "")
    {
      $ch{type} = "public";
    }
    if ($ch{type} = "all")
    {
      $ch{type} = "";
    }

} # getOptions

sub usage
{
      print "Usage: \n";
      print "geoss_rm_inactive_users " .
       "[--type=<administrator|curator|experiment_set_provider|public|all>]" .
      exit;
} #usage

