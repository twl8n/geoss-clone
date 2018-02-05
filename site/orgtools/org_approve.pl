use strict;
use CGI;
use GEOSS::Session;
use GEOSS::Database;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
my %ch = $q->Vars();

my $us_fk = get_us_fk($dbh, "orgtools/index.cgi");

if (! get_config_entry($dbh, "array_center"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_ARRAY_CENTER_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}


if ((!is_administrator($dbh, $us_fk)) && (! is_org_curator($dbh, $us_fk)))
{
  GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
  write_log("$us_fk runs org_approve.cgi");
  my $url = index_url($dbh, "webtools"); # see session_lib
    print "Location: $url\n\n";
  $dbh->disconnect;
  exit();
};

draw_org_approve($dbh, $us_fk, \%ch);
