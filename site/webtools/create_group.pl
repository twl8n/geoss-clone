use strict;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $message = "";
    
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/create_group.cgi");
    
    
    my $newg = $q->param("newgroup");
    if ($newg)
    {
        my $sql = "select gs_pk from groupsec where gs_name='$newg'";
        my $sth = $dbh->prepare($sql);
        $sth->execute() || die "Select failed: $sql\nDBI::errstr\n";
        if ($sth->rows() == 0)
        {
          new_group($dbh, $us_fk, $newg);
          my $url = index_url($dbh); # see session_lib
          print "Location: $url\n\n";
          $sth->finish();
          $dbh->disconnect();
          exit();
        }
        else
        {
          my $msg = get_message("NAME_MUST_BE_UNIQUE");
	        set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
        }
    }

    my %ch;
    $ch{newgroup} = $newg;
    $ch{htmltitle} = "Create a Group";
    $ch{help} = set_help_url($dbh, "create_a_new_group");
    $ch{htmldescription} = "";
    my $allhtml = get_allhtml($dbh, $us_fk, "create_group.html", "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);

    print "Content-type: text/html\n\n$allhtml\n";
    $dbh->disconnect();
}

sub new_group
{
    my $dbh = $_[0];
    my $us_fk = $_[1];
    my $newg = $_[2];
    
    my $get_fk_sql = "select nextval('guc_seq'::text)";
    my $gs_sql = "insert into groupsec (gs_pk, gs_owner, gs_name) values (?, ?, ?)";
    my $gl_sql = "insert into grouplink (us_fk, gs_fk) values (?, ?)";
    
    (my $gs_pk) = $dbh->selectrow_array($get_fk_sql) || die "$get_fk_sql\n$DBI::errstr\n";

    my $sth = $dbh->prepare($gs_sql);
    $sth->execute($gs_pk, $us_fk, $newg) || die "$gs_sql\n$DBI::errstr\n";

    $sth = $dbh->prepare($gl_sql);
    $sth->execute($us_fk, $gs_pk) || die "$gl_sql\n$DBI::errstr\n";

    # insert all curators into the new group if add_curator_to_groups 
    # is true

    my $add = get_config_entry($dbh, "add_curator_to_groups");
    if ($add == 1)
    {
       my $sth2 = getq("get_all_us_pks_by_type", $dbh, "curator");
       $sth2->execute() || die "get_all_us_pks_by_type\n$DBI::errstr\n";
       $sth = $dbh->prepare($gl_sql);
       while (my ($cur_us_pk) = $sth2->fetchrow_array())
       {
         if ($cur_us_pk != $us_fk)
         {
           $sth->execute($cur_us_pk, $gs_pk) || die "$gl_sql\n$DBI::errstr\n";
         }
       }
    }


    my $msg = get_message("SUCCESS_ADD_GROUP", $newg);
    set_session_val($dbh, $us_fk, "message", "goodmessage", $msg);
    $dbh->commit;
}
