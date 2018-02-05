use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh=new_connection();
    my $headerfile = "/site/webtools/header.html";
    my $footerfile = "/site/webtools/footer.html";
    my $us_fk = get_us_fk($dbh, "admintools/admin_removeuser.cgi");
   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }

    $ch{htmltitle} = "Remove A User";
    $ch{help} = set_help_url($dbh, "remove_a_user");
    $ch{htmldescription} = "This page can be used to remove a user.  Only users who have no data associated with them can be removed.";
    my $login = $ch{remove_user};
  
    if ((! exists($ch{step})) || (! $ch{step}))
    {
      $ch{remove_user} = select_remove_users($dbh, $us_fk);
      my $allhtml = get_allhtml($dbh, $us_fk, "admin_removeuser.html",
        "$headerfile", 
        "$footerfile", \%ch);

      print $q->header;
      print "$allhtml\n";
      print $q->end_html;
    }
    elsif ($ch{step} == 3)
    {
       #delete the user
       my $success = remove_user_generic($dbh, $us_fk, $login);
      
       if ($success eq "true")
       {
         set_session_val($dbh, $us_fk, "message", "goodmessage", 
           get_message("SUCCESS_DELETE_USER","$login"));
         my $url = index_url($dbh);
         print "Location: $url\n\n";
       }
       else
       {
          $ch{step} = 1;
          $ch{remove_user} = select_remove_users($dbh, $us_fk);
          my $allhtml = get_allhtml($dbh, $us_fk, "admin_removeuser.html",
            "$headerfile", "$footerfile", \%ch);

          print $q->header;
          print "$allhtml\n";
          print $q->end_html;
       }
    }
    
    $dbh->disconnect();
    exit();
}

