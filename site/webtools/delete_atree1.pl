use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/choose_tree.cgi");

        
    my $sth = getq("select_tree_nc_by_pk", $dbh, $us_fk);
    $sth->execute($ch{tree_pk});
    my $chref = $sth->fetchrow_hashref();
    $sth->finish();

    $chref->{htmltitle} = "Analysis Tree Delete Confirmation";
    $chref->{help} = set_help_url($dbh, "edit_delete_or_run_an_existing_analysis_tree");
    my $allhtml = get_allhtml($dbh, $us_fk, "delete_atree1.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html", $chref); 

    print "Content-type: text/html\n\n";
    print "$allhtml\n";
    
    $dbh->disconnect;
    exit(0);
}

