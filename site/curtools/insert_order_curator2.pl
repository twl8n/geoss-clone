use strict;
require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars;
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "curtools/insert_order_curator1.cgi"); # also in session_lib

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }

    if (! is_curator($dbh, $us_fk))
    {
      GEOSS::Session->set_return_message("errmessage", "INVALID_PERMS");
      my $url = index_url($dbh, "webtools"); # see session_lib
      write_log("error: non administrator runs $0");
      print "Location: $url\n\n";
      exit();
    }

    
    ($ch{con_pk}, $ch{lname}, $ch{fname}) = split(',', $ch{esp_info});

    $ch{org_pk} = $ch{select_org};
    if ($ch{org_pk} ne "NULL")
    {
      my $sth = getq("select_organization", $dbh, $ch{org_pk});
      $sth->execute()
        || die "Query select_organization execute fails.\n$DBI::errstr\n";
      my $hr = $sth->fetchrow_hashref();

      $ch{org_name} = $hr->{org_name};
    }
    else
    {
      $ch{org_name} = "None";
    }
    $ch{user_pi} = user_pi($ch{con_pk});

    $ch{htmltitle} = "Array Order Creation";
    $ch{help} = set_help_url($dbh, "create_a_new_array_order");
    my $allhtml = get_allhtml($dbh, $us_fk, "insert_order_curator2.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
    print "Content-type: text/html\n\n$allhtml";
    $dbh->disconnect;
    exit(0);
}



