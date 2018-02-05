use strict;
use CGI;
use GEOSS::Session;
use GEOSS::Database;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $us_fk = GEOSS::Session->user->pk;

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }

    if(!is_curator($dbh, $us_fk))
    {
      GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
      my $url = index_url($dbh, "webtools"); # see session_lib
        warn("non administrator user pk $us_fk runs $0");
      print "Location: $url\n\n";
      exit();
    }

    my $us_fk = get_us_fk($dbh, "curtools/view_account.cgi");
    my $sql = "select us_pk from usersec where login='$ch{login}'";
    my ($login_us_fk) = $dbh->selectrow_array($sql) || die "Select failed: $sql\n$DBI::errstr\n";
    
    my $valid = 0;
    # get organizations the requested user is part of 
    my $sth = getq("get_orgs_by_user", $dbh, $login_us_fk);
    $sth->execute() || die "get_orgs_by_user $login_us_fk $DBI::errstr\n";
    # foreach organization, check if the requestor is part of that org
    my $org_pk;
    while (($org_pk, undef) = $sth->fetchrow_array())
    {
      $valid = 1 if (is_org_curator($dbh, $us_fk, $org_pk)); 
    }
    if ((! (is_curator($dbh, $us_fk))) && (! $valid)) 
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }
    
    my $sql = "select con_fk from usersec where login='$ch{login}'";
    my ($con_fk) = $dbh->selectrow_array($sql) || die "Select failed: $sql\n$DBI::errstr\n";
    $sql = "select * from contact where con_pk=$con_fk";
    my $chashref = $dbh->selectrow_hashref($sql) || die "$sql\n$DBI::errstr\n";
    %ch = (%ch, %$chashref);
    
    $ch{htmltitle} = "Account Information";
    $ch{help} = set_help_url($dbh, "view_account_information");
    my $allhtml = get_allhtml($dbh, $us_fk, "view_account.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
    
    print $q->header;
    print "$allhtml\n";
    print $q->end_html;
    $dbh->disconnect();
    exit();
}

