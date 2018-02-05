use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    
    %ch = $co->Vars();

    my $dbh = new_connection();
    my $headerfile = "/site/webtools/header.html";
    my $footerfile = "/site/webtools/footer.html";
    my $us_fk = get_us_fk($dbh, "admintools/admin_config.cgi");

   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs admin_config.cgi");
        print "Location: $url\n\n";
        exit();
    }

    if ((! exists($ch{step}) || $ch{step} == 2 || (! $ch{step}))) {

        my %ch = %{get_all_subs_vals($dbh, $us_fk, {})};

        $ch{htmltitle} = "Configure GEOSS";
        $ch{help} = set_help_url($dbh,"GEOSS_administration");
        $ch{htmldescription} = "This page can be used to configure GEOSS system variables";
        my $allhtml = readfile("admin_config.html",
         "$headerfile",
         "$footerfile");

        $allhtml = fixradiocheck("conf_user_data_load",
          $ch{user_data_load}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_add_curator_to_groups",
          $ch{add_curator_to_groups}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_allow_public_users",
          $ch{allow_public_users}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_allow_member_users",
          $ch{allow_member_users}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_data_publishing",
          $ch{data_publishing}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_array_center",
          $ch{array_center}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_analysis",
          $ch{analysis}, "checkbox", $allhtml);
        
        $allhtml = fixradiocheck("conf_ord_num_format",
          $ch{ord_num_format}, "radio", $allhtml);
        #$allhtml = fixradiocheck("conf_show_all_users",
        #  $ch{show_all_users}, "checkbox", $allhtml);

        my $newkey;
        foreach $newkey (keys(%ch))
        {
          $ch{"conf_" . $newkey} = $ch{$newkey};
        }

        $allhtml =~ s/{(.*?)}/$ch{$1}/g;

        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
        $dbh->disconnect();
        exit();
    }
    elsif ($ch{step} == 3) {
        # step 3: update contact information
        
        my $now = localtime;
        
        my $valid = 1;

        # Todo - need up update with our new check for email validity
        #if ((! Email::Valid->address($ch{config_contact})) &&
	#     ($ch{config_contact} ne "")) 
        #{
        #  my $msg = get_message("INVALID_INACTIVITY_LOGOUT", "Contact ");
        #  set_session_val($dbh, $us_fk, "message","errmessage", $msg);
        #  $valid = 0;
        #}
        #if (! Email::Valid->address($ch{contact_pub_data}))
        #{
        #  my $msg = get_message("INVALID_EMAIL_ADDRESS", 
        #  "Public Data Administrator ");
        #  set_session_val($dbh, $us_fk, "message","errmessage",$msg);
        #  $valid = 0;
        #}
        #if (! Email::Valid->address($ch{contact_admin}))
        #{
        #  my $msg = get_message("INVALID_EMAIL_ADDRESS", "Administrator ");
        #  set_session_val($dbh, $us_fk, "message","errmessage",$msg);
        #  $valid = 0;
        #}
        #if (! Email::Valid->address($ch{contact_curator}))
        #{
        #  set_session_val($dbh, $us_fk, "message","errmessage",$msg);
        #  $valid = 0;
        #}
        if ($ch{conf_inact_logout_general} < 1)
        {
          my $msg = get_message("INVALID_INACTIVITY_LOGOUT", "General ");
          set_session_val($dbh, $us_fk, "message","errmessage",$msg);
          $valid = 0;
        }
        if ($ch{conf_inact_logout_curator} < 1)
        {
          my $msg = get_message("INVALID_INACTIVITY_LOGOUT", "Array Center Staff ");
          set_session_val($dbh, $us_fk, "message","errmessage",$msg);
          $valid = 0;
        }

        if (defined $ch{conf_allow_public_users})
        {
          $ch{conf_allow_public_users} = 1;
        }
        else
        {
          $ch{conf_allow_public_users} = 0;
        }

        if (defined $ch{conf_allow_member_users})
        {
          $ch{conf_allow_member_users} = 1;
        }
        else
        {
          $ch{conf_allow_member_users} = 0;
        }

        if (defined $ch{conf_add_curator_to_groups})
        {
          $ch{conf_add_curator_to_groups} = 1;
        }
        else
        {
          $ch{conf_add_curator_to_groups} = 0;
        }

        if (defined $ch{conf_analysis})
        {
          $ch{conf_analysis} = 1;
        }
        else
        {
          $ch{conf_analysis} = 0;
        }
        

        if (defined $ch{conf_data_publishing})
        {
          $ch{conf_data_publishing} = 1;
        }
        else
        {
          $ch{conf_data_publishing} = 0;
        }
        

        if (defined $ch{conf_array_center})
        {
          $ch{conf_array_center} = 1;
        }
        else
        {
          $ch{conf_array_center} = 0;
        }

        if (defined $ch{conf_user_data_load})
        {
          $ch{conf_user_data_load} = 1;
        }
        else
        {
          $ch{conf_user_data_load} = 0;
        }
        
        
	if (($ch{conf_days_to_confirm} < 1) || ($ch{conf_days_to_confirm} > 30)) 
        {
          my $msg = get_message("INVALID_DAYS_TO_CONFIRM");
          set_session_val($dbh, $us_fk, "message","errmessage",$msg);
          $valid = 0;
	}
	if ($valid == 1)
        {
          my $sql = "update configuration set wwwhost=trim(?), " .
             "orgname=trim(?), curator_email=trim(?), " .
             "pub_data_email=trim(?), ". 
             "admin_email=trim(?), alt_curator_email=trim(?), " .
             "chip_data_path=trim(?), inact_logout_general=?, ". 
             "inact_logout_curator=?, inact_logout_administrator=?, ". 
             "bug_report_url=trim(?), linktext1=trim(?), linkurl1=trim(?), ". 
             "add_curator_to_groups=?, allow_public_users=?, ". 
             "allow_member_users=?, companion_geoss=trim(?), ". 
             "days_to_confirm=?, additional_path=trim(?), ". 
             "custom_desc1=trim(?), custom_news1=trim(?), ". 
             "custom_news2=trim(?), array_center=?, analysis=?, ". 
             "data_publishing=?, user_data_load=?, ord_num_format=trim(?)";
        
          my $cih = $dbh->prepare($sql);
        
          $cih->execute($ch{conf_wwwhost},
                      $ch{conf_orgname},
                      $ch{conf_curator_email},
                      $ch{conf_pub_data_email},
                      $ch{conf_admin_email},
                      $ch{conf_alt_curator_email},
		      $ch{conf_chip_data_path},
                      $ch{conf_inact_logout_general},
                      $ch{conf_inact_logout_curator},
                      $ch{conf_inact_logout_administrator},
                      $ch{conf_bug_report_url},
                      $ch{conf_linktext1},
                      $ch{conf_linkurl1},
                      "$ch{conf_add_curator_to_groups}",
                      "$ch{conf_allow_public_users}",
                      "$ch{conf_allow_member_users}",
                      "$ch{conf_companion_geoss}",
                      "$ch{conf_days_to_confirm}",
                      $ch{conf_additional_path},
                      $ch{conf_custom_desc1},
                      $ch{conf_custom_news1},
                      $ch{conf_custom_news2},
                      "$ch{conf_array_center}",
                      "$ch{conf_analysis}",
                      "$ch{conf_data_publishing}",
                      "$ch{conf_user_data_load}",
                      $ch{conf_ord_num_format},
)
                      || die "Update failed. sql: $sql\n$DBI::errstr\n";

          $dbh->commit;
          my $msg = get_message("SUCCESS_UPDATE_FIELDS");
          set_session_val($dbh, $us_fk, "message","errmessage",$msg);
        
        }
       
        # we have a special situation here:
        #   we want to use the configuration values from the table for
        #   the header and footer component of the page
        #   However, if the update has failed, we want to keep the 
        #   existing values in %ch for the page.  
        #   existing values should be in conf_

        my $allhtml = readfile("admin_config.html",
         "$headerfile",
         "$footerfile");

        $allhtml = fixradiocheck("conf_allow_public_users",
          $ch{conf_allow_public_users}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_allow_member_users",
          $ch{conf_allow_member_users}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_add_curator_to_groups",
          $ch{conf_add_curator_to_groups}, "checkbox", $allhtml);
        #$allhtml = fixradiocheck("conf_show_all_users",
        #  $ch{conf_show_all_users}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_user_data_load",
          $ch{conf_user_data_load}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_data_publishing",
          $ch{conf_data_publishing}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_array_center",
          $ch{conf_array_center}, "checkbox", $allhtml);
        $allhtml = fixradiocheck("conf_analysis",
          $ch{conf_analysis}, "checkbox", $allhtml);
        
        $allhtml = fixradiocheck("conf_ord_num_format",
          $ch{conf_ord_num_format}, "radio", $allhtml);
        #$allhtml = fixradiocheck("conf_show_all_users",
        #  $ch{show_all_users}, "checkbox", $allhtml);


        %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
        $ch{htmltitle} = "Configure GEOSS";
        $ch{help} = set_help_url($dbh,"GEOSS_administration");
        $ch{htmldescription} = "This page can be used to configure GEOSS system variables";
        $allhtml =~ s/{(.*?)}/$ch{$1}/g;

        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
    }
    $dbh->disconnect;
    exit();
}

