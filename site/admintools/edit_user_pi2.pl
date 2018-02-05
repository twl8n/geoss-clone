use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $htmlfile;
    
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


    my $allhtml;
    if (exists $ch{pi})
    {
      $htmlfile = "edit_pis_for_user.html";
      $ch{description} = "This page allows you to modify which pis are associated with a given user.";  
      $ch{pi_list} = select_users($dbh, $us_fk, "pi_list", 
         $ch{user_login});
      $ch{pi_not_list} = select_users($dbh, $us_fk, "pi_not_list", 
	 $ch{user_login});
      set_session_val($dbh, $us_fk, "pi_user", "user", $ch{user_login});
    }
    elsif (exists $ch{user})
    {
      $htmlfile = "edit_users_for_pi.html";
      $ch{description} = "This page allows you to modify which users are associated with a given pi.";
      $ch{user_list} = select_users($dbh, $us_fk, "user_list", 
        $ch{user_login});
      $ch{user_not_list} = select_users($dbh, $us_fk, "user_not_list", 
	$ch{user_login});
       set_session_val($dbh, $us_fk, "pi_user", "pi", $ch{user_login});
    }
    else
    {
      die "Unknown action in edit_user_pi2.cgi\n";
    }
    
    $ch{htmltitle} = "Manage PIs and Users";
    $ch{help} = set_help_url($dbh, "manage_pis_and_users");
    $allhtml = get_allhtml($dbh, $us_fk, $htmlfile, "/site/webtools/header.html", "/site/webtools/footer.html",
      \%ch);

    print "Content-type: text/html\n\n$allhtml";
    $dbh->disconnect();
    exit();
}
