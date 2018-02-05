=head1 NAME
  
geoss_adduser - adds a user to the geoss system

=head1 SYNOPSIS

geoss_adduser  --login=<login> --password=<password> 
  --type=<administrator|curator|experiment_set_provider|public> 
  --pi_login=<pi_login> 
  [--organization=<organization>]  [--contact_fname=<first name>] 
  [--contact_lname=<last name>] [--contact_phone=<phone number>]
  [--contact_email=<email addy>]  [--department=<department>] 
  [--building=<building>]  [--room_number=<room_number>] 
  [--org_phone=<organization phone>]
  [--org_email=<organization email>] [--org_mail_address=
  <organization mail address>] [--org_toll_free_phone=
  <organization toll free>] [--org_fax=<organization fax number>] 
  [--url=<organization url>] [--credentials=<user credentails>] 
   
=head1 DESCRIPTION
  
This script is intended for use as part of the geoss system.  It 
will add a user.  

=cut
    
use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::BuildOptions;
require 'geoss_session_lib';

use Getopt::Long 2.13;
my %ch;

main:
{
    getOptions();

    -w $USER_DATA_DIR
      or die "You cannot create new geoss users because you do not have"
           . " appropriate permissions to write to $USER_DATA_DIR";

    my $us_fk = "command";
 
    # don't req the user to enter twice on the command line
    # as the password is in plain text with this utility
    $ch{confirm_password} = $ch{password};
    my $verify = verify_acct_generic($dbh, $us_fk, \%ch);
    my $success;
    ($verify eq "") ? 
       $success = create_acct_generic($dbh, $us_fk, \%ch) :
       $success = $verify;
    print "$success\n";
    $dbh->commit();
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
                  'organization=s' => \$ch{organization},
                  'contact_fname=s' => \$ch{contact_fname},
                  'contact_lname=s' => \$ch{contact_lname},
                  'contact_phone=s' => \$ch{contact_phone},
                  'contact_email=s' => \$ch{contact_email},
                  'department=s' => \$ch{department},
                  'building=s' => \$ch{building},
                  'room_number=s' => \$ch{room_number},
                  'org_phone=s' => \$ch{org_phone},
                  'org_email=s' => \$ch{org_email},
                  'org_mail=s' => \$ch{org_mail_address},
                  'org_toll_free_phone=s' => \$ch{org_toll_free_phone},
                  'org_fax=s' => \$ch{org_fax},
                  'url=s' => \$ch{url},
                  'credentials=s' => \$ch{credentials},
                  'login=s' => \$ch{login},
                  'password=s' => \$ch{password},
                  'pi_login=s' => \$ch{pi_login},
                  'help|?' => \$help,
                  );
    } #have command line args
    if (($ch{login} eq "") || ($ch{password} eq "") ||
        ($ch{type} eq ""))
    {
      usage();
    }
    if (($ch{type} ne "administrator") && ($ch{pi_login} eq ""))
    {
      usage();
    } 
    usage() if ($help); 

} # getOptions

sub usage
{
      print "Usage: \n";
      print "geoss_adduser --login=<login> --password=<password> \n" .
       " --type=<administrator|curator|experiment_set_provider|public> " .
       " --pi_login=<pi_login> \n" .
       "[--organization=<organization>]  [--contact_fname=<first name>] \n".
       "  [--contact_lname=<last name>] [--contact_phone=<phone number>]\n" .
       " [--contact_email=<email addy>]  [--department=<department>] \n".
       " [--building=<building>]  [--room_number=<room_number>] \n" .
       " [--org_phone=<organization phone>]\n ". 
       " [--org_email=<organization email>] [--org_mail_address=" .
       "<organization mail address>]  \n[--org_toll_free_phone=".
       "<organization toll free>] \n [--org_fax=<organization fax number>] " .
       " [--url=<organization url>] \n [--credentials=<user credentails>] \n";
      exit;
} #usage

