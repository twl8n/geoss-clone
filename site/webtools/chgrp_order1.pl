use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $dbh = new_connection();
    my %ch = $q->Vars();
    my $us_fk = get_us_fk($dbh, "webtools/chgrp_order1.cgi");

    if (is_public($dbh, $us_fk))
    {
      set_return_message($dbh, $us_fk, "message","errmessage", "INVALID_PERMS");
      my $url = index_url($dbh, "webtools");
      print "Location: $url\n\n";

    }
    else
    {
    # list all the orders I own

    (my $all_html, my $loop_template) = readtemplate("chgrp_order1.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    #
    # Do the whole field_xx thing so all fields are in one big form,
    # and any number of records can be change with a single submit.
    # 
    my $sth = getq("orders_i_own", $dbh, $us_fk);
    $sth->execute() || die "Query orders_i_own execute fails.\n$DBI::errstr\n";
    my $rows = $sth->rows();
    my $hr;  #hash ref
    my $xx = 0;
    while( $hr = $sth->fetchrow_hashref())
    {
	# study_name, ref_fk, gs_fk, gs_name, permissions, user_read, user_write, group_read, group_write
	$hr->{select_gs_name} = select_gs_name($dbh, $us_fk);
	$hr->{octal_permissions} = sprintf("%o", $hr->{permissions});
	if ($hr->{user_read} == 1)
	{
	    $hr->{user_read} = "Yes";
	}
	if ($hr->{user_write} == 1)
	{
	    $hr->{user_write} = "Yes";
	}
	else
	{
	    $hr->{user_write} = "Locked";
	}
	my $loop_instance = $loop_template;
	$loop_instance =~ s/{(.*?)}/$hr->{$1}/gs;
	$loop_instance = fixselect("select_gs_name", $hr->{gs_fk}, $loop_instance);
	$loop_instance = fixradiocheck("group_read", $hr->{group_read}, "checkbox", $loop_instance);
	$loop_instance = fixradiocheck("group_write", $hr->{group_write}, "checkbox", $loop_instance);
	$loop_instance =~ s/name=\"(.*?)\"/name=\"$1_$xx\"/g;
        $xx++;
	$all_html =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }
    $all_html =~ s/<loop_here>//s;

    $ch{htmltitle} = "Manage Group and Permissions for Orders";
    $ch{help} = set_help_url($dbh,
      "change_group_ownership_and_read_or_write_permissions_for_existing_array_orders");
    $ch{htmldescription} = "Change the group ownership and/or group read-write permissions.";
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $all_html =~ s/{(.*?)}/$ch{$1}/sg;

    print "Content-type: text/html\n\n$all_html\n";
    }
    $dbh->disconnect();
}

