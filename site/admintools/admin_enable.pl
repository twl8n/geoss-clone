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
    my $us_fk = get_us_fk($dbh, "admintools/admin_enable.cgi");
   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }

    $ch{htmltitle} = "Enable A User";
    $ch{help} = set_help_url($dbh, "enable_a_user");
    $ch{htmldescription} = "This page can be used to enable a disabled user.";
    my $login = $ch{enable_user};
  
    if ((! exists($ch{step})) || (! $ch{step}))
    {
      $ch{enable_user} = select_users_to_enable($dbh, $us_fk);
      $ch{select_type} = select_type("all");

      my $allhtml = get_allhtml($dbh, $us_fk, "admin_enable.html",
        "$headerfile", 
        "$footerfile", \%ch);

      print $q->header;
      print "$allhtml\n";
      print $q->end_html;
    }
    elsif ($ch{step} == 3)
    {
       #enable the user
       my $success = enable_user($dbh, $us_fk, $login, $ch{type});
      
       if ($success eq "true")
       {
         set_session_val($dbh, $us_fk, "message", "goodmessage", 
           get_message("SUCCESS_ENABLE_USER","$login"));
         my $url = index_url($dbh);
         print "Location: $url\n\n";
       }
       else
       {
          $ch{step} = 1;
          $ch{enable_user} = select_enable_users($dbh, $us_fk);
          my $allhtml = get_allhtml($dbh, $us_fk, "admin_enable.html",
            "$headerfile", "$footerfile", \%ch);

          print $q->header;
          print "$allhtml\n";
          print $q->end_html;
       }
    }
    
    $dbh->disconnect();
    exit();
}

sub enable_user
{
  my ($dbh, $us_fk, $login, $type) = @_;

  my $sql;
  my $sth;
  my $success = "true";

  my $sql = "select us_pk,con_fk from usersec where login='$login'";
  $sth = $dbh->prepare($sql) || die "Prepare $sql\n$DBI::errstr";
  $sth->execute() || die "Execute $sql\n $DBI::errstr";
  my ($rm_us_fk, $con_fk) = $sth->fetchrow_array();
  $sth->finish();

  if ($success eq "true")
  {
     #proceed with enable

     # change the user's type from disabled to the new type
     $sql = "update contact set type = '$type' where con_pk = '$con_fk'";
     $dbh->do($sql) || die "$sql\n$DBI::errstr\n";

  }
  $dbh->commit();
  return($success);  
}
