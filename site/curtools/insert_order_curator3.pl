use strict;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_insert_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
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
        GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();

    }
	
    ($ch{owner_us_pk}, $ch{owner_gs_pk}) = split(',', $ch{pi_info});

    my $order_number = generate_order_number($dbh, $us_fk); # see sub below.
    
    #
    # 2003-08-19 Tom: don't trim() dates. Postgresql 7.3 gets upset. trim() forces the data type to be text.
    # 
    my $sql = "insert into order_info (order_number,created_by,org_fk) values (trim(?),?,?)";
    my $sth = $dbh->prepare($sql) || die "Insert failed: $sql\n$DBI::errstr\n";
    if ($ch{org_pk} ne "NULL")
    {
      $sth->execute($order_number, $ch{con_pk},$ch{org_pk}) || die "Insert failed: $sql\n$DBI::errstr\n";
    }
    else
    {
      $sth->execute($order_number, $ch{con_pk},undef) || die "Insert failed: $sql\n$DBI::errstr\n";
    }

    my $oi_pk = insert_security($dbh, $ch{owner_us_pk}, $ch{owner_gs_pk}, 0660);
    
    #
    # billing is implicitly secured via order_info
    #
    $sql = "insert into billing (oi_fk, chips_billed, rna_isolation_billed, analysis_billed) values ($oi_pk, '0'::bool, '0'::bool, '0'::bool)";
    
    $dbh->do($sql) || die "$sql\n$DBI::errstr\n";
    
    # email the creator with their order number
    # get the contact info by login 
    my ($login, $contact_fname, $contact_lname, $contact_email) = doq($dbh, "user_info2", $ch{con_pk});

    my $url = index_url($dbh, "webtools") . "/choose_order.cgi";
    my %info = 
    (
      "order_number" => $order_number,
      "edit_delete_url" => $url, 
      "email" => $contact_email,
    );

    my $email_file = "$WEB_DIR/site/curtools/order_created_email.txt";
    if ($contact_email)
    {
      email_generic($dbh, $email_file, \%info);
    }
    my $msg = get_message("SUCCESS_ORDER_CREATED", $order_number);
    set_session_val($dbh, $us_fk, "message", "goodmessage", $msg);
    $dbh->commit;
    $dbh->disconnect;
    
    my $url = index_url($dbh); # see session_lib
    print "Location: $url\n\n";
    
    exit(0);
}

