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
    my $pk = shift || ask_user("Enter sty_pk:\n");

    my $study = GEOSS::Experiment::Study->new(pk => $pk)
        or die "Study ($pk) does not exist";

    print "Study Name: $study\t";
    print "Status: " . $study->status . "\n";
    my $owner = $study->owner;
    print 'Owner: ' . $owner->name . " $owner\t";
    print 'Group: ' . $study->group . "\n";
    foreach ($study->exp_conditions)
    {
      print "\tExp Cond: $_ \t " . $_->status . "\n";
      foreach ($_->samples)
      {
        print "\t\tSample: $_\t" . $_->status . "\n";
        foreach ($_->arraymeasurements)
        {
          print "\t\t\tChips: $_\t" . $_->status . "\n";
        }
      }
    }

}

sub usage
{
   print "geoss_study_info [sty_pk]\n";
   exit 1;
}
