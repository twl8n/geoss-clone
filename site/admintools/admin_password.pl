use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh=new_connection();
    my $us_fk = get_us_fk($dbh, "admintools/admin_password.cgi");

   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs admin_password.cgi");
        print "Location: $url\n\n";
        exit();
    }

    if ((! exists($ch{step}) || (! $ch{step})))
    {
      display_page($dbh, $us_fk, $q, \%ch);
    }
    elsif ($ch{step} == 3)
    {
       my $user_pass = doq($dbh, "get_us_pk", $ch{user_login});
       my $us_fk_pass = doq_get_pw($dbh, $us_fk, $user_pass);
       my $success=change_password_generic($dbh, $us_fk, $us_fk_pass,
         $user_pass, $ch{new_pass1}, $ch{new_pass2}, "admin_");
        if ($success eq "true")
        {
          my $url = index_url($dbh);
          print "Location: $url\n\n";
        }
        else
        {
          $ch{step} = "";
          display_page($dbh, $us_fk, $q, \%ch);
        }
    }
    $dbh->disconnect();
    exit();
}

sub display_page
{
  my ($dbh, $us_fk, $q,  $chref) =@_;

  my $headerfile = "/site/webtools/header.html";
  my $footerfile = "/site/webtools/footer.html";
  my $oldval = $chref->{user_login};
  $chref->{htmltitle} = "Change User Password";
  $chref->{help} = set_help_url($dbh, "change_user_password");
  $chref->{htmldescription} = "This page can be used to change a user's password.";
  $chref->{user_login} = select_users($dbh, $us_fk, "user_login");
  $chref->{user_login} = fixselect("user_login", $oldval,$chref->{user_login})       if ((defined $oldval) && ($oldval ne ""));
  my $allhtml = get_allhtml($dbh, $us_fk, "admin_password.html",
      "$headerfile", 
      "$footerfile", $chref);

  print $q->header;
  print "$allhtml\n";
  print $q->end_html;
}
