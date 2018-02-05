use strict;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "curtools/view_brief_curator.cgi");

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }


    if (! is_curator($dbh, $us_fk))
    {
      GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();

    }
    (my $allhtml, my $loop_template, my $tween, my $loop_template2) = readtemplate("view_brief_curator.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    my $sth = getq("order_report", $dbh);
    $sth->execute() || die "execute order_record\n$DBI::errstr\n";

    my $al_sth = getq("distinct_al_where_oi_pk", $dbh);
    
    my $alt_flag = 1; # colored
    my $hr;
    my $prev_order_number = "";
    my $loop_instance;
    while($hr = $sth->fetchrow_hashref())
    {
	($hr->{num_samples}, $hr->{num_hybs}) = doq($dbh, "oi_pk_sample_and_hyb_count", $hr->{oi_pk});
	$loop_instance = $loop_template;
	$loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
	if ($alt_flag)
	{
	    $loop_instance =~ s/#FFFFFF/#CCCCFF/sgi;
	}

	$al_sth->execute($hr->{oi_pk}) || die "execute distinct_al_where_oi_pk\n$DBI::errstr\n";
	my $al_hr;
	while($al_hr = $al_sth->fetchrow_hashref())
	{
	    ($al_hr->{al_samples}, $al_hr->{al_hybs}) = doq($dbh, "al_pk_sample_and_hyb_count", $al_hr->{al_pk}, $hr->{oi_pk});
	    my $loop_instance2 = $loop_template2;
	    if ($alt_flag)
	    {
		$loop_instance2 =~ s/#FFFFFF/#CCCCFF/sgi;
	    }
	    $loop_instance2 =~ s/{(.*?)}/$al_hr->{$1}/g;
	    $loop_instance =~ s/<loop_here2>/$loop_instance2<loop_here2>/s;
	}
	if ($alt_flag)
	{
	    $alt_flag = 0;
	}
	else
	{
	    $alt_flag = 1;
	}
	
	$allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }


    $allhtml =~ s/<loop_here>//s;
    $ch{oi_form} = oi_form($dbh); # see session_lib
    $ch{htmltitle} = "Brief Array Order View";
    $ch{help} = set_help_url($dbh, "brief_view_of_all_array_orders");
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";
    $dbh->disconnect();
    exit(0);
}

