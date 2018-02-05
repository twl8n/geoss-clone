use strict;
use CGI;
use GEOSS::Database;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;

my %ch;
my $us_fk = get_us_fk($dbh, "webtools/study_names.cgi");

$ch{type} = "study";
$ch{ret_file} = "edit_study";
my $sth_sn = getq("all_studies", $dbh);
$sth_sn->execute();
while( (my $study_name, undef, undef) = $sth_sn->fetchrow_array())
{
  $ch{sn_list} .= "$study_name<br>";
}
$ch{htmltitle} = "View all array study names";
$ch{help} = set_help_url($dbh, "create_new_array_study");
$ch{htmldescription} = "This list shows all array study names currently in use in the system.  In order to avoid confusion, we don't allow reuse of study names.";

my $allhtml = get_allhtml($dbh, $us_fk, "in_use_names.html", 
    "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);

print "Content-type: text/html\n\n$allhtml\n";
$dbh->disconnect();

