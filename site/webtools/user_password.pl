use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh=new_connection();
    my $us_fk = get_us_fk($dbh, "webtools/user_password.cgi");

    if ((! exists($ch{step}) || (! $ch{step})))
    {
      display_page($dbh, $us_fk, $q, \%ch);
    }
    elsif ($ch{step} == 3)
    {
       $ch{login} = doq_get_login($dbh, $us_fk);
       my $success=change_password_generic($dbh, $us_fk,
        $ch{old_password}, $us_fk, $ch{new_pass1}, $ch{new_pass2});
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
  $chref->{htmltitle} = "Change Password";
  $chref->{help} = set_help_url($dbh, "change_my_password");
  $chref->{htmldescription} = "This page can be used to change your password.";
  my $allhtml = get_allhtml($dbh, $us_fk, "user_password.html",
      "$headerfile", 
      "$footerfile", $chref);

  print $q->header;
  print "$allhtml\n";
  print $q->end_html;
}
