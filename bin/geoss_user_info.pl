use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::Experiment::Study;
use GEOSS::User::User;
use GEOSS::User::Group;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_sql_lib";

main:
{
    my $pk = shift || ask_user("Enter us_pk:\n");

    my $user = GEOSS::User::User->new(pk => $pk)
        or die "User ($pk) does not exist";

    print "User: $user\n";
    print "Name: " . $user->name . "\n";
    print "Email: " . $user->email . "\n";
    print "Phone: " . $user->phone .  "\n";

    print "Groups: \n"; 
    foreach my $g ($user->groups)
    {
      print "\t$g\n";
    }
}

sub usage
{
   print "geoss_user_info [user_pk]\n";
   exit 1;
}
