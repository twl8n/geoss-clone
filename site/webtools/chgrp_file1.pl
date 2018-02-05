use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $dbh = new_connection();
    my %ch = $q->Vars();
    my $us_fk = get_us_fk($dbh, "webtools/chgrp_file1.cgi");

    my %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};


    # list all the studies, orders, files I own

    (my $all_html, my $loop_template) = readtemplate("chgrp_file1.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    #
    # Do the whole field_xx thing so all fields are in one big form,
    # and any number of records can be change with a single submit.
    # 
    my $sth = getq("files_i_own", $dbh, $us_fk);
    $sth->execute() || die "Query files_i_own execute fails.\n$DBI::errstr\n";
    my $rows = $sth->rows();
    my $hr;  #hash ref
    my $xx = 0;
    while( $hr = $sth->fetchrow_hashref())
    {
	# study_name, ref_fk, gs_fk, gs_name, permissions, user_read, user_write, group_read, group_write
	$hr->{select_gs_name} = select_gs_name($dbh, $us_fk); # see session_lib
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
    $ch{htmltitle} = "Change File Group and/or Permissions";
    $ch{help} = set_help_url($dbh,
      "change_group_ownership_and_read_or_write_permissions_for_existing_files");
    $ch{htmldescription} = "To reassign the group a file belongs to, select the new group from the group drop down.  Permissions can be set by selecting appropriate checkboxes.";
    $all_html =~ s/{(.*?)}/$ch{$1}/sg;

    print "Content-type: text/html\n\n$all_html\n";
    $dbh->disconnect();
}
