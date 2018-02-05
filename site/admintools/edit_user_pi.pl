use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    
    my $us_fk = get_us_fk($dbh, "admintools/edit_user_pi.cgi");
    if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }


    # clear existing enteries -- there shouldn't be any at this point
    get_session_val($dbh, $us_fk, "pi_user");
    $ch{user_login} = select_users($dbh, $us_fk, "user_login");
    
    $ch{htmltitle} = "Manage PIs and Users";
    $ch{help} = set_help_url($dbh, "manage_pis_and_users");
    $ch{description} = "This page allows you to modify which pis are associated with a given user.  You may do this in one of two ways:  by assigning (or removing) pis associated with a specific user, or by changing users associated with a specific pi.";
    
    my $allhtml = get_allhtml($dbh, $us_fk, "edit_user_pi.html", "/site/webtools/header.html",
      "/site/webtools/footer.html", \%ch);

    print "Content-type: text/html\n\n$allhtml";
    $dbh->disconnect();
    exit();
}
