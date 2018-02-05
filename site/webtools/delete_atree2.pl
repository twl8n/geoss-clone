use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "webtools/choose_tree.cgi");

    # TODO - delete all associated files
    delete_tree($dbh, $ch{tree_pk}, $us_fk);

    $dbh->commit;
    $dbh->disconnect;

    #
    # This script has no web page output. It only redirects 
    # back to choose_tree.cgi
    #
    my $url = index_url($dbh); # see session_lib
    $url .="/choose_tree.cgi";
    print "Location: $url\n\n";
    exit();
}
