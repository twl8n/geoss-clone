use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::Arraycenter::Order;
use GEOSS::Arraycenter::Organization;
use GEOSS::User::User;
use GEOSS::User::Group;
use GEOSS::Experiment::Study;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_sql_lib";

main:
{
    my $pk = shift || ask_user("Enter oi_pk\n");

    my $order = GEOSS::Arraycenter::Order->new(pk => $pk)
      or die "Order ($pk) does not exist";

    print "Order: $order\tStatus: " . $order->status .  "\tStudy: " . 
      $order->study . "\n";

    foreach ($order->samples)
    {
      print "\tSample: $_\t" . $_->status . "\n";
      foreach ($_->arraymeasurements)
      {
        print "\t\tChips: $_\t" . $_->status . "\n";
      }
    }
    print "Owner: " . $order->owner . "\tGroup: " .  $order->group . "\n";
    print "Locked: " .  $order->locked . "\t";
    my $organization = $order->organization;
    print "Organization: $organization\n"; 
    print "Is approved: " . $order->approved . "\t";
    print "Approval Date: " . $order->approval_date . "\n";
}

sub usage
{
   print "geoss_order_info  [oi_pk]\n";
   exit 1;
}
