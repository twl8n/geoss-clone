=head1 NAME
  
geoss_change_dbpw - change the geoss user database password

=head1 SYNOPSIS

geoss_change_dbpw 
   
=head1 DESCRIPTION
  
This utility will allow a user to change the geoss user database password.

=cut
    
use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use Getopt::Long 2.13;
require "$LIB_DIR/geoss_session_lib";

my %ch;

main:
{
    my $us_fk = "command";
 
    my $newpass = "foo";
    my $confirm = "bar";
    # get the new password
    my $first = 1;
    while ($newpass ne $confirm)
    {
      if ($first == 1)
      {
        $first = 0;
      }
      else
      {
        print "Password do not match.\n\n"; 
      }
      print "Enter the new password:\n";
      $|=1;
      system("stty -echo");
      $newpass=<STDIN>;
      chomp($newpass);
      $|=0;
      system("stty echo"); 
      print "Re-enter the new password for confirmation:\n";
      $|=1;
      system("stty -echo");
      $confirm=<STDIN>;
      chomp($confirm);
      $|=0;
      system("stty echo"); 

    }
    my $success = change_dbpw_generic($dbh, $us_fk, $newpass, $confirm);
    print "$success\n";
    $dbh->disconnect();
}

