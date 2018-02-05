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
    my $us_fk = get_us_fk($dbh, "admintools/admin_removeorg.cgi");
   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }

    $ch{htmltitle} = "Remove A Special Center";
    $ch{help} = set_help_url($dbh, "delete_a_special_center");
    $ch{htmldescription} = "This page can be used to remove a special center.
      Only special centers who have no users associated with them can be removed.";
    my $org = $ch{remove_org};
  
    if ((! exists($ch{step})) || (! $ch{step}))
    {
      $ch{remove_org} = select_remove_orgs($dbh, $us_fk);
      my $htmlfile = "admin_removeorg.html";
      $htmlfile = "admin_removeorg2.html" if ($ch{remove_org} eq 
       qq#<select name="remove_org">\n</select>\n#); 
      my $allhtml = get_allhtml($dbh, $us_fk, $htmlfile,
        "$headerfile", 
        "$footerfile", \%ch);

      print $q->header;
      print "$allhtml\n";
      print $q->end_html;
    }
    elsif ($ch{step} == 3)
    {
       #delete the organization
       my $success = remove_org_generic($dbh, $us_fk, $org);
      
       if ($success eq "true")
       {
         set_session_val($dbh, $us_fk, "message", "goodmessage", 
           get_message("SUCCESS_MODIFY_SPECIAL_CENTER", "deleted"));
         my $url = index_url($dbh);
         print "Location: $url\n\n";
       }
       else
       {
          $ch{step} = 1;
          $ch{remove_org} = select_remove_orgs($dbh, $us_fk);
          my $allhtml = get_allhtml($dbh, $us_fk, "admin_removeorg.html",
            "$headerfile", "$footerfile", \%ch);

          print $q->header;
          print "$allhtml\n";
          print $q->end_html;
       }
    }
    
    $dbh->disconnect();
    exit();
}

