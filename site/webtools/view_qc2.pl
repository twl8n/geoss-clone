use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/view_qc1.cgi");
    
    (my $allhtml, my $loop_template) = readtemplate("view_qc2.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    my $sth = getq("get_qc_secure", $dbh, $us_fk);
    $sth->execute($ch{qc_fk}) || die "execute get_qc\n$DBI::errstr\n";
    my $hr = $sth->fetchrow_hashref();
    $sth->finish();
    foreach my $key (keys(%{$hr}))
    {
	$ch{$key} = $hr->{$key};
    }


    $sth = getq("get_qc_housekeeping", $dbh);
    $sth->execute($ch{qc_pk}) || die "execute get_qc_controls\n$DBI::errstr\n";
    while($hr = $sth->fetchrow_hashref())
    {
	my $loop_instance = $loop_template;
	$loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
	$allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }

    $allhtml =~ s/<loop_here>//s;

    $ch{action_url} = index_url($dbh);
    $ch{action_url} .="/view_qc1.cgi";
    $ch{htmltitle} = "View Quality Control";
    $ch{help} = set_help_url($dbh, "view_quality_control_records");
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";
    exit(0);

}

