use strict;
use URI::Escape;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $q = new CGI;
  my %ch=$q->Vars();

  my $dbh = new_connection();

  if ($ch{step} eq "Specify account fields")
  {
    my $acctref = { 
     "login" => $ch{login},
     "pi_login" => $ch{pi_login} || $ch{login},
     "type" => $ch{type},
     "password" => $ch{password},
     "confirm_password" => $ch{confirm_password},
     "contact_fname" => $ch{contact_fname},
     "contact_lname" => $ch{contact_lname},
     "contact_email" => $ch{contact_email},
     "org_mail_address" => $ch{org_mail_address},
    };


    my $verify = verify_acct_generic($dbh, "command", $acctref);
    if ($verify ne "") 
    {
      $ch{step} = "Select account type";
      $ch{message} = $verify;
    }
    else
    {
      if ($ch{type} eq "public")
      {
        my $create = create_acct_generic($dbh, "command", $acctref);
        if ($create !~ /Successfully added user/)
        {
          $ch{message} = $create;
        }
      }
      else  # account type is not public
      {
        my $email_file = "$WEB_DIR/site/account_request_adm_email.txt";
        my $admin_email = get_config_entry($dbh, "admin_email");

        my $create_url =  index_url($dbh) . "/admintools/admin_adduser.cgi?";
        while (my ($key, $value) = each(%ch))
        {
          $create_url .= uri_escape($key) . "=" . uri_escape($value) . 
            "&" if ($value ne "");
        };
        #remove trailiing &
        chop($create_url);       
        my $set_type;
        $set_type = "Public User" if ($ch{type} eq "public");
        $set_type = "Experiment Set Provider" 
         if ($ch{type} eq "experiment_set_provider");
        $set_type = "Curator" if ($ch{type} eq "curator");
        $set_type = "Administrator" if ($ch{type} eq "administrator");
    
        my $info = 
        {
          "email" => $admin_email,
          "type" => "$set_type",
          "contact_email" => "$ch{contact_email}",
          "password" => "$ch{password}",
          "confirm_password" => "$ch{password}",
          "pi_login" => "$ch{pi_login}",
          "contact_fname" => "$ch{contact_fname}",
          "contact_lname" => "$ch{contact_lname}",
          "credentials" => "$ch{credentials}",
          "organization" => "$ch{organization}",
          "contact_phone" => "$ch{contact_phone}",
          "org_phone" => "$ch{org_phone}",
          "org_toll_free_phone" => "$ch{org_toll_free_phone}",
          "org_fax" => "$ch{org_fax}",
          "org_email" => "$ch{org_email}",
          "org_mail_address" => "$ch{org_mail_address}",
          "url" => "$ch{url}", 
          "create_url" => "$create_url"
        };

        #email request to the administrators
        email_generic($dbh, $email_file, $info);
      }
    }
  }
  draw_req($dbh, \%ch); 
  $dbh->disconnect;
}

sub draw_req
{
    my ($dbh, $chref) = @_;

    my %ch = %$chref;
    $ch{message} =~ s/\n/<br>/g;
    $ch{message} = "<font color=\"#FF0000\">$ch{message}</font>";
    my $htmlfile;
    if ($ch{step} eq "Specify account fields")
    {
      $htmlfile = "req_account3.html";
    }
    elsif(($ch{step} eq "Select account type") && ($ch{type} eq "public"))
    {
      $htmlfile = "req_account2_pub.html";
    }
    elsif(($ch{step} eq "Select account type") && 
          (($ch{type} eq "curator") ||
           ($ch{type} eq "experiment_set_provider") ||
           ($ch{type} eq "administrator"))
         )
    {
      $htmlfile = "req_account2_mem.html";
    }
    else
    {
      $htmlfile = "req_account1.html";
    }

    my $confref = get_all_config_entries($dbh);
    @ch{keys %$confref} = values %$confref;
    $ch{version} = $VERSION;
    $ch{htmltitle} = "Request GEOSS account";
    $ch{htmldescription} = "Use this form to request a GEOSS account";
    
    if (($ch{step} ne "Select account type") &&
        ($ch{step} ne "Specify account fields"))
    {
      my $allow_public = get_config_entry($dbh, "allow_public_users");
      my $allow_member = get_config_entry($dbh, "allow_member_users");
      my $companion = get_config_entry($dbh, "companion_geoss");
      my @disallow;
      my @allow;
      if ($allow_public == 1 )
      {
        push @allow, "public";
      }
      else
      {
        push @disallow, "public";
      }
      if ($allow_member == 1)
      {
        push @allow, ("experiment_set_provider", "curator", "administrator");
      }
      else
      {
        push @disallow, ("experiment_set_provider", "curator", "administrator");
      }

      $ch{select_type} = select_type(\@allow);
      $htmlfile = "req_account2_none.html" if ($#allow == -1);
      
      if ($#disallow != -1)
      {
        $ch{disallow_type} = "<tr><td colspan = 2>The following user types are not supported on this installation:<br><ul>";
        foreach (@disallow)
        {
          $ch{disallow_type} .= "<li>$_</li>";
        }
        $ch{disallow_type} .= "</ul>";
        if ("companion" ne "")
        {
          $ch{disallow_type} .= "Try <a href=\"$companion\">the companion GEOSS installation</a> if you require an account of a type that is not supported on this installation.<br></td></tr>"
         }
      }
    }
    $ch{select_pi_login} = select_pi_login($dbh, "1"); 
    my ($allhtml, $loop_template)  = readtemplate($htmlfile, "site/header.html", "site/footer.html");
      
   if(($ch{step} eq "Select account type") && 
      (($ch{type} eq "curator") ||
       ($ch{type} eq "experiment_set_provider") ||
       ($ch{type} eq "administrator")))
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
          $loop_instance =~ s/value="$chref->{org}"/value="$chref->{org}" selected/;
        }
        $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
        $allhtml = fixselect("$org", $ch{$org}, $allhtml);
      }
      $allhtml =~ s/<loop_here>//s;
    }

    $allhtml =~ s/{(.*)}/$ch{$1}/g;
    $allhtml = fixselect("pi_login", $ch{pi_login}, $allhtml);

    print "Content-type: text/html\n\n$allhtml\n";
}
