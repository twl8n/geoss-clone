use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

# You can test this with a query like:
# select ref_fk,gs_fk,permissions from groupref where ref_fk in ((select smp_pk from sample,arraymeasurement where oi_fk=51 and smp_fk=smp_pk) union (select am_pk from sample,arraymeasurement where oi_fk=51 and smp_fk=smp_pk));
# where you put in the oi_pk of your choice instead of 51.


main:
{
    my $q = new CGI;
    my $dbh = new_connection();
    my %ch = $q->Vars;
    my $ref_fk = $ch{ref_fk};
    my $us_fk = get_us_fk($dbh, "webtools/chgrp_order1.cgi");
    my $message = "";

    #
    # This is a powerful (and robust?) way to process
    # as many _xx fields as existed in the submitted CGI form.
    # The older scripts counted some field to get a max xx. This is more elegant.
    # The older stuff also required two hashes %all_ch and %ch. 
    # Here we only have one hash, but the keys must always have the _$xx on the end,
    # and the keys must always be interpolated.
    #
    for(my $xx=0; exists($ch{"gs_fk_$xx"}); $xx++)
    {
	my $perm = $ch{"permissions_$xx"};
	#
	# Users can't change user read or user write under most circumstances.
	# If not user_write, don't allow group_write
	#
	if ($ch{"group_read_$xx"})
	{
	    $perm |= 040; # 040 octal = 32 decimal
	}
	else
	{
	    $perm &= 0730; # 0730 is 0770-040 or in decimal (511-32)
	}
	if ($ch{"group_write_$xx"} && ($ch{"permissions_$xx"} & 0200))
	{
	    $perm |= 020; # 020 is 16 decimal
	}
	else
	{
	    $perm &= 0750; # 0750 is 0770-020 or in decimal (511-16)
	}

	#
	# Check that $ch{"select_gs_name_$xx"} is a group I own
	# The update_db query also has this constraint.
	#
	my $sth = getq("select_gs_name", $dbh, $us_fk);
	$sth->execute() || die "Query select_gs_name execute fails.\n$DBI::errstr\n";
	my %gname;
	while( (my $gs_pk, my $gs_name) = $sth->fetchrow_array())
	{
	    $gname{$gs_pk} = $gs_name;
	}

	if (exists($gname{$ch{"select_gs_name_$xx"}}))
	{
	    $sth = getq("update_security", $dbh, $us_fk);
	    $sth->execute($us_fk,                   # us_fk
			  $ch{"select_gs_name_$xx"},# gs_fk
			  $perm,                    # permissions
			  $ch{"ref_fk_$xx"})        # ref_fk
		|| die "execute update_security\n$DBI::errstr\n";
            my $msg = get_message("SUCCESS_UPDATE_GROUP_PERMS");
            set_session_val($dbh, $us_fk, "message","errmessage", $msg);
	    #
	    # The sample table has an oi_fk. Table arraymeasurement has an smp_fk. Therefore
	    # it makes sense to call some hybridization permissions code from inside the loop 
	    # where we know the smp_pk.
	    #
	    set_sample_hyb_perms($dbh, $ch{"ref_fk_$xx"}, $perm, $ch{"select_gs_name_$xx"}, $us_fk);
	}
	else
	{
	    my $selected_gs = $ch{"select_gs_name_$xx"};
	    write_log("User is not owner of $selected_gs");
	}
    }
    $dbh->commit();
    my $url = index_url($dbh); # see session_lib
    if (is_value($dbh, $us_fk, "message", ""))
    {
        $url =~ s/(.*)\/.*/$1\/webtools\/chgrp_order1.cgi/;
    }
    $dbh->disconnect();
    print "Location: $url\n\n";
    exit();
}


sub set_sample_hyb_perms
{
    my ($dbh, $oi_pk, $permissions, $gs_fk, $us_fk) = @_;

    my $smp_sth = getq("select_smp_pk", $dbh);
    my $am_sth = getq("select_am_pk", $dbh);
    my $update_sth = getq("update_security", $dbh, $us_fk);

    $smp_sth->execute($oi_pk) || die "Query select_smp_pk execute fails.\n$DBI::errstr\n";
    while( (my $smp_pk, my $smp_permissions) = $smp_sth->fetchrow_array())
    {
	$am_sth->execute($smp_pk) || die "Query select_am_pk excute fails.\n $DBI::errstr\n";
	while( (my $am_pk, my $am_permissions) = $am_sth->fetchrow_array())
	{
	    # Yes, we are ignoring $am_permissions that we just got back from the db.
	    $update_sth->execute($us_fk, $gs_fk, $permissions, $am_pk) || die "execute update_security\n$DBI::errstr\n";
	}
	# Yes, we are ignoring $smp_permissions that we just got back from the db.
	$update_sth->execute($us_fk, $gs_fk, $permissions, $smp_pk) || die "execute update_security\n$DBI::errstr\n";
    }
}
