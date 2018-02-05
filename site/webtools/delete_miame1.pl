use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

# 2004-06-02 twl8n
# sql_lib is auto loaded by session_lib
# require "$LIB_DIR/geoss_sql_lib";

require "$LIB_DIR/geoss_miame_lib";

my $q = new CGI;
my %ch = $q->Vars();
my $dbh = new_connection();

if (! get_config_entry($dbh, "data_publishing"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_DATA_PUBLISHING_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}


delete_miame_data($dbh, $ch{miame_pk});
$dbh->disconnect();
my $url = index_url($dbh);
$url =~ s/(.*)\/.*/$1\/webtools\/choose_miame1.cgi/;
print "Location: $url\n\n";
exit();

