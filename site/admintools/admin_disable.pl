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
    my $us_fk = get_us_fk($dbh, "admintools/admin_disableuser.cgi");
   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }

    $ch{htmltitle} = "Disable A User";
    $ch{help} = set_help_url($dbh, "disable_a_user");
    $ch{htmldescription} = "This page can be used to disable a user.  Once a user is disabled, they are unable to log on to GEOSS.";
    my $login = $ch{disable_user};
  
    if ((! exists($ch{step})) || (! $ch{step}))
    {
      $ch{disable_user} = select_users_to_disable($dbh, $us_fk);
      my $allhtml = get_allhtml($dbh, $us_fk, "admin_disable.html",
        "$headerfile", 
        "$footerfile", \%ch);

      print $q->header;
      print "$allhtml\n";
      print $q->end_html;
    }
    elsif ($ch{step} == 3)
    {
       #disable the user
       my $success = disable_user($dbh, $us_fk, $login);
      
       if ($success eq "true")
       {
         set_session_val($dbh, $us_fk, "message", "goodmessage", 
           get_message("SUCCESS_DISABLE_USER","$login"));
         my $url = index_url($dbh);
         print "Location: $url\n\n";
       }
       else
       {
          $ch{step} = 1;
          $ch{disable_user} = select_disable_users($dbh, $us_fk);
          my $allhtml = get_allhtml($dbh, $us_fk, "admin_disable.html",
            "$headerfile", "$footerfile", \%ch);

          print $q->header;
          print "$allhtml\n";
          print $q->end_html;
       }
    }
    
    $dbh->disconnect();
    exit();
}

sub disable_user
{
  my ($dbh, $us_fk, $login) = @_;

  my $sql;
  my $sth;
  my $success = "true";

  my $sql = "select us_pk,con_fk from usersec where login='$login'";
  $sth = $dbh->prepare($sql) || die "Prepare $sql\n$DBI::errstr";
  $sth->execute() || die "Execute $sql\n $DBI::errstr";
  my ($rm_us_fk, $con_fk) = $sth->fetchrow_array();
  $sth->finish();

  # the user is not allowed to disable themself
  if ($us_fk == $rm_us_fk)
  {
      $success = "false";
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("ERROR_DISABLE_SELF"));
  }

  if ($success eq "true")
  {
     #proceed with disable

     # change the user's type to disabled
     $sql = "update contact set type = 'disabled' where con_pk = '$con_fk'";
     $dbh->do($sql) || die "$sql\n$DBI::errstr\n";

  }
  $dbh->commit();
  return($success);  
}
