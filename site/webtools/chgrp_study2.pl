use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $dbh = new_connection();
    my %ch = $q->Vars;
    my $ref_fk = $ch{ref_fk};
    my $us_fk = get_us_fk($dbh, "webtools/chgrp_study1.cgi");

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
	    $sth->execute($us_fk, $ch{"select_gs_name_$xx"}, $perm, $ch{"ref_fk_$xx"}) || die "execute update_security\n$DBI::errstr\n";
	    my $msg = get_message("SUCCESS_UPDATE_GROUP_PERMS");
	    set_session_val($dbh, $us_fk, "message", "goodmessage", $msg);
	    set_ec_perms($dbh, $ch{"ref_fk_$xx"}, $perm, $ch{"select_gs_name_$xx"}, $us_fk);
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
        $url =~ s/(.*)\/.*/$1\/webtools\/chgrp_study1.cgi/;
    }
    print "Location: $url\n\n";
    $dbh->disconnect();
}

#
# Experimental conditions can be locked if there is an order using them that is locked.
# Don't allow an ec_pk to be group writable if it is not user_writable, and
# don't change the user write bit.
# Different exp. conds. in a study may have different lock status and therefore different permissions.
# To reiterate, the permissions of the study may not be correct for the exp. conds.
# 
sub set_ec_perms
{
    my ($dbh, $sty_pk, $permissions, $gs_fk, $us_fk) = @_;

    my $sth = getq("select_ec_pk", $dbh);
    my $update_sth = getq("update_security", $dbh, $us_fk);

    $sth->execute($sty_pk);
    while( (my $ec_pk, my $ec_permissions) = $sth->fetchrow_array())
    {
	if (! ($ec_permissions & 0200))
	{
	    $ec_permissions = ($permissions & 0550) # if ! user write (0200) then clear user and group write (0770-0220=0550) 
	}
	else
	{
	    $ec_permissions = $permissions;
	}
	$update_sth->execute($us_fk, $gs_fk, $ec_permissions, $ec_pk) || die "execute update_security\n$DBI::errstr\n";
    }
}
