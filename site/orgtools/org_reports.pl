use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $co = new CGI;
my %ch = $co->Vars();
my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, "orgtools/org_reports.cgi");

if (! get_config_entry($dbh, "array_center"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_ARRAY_CENTER_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}


if ((!is_administrator($dbh, $us_fk)) && (! is_org_curator($dbh, $us_fk)))
{
  set_session_val($dbh, $us_fk, "message", "errmessage",
    get_message("INVALID_PERMS"));
  warn "$us_fk runs org_reports.cgi without sufficient privs";
  my $url = index_url($dbh, "webtools"); # see session_lib
  print "Location: $url\n\n";
  $dbh->disconnect;
  exit();
};


draw_org_reports($dbh, $us_fk, \%ch);
