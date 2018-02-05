use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    
    %ch = $co->Vars();
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "admintools/admin_adduser.cgi");

   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs admin_adduser.cgi");
        print "Location: $url\n\n";
        exit();
    }

   
    if (($ch{step} eq "Specify account fields") ||
        (! $ch{step}) ||
        (!exists($ch{step})))
    {
      display_page($dbh, $us_fk, $co, \%ch);
      $dbh->disconnect();
      exit();
    }
    elsif ($ch{step} eq "Add User") {
        my $verify = verify_acct_generic($dbh, $us_fk, \%ch);
        my $success;
        if ($verify eq "")
        {
          $success  = create_acct_generic($dbh, $us_fk, \%ch);
        }
        if ($success eq "true")
        {
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

  my @allowed = ("administrator");

  if (get_config_entry($dbh, "array_center")) 
  {
    push @allowed, "curator";
  }
  if (get_config_entry($dbh, "allow_member_users") == 1)
  {
    push @allowed, "experiment_set_provider";
  }
  if (get_config_entry($dbh, "allow_public_users") == 1)
  {
    push @allowed, "public";
  }

  $chref->{select_type} = select_type(\@allowed);
  $chref->{select_pi_login} = select_pi_login($dbh, $us_fk);


  # if this is a redraw (due to an error when adding), make sure that 
  # the appropriate values from select boxes are selected
  if ($chref->{type})
  {
     $chref->{select_type} =~ s/value="$chref->{type}"/value="$chref->{type}" selected/;
  }
  if ($chref->{pi_login})
  {
     $chref->{select_pi_login} =~ s/value="$chref->{pi_login}"/value="$chref->{pi_login}" selected/;
  }

  $chref->{htmltitle} = "Add A User";
  $chref->{help} = set_help_url($dbh, "add_a_user");
  $chref->{htmldescription} = "This page can be used to add a GEOSS user.";
  (my $allhtml, my $loop_template) = readtemplate("admin_adduser.html", "/site/webtools/header.html", "/site/webtools/footer.html");
  if (get_config_entry($dbh, "array_center"))
  {
    my $sth=getq("select_all_organizations", $dbh);
    $sth->execute() || die "execute \n$DBI::errstr\n";
    my $hr;
    while($hr = $sth->fetchrow_hashref())
    {
      my $loop_instance = $loop_template;
      $loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
# redraw stuff
      my $org=$hr->{org_name};
      if ($chref->{$org})
      {
        $loop_instance =~ s/value="$chref->{$org}"/value="$chref->{$org}" selected/;
      }
      $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }
  }
  $allhtml =~ s/<loop_here>//s;

  my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  print $co->header;
  print "$allhtml\n";
  print $co->end_html;
 
}
