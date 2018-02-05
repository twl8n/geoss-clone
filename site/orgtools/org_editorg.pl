use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    
    %ch = $co->Vars();
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "orgtools/org_editorg.cgi");
    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("message","errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }

    if ((!is_administrator($dbh, $us_fk)) && (! is_org_curator($dbh, $us_fk)))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        write_log("$us_fk runs org_editorg_.cgi");
        my $url = index_url($dbh, "webtools"); # see session_lib
        print "Location: $url\n\n";
        $dbh->disconnect;
        exit();
    };


   
    if ((! exists($ch{step}) || $ch{step} == 2 || (! $ch{step}))) 
    {
      draw_edit_org($dbh, $us_fk, $ch{org_pk})
    }
    elsif ($ch{step} == 3) {
        # step 3: edit the organization
        my $success  = edit_org_generic($dbh, $us_fk, \%ch);

        if ($success eq "true")
        {
          set_session_val($dbh, $us_fk, "message", "goodmessage",
            get_message("SUCCESS_MODIFY_SPECIAL_CENTER", "modified"));
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

  my $allhtml = readfile("org_editorg.html", "$headerfile", "$footerfile");
  $allhtml = fixradiocheck("needs_approval", 
    $chref->{needs_approval}, "checkbox", $allhtml);
  $chref->{htmltitle} = "Edit your organization";
  $chref->{htmldescription} = "This page can be used to edit a organization.";
 
  my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;

  print $co->header;
  print "$allhtml\n";
  print $co->end_html;
 
}
