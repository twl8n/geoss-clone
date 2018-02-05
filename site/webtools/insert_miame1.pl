use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
my %ch = $q->Vars();
my $debug;
my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, "webtools/insert_miame1.cgi");

if (is_public($dbh, $us_fk))
{
  set_return_message($dbh, $us_fk, "message","errmessage", "INVALID_PERMS");
  my $url = index_url($dbh, "webtools");
  print "Location: $url\n\n";

}
else
{
  if (! get_config_entry($dbh, "data_publishing"))
  {
    GEOSS::Session->set_return_message("errmessage",
        "ERROR_DATA_PUBLISHING_NOT_ENABLED");
    print "Location: " . index_url($dbh, "webtools") . "\n\n";
    exit;
  }

  draw_insert_miame($dbh, $us_fk, \%ch);
}
$dbh->disconnect();
exit();

