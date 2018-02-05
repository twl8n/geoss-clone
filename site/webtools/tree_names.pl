use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;

my $dbh = new_connection();
my %ch;
my $us_fk = get_us_fk($dbh, "webtools/tree_names.cgi");

$ch{type} = "tree";
$ch{ret_file} = "insert_tree";
my $sth_sn = getq("all_trees", $dbh);
$sth_sn->execute();
while( (my $tree_name, undef, undef) = $sth_sn->fetchrow_array())
{
  $ch{sn_list} .= $tree_name . "<br>";
}
$ch{htmltitle} = "View all tree names";
$ch{help} = set_help_url($dbh, "create_or_run_a_new_analysis_tree");
$ch{htmldescription} = "This list shows all tree names currently in use in 
the system.  In order to avoid confusion, duplicate tree names are not
allowed.";

my $allhtml = get_allhtml($dbh, $us_fk, "in_use_names.html", 
    "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);

print "Content-type: text/html\n\n$allhtml\n";
$dbh->disconnect();

