use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
# 2004-06-02 twl8n sql_lib auto loaded by session_lib
#require "$LIB_DIR/geoss_sql_lib";
require "$LIB_DIR/geoss_miame_lib";

my $q = new CGI;
my %ch = $q->Vars();
my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, "webtools/help_miame.cgi");

if (! get_config_entry($dbh, "data_publishing"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_DATA_PUBLISHING_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}


$ch{htmltitle}="MIAME Help";
$ch{help} = set_help_url($dbh, "edit_or_delete_or_submit_publishing_information");
my $allhtml = get_allhtml($dbh, $us_fk, "help_miame.cgi", "/site/webtools/header.html",
    "/site/webtools/footer.html" , \%ch);


print $q->header;
print "$allhtml\n";
print $q->end_html;
$dbh->disconnect();
exit();

