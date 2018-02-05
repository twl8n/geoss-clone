use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

main:
{
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "orgtools/choose_organization.cgi");

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }


    if ((!is_administrator($dbh, $us_fk)) && (! is_org_curator($dbh, $us_fk)))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage", 
          get_message("INVALID_PERMS"));
        write_log("$us_fk runs choose_organization.cgi");
        my $url = index_url($dbh, "webtools"); # see session_lib
        print "Location: $url\n\n";
        $dbh->disconnect;
        exit();
    };
    my $q = new CGI;
    my $action = $q->param("action");
    if (($action ne "org_editorg") &&
        ($action ne "org_edit_mem") && 
        ($action ne "org_approve") &&
        ($action ne "org_reports"))
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
          get_message("ERROR_ACTION"));
    }

    my $allhtml;
    ($allhtml, my $loop_template) = readtemplate("choose_organization.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    my $sth = getq("get_orgs_by_user", $dbh, $us_fk);
    $sth->execute() 
      || die "Query get_orgs_by_user execute fails.\n$DBI::errstr\n";
    my $hr;
    my $count = 0;
    my $org_pk = 0;
    while( $hr = $sth->fetchrow_hashref())
    {
        $count++;
        $org_pk = $hr->{org_pk};
	my $loop_instance = $loop_template;
        $hr->{action} = $action . ".cgi";
        $hr->{actiontxt} = "Edit" if ($action =~ /org_editorg/);
        $hr->{actiontxt} = "Edit Members of" if ($action eq "org_edit_mem");
        $hr->{actiontxt} = "Approve orders for " if ($action eq "org_approve");
        $hr->{actiontxt} = "View reports for " if ($action eq "org_reports");
	$loop_instance =~ s/{(.*?)}/$hr->{$1}/sg;
	$allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }
    $allhtml =~ s/<loop_here>//s;
    if ($count == 1)
    {
      draw_edit_org($dbh, $us_fk, $org_pk) if ($action eq "org_editorg"); 
      draw_edit_mem($dbh, $us_fk, $org_pk) if ($action eq "org_edit_mem"); 
      draw_org_approve($dbh, $us_fk, {"org_pk" => $org_pk}) if ($action eq "org_approve");
      draw_org_reports($dbh, $us_fk, {"org_pk" => $org_pk}) if ($action eq "org_reports");
    }
    else
    {
      my %ch = %{get_all_subs_vals($dbh, $us_fk, {})};

      $ch{htmltitle} = "Choose an Organization";
      $ch{htmldescription} = "Select an organization to edit."; 
      $allhtml =~ s/{(.*?)}/$ch{$1}/g;

      print "Content-type: text/html\n\n$allhtml\n";
    }
    $dbh->disconnect();
}
