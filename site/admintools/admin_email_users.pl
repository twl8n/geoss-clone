use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh=new_connection();
    my $us_fk = get_us_fk($dbh, "admintools/admin_email_users.cgi");

   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }

    if ((! exists($ch{step}) || (! $ch{step})))
    {
      display_page($dbh, $us_fk, $q, \%ch);
    }
    elsif ($ch{step} == 3)
    {
       my @emails = getq_email_addys($dbh, $us_fk, $ch{type}); 

       my $email;
       my $from = get_config_entry($dbh, "admin_email");

       foreach $email (@emails)
       {
         if ($email ne "")
         {
           warn "Sending mail to: $email from: $from";
           open (MAIL, '| /usr/lib/sendmail -t ');
           print MAIL "To: $email\nFrom: $from\n";
           print MAIL "Subject: $ch{subject}\n";
           print MAIL "$ch{email_text}\n";
           close MAIL;
         }
       }

       set_session_val($dbh, $us_fk, "message", "goodmessage",
        get_message("SUCCESS_EMAIL"));
       my $url = index_url($dbh);
       print "Location: $url\n\n";
    }
    $dbh->disconnect();
    exit();
}

sub display_page
{
  my ($dbh, $us_fk, $q,  $chref) =@_;

  my $headerfile = "/site/webtools/header.html";
  my $footerfile = "/site/webtools/footer.html";
  my $oldval = $chref->{user_type};
  $chref->{htmltitle} = "Email GEOSS users";
  $chref->{help} = set_help_url($dbh, "email_all_users"); 
  $chref->{htmldescription} = "This page can be used to email GEOSS users.";
  $chref->{user_type} = select_type("all");
  $chref->{user_type} =~ s/<select name="type">/<select name="type"><option value="all">All types<\/option>/;
  $chref->{user_type} = fixselect("user_type", $oldval,$chref->{user_type})       if ((defined $oldval) && ($oldval ne ""));
  my $allhtml = get_allhtml($dbh, $us_fk, "admin_email_users.html",
      "$headerfile", 
      "$footerfile", $chref);

  print $q->header;
  print "$allhtml\n";
  print $q->end_html;
}
