use strict;
use GEOSS::Experiment::Study;
use GEOSS::Session;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
    
my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, "webtools/choose_study.cgi");

my $study = GEOSS::Experiment::Study->new(pk => $q->param("sty_pk"));
if ($study)
{
  my $status = $study->status;
  if (($status eq "INCOMPLETE") || ($status eq "COMPLETE"))
  {
    $study->delete;
    GEOSS::Session->set_return_message("goodmessage", "SUCCESS_DELETE_STUDY",
        $study->name); 
    $dbh->commit;
  }
  else
  {
    GEOSS::Session->set_return_message("errmessage", "CANT_DELETE",
        $study->name, 
        "Status ($status) must be INCOMPLETE or COMPLETE in order to delete.");
  }
}
my $url = index_url($dbh); # see session_lib
$url .= "/choose_study.cgi";
print "Location: $url\n\n";
exit();
