use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    
    %ch = $co->Vars();
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "admintools/admin_rm_inactive_users.cgi");

   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs admin_rm_inactive_users.cgi");
        print "Location: $url\n\n";
        exit();
    }

   
    if ((! exists($ch{step}) || (! $ch{step}))) 
    {
      display_page($dbh, $us_fk, $co, \%ch);
      $dbh->disconnect();
      exit();
    }
    elsif ($ch{step} == 2) {
        # step 2: remove inactive users
        my $headerfile = "/site/webtools/header.html";
        my $footerfile = "/site/webtools/footer.html";
        my $chref = {};
        $chref->{success}  = rm_inactive_users($dbh, $us_fk, \%ch);
        $chref->{success} =~ s/\n/<br>/g;
        $chref->{htmltitle} = "Remove Inactive Users";
        $chref->{help} = set_help_url($dbh, "remove_inactive_users");
        $chref->{htmldescription} = "";
        my $allhtml = get_allhtml($dbh, $us_fk, 
          "admin_rm_inactive_users_2.html", 
          "$headerfile", "$footerfile", $chref);

        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
    }
    $dbh->disconnect;
    exit();
}

sub display_page
{
  my ($dbh, $us_fk, $co,  $chref) =@_;

  my $headerfile = "/site/webtools/header.html";
  my $footerfile = "/site/webtools/footer.html";

  $chref->{select_type} = select_type("all");
  my $days = get_config_entry($dbh, "days_to_confirm");

  # if this is a redraw make sure that 
  # the appropriate values from select boxes are selected
  #  if ($chref->{type})
  #  {
  #     $chref->{select_type} =~ s/value="$chref->{type}"/value="$chref->{type}" selected/;
  #  }

  $chref->{htmltitle} = "Remove Inactive Users";
  $chref->{help} = set_help_url($dbh, "remove_inactive_users");
  $chref->{htmldescription} = "This page allows you to remove inactive users.  An inactive user is a user who has not logged in withing $days days.  This functionality is intended for users of type 'public', but can be used with any user type.";

  my $allhtml = get_allhtml($dbh, $us_fk, "admin_rm_inactive_users_1.html", 
    "$headerfile", 
    "$footerfile", $chref);

  print $co->header;
  print "$allhtml\n";
  print $co->end_html;
}
