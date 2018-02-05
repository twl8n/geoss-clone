use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    
    %ch = $co->Vars();
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "admintools/admin_addorg.cgi");

   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs admin_addorg.cgi");
        print "Location: $url\n\n";
        exit();
    }

   
    if ((! exists($ch{step}) || $ch{step} == 2 || (! $ch{step}))) 
    {
      display_page($dbh, $us_fk, $co, \%ch);
      $dbh->disconnect();
      exit();
    }
    elsif ($ch{step} == 3) {
        # step 3: add the organization
        my $success  = create_org_generic($dbh, $us_fk, \%ch);

        if ($success eq "true")
        {
          make_logo_icon_avail($dbh, $us_fk, $ch{org_name}, \%ch);
          set_session_val($dbh, $us_fk, "message", "goodmessage",
            get_message("SUCCESS_MODIFY_SPECIAL_CENTER", "added"));
          my $url = index_url($dbh);
          print "Location: $url\n\n";  
        }
        else
        {
          $ch{step} = "";
          display_page($dbh, $us_fk, $co, \%ch);
        }
    }
    $dbh->disconnect;
    exit();
}

sub display_page
{
  my ($dbh, $us_fk, $co,  $chref) =@_;

  my $headerfile = "/site/webtools/header.html";
  my $footerfile = "/site/webtools/footer.html";

  $chref->{htmltitle} = "Add a special center ";
  $chref->{help} = set_help_url($dbh, "add_a_special_center");
  $chref->{htmldescription} = "This page can be used to add a special center.";
  $chref->{select_logo} = select_fi_fk($dbh, $us_fk, "logo");
  $chref->{select_icon} = select_fi_fk($dbh, $us_fk, "icon");
  my $allhtml = get_allhtml($dbh, $us_fk, "admin_addorg.html", 
    "$headerfile", 
    "$footerfile", $chref);


  print $co->header;
  print "$allhtml\n";
  print $co->end_html;
 
}
