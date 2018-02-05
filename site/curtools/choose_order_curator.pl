use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $debug;
    my $sql;
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "curtools/choose_order_curator.cgi");
    
    my $fclause;
    my $wclause;

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }

    if (! is_curator($dbh, $us_fk))
    {
      GEOSS::Session->set_return_message("errmessage",
          "INVALID_PERMS");
      my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();

    }

    #
    #
    (my $allhtml, my $loop_template, my $tween, my $loop_template2) = readtemplate("choose_order_curator.html", "/site/webtools/header.html", "/site/webtools/footer.html"); 

    my $recordlist = makelist($dbh, $us_fk, $loop_template, $loop_template2);
    my $oi_form = oi_form($dbh);
    $allhtml =~ s/<loop_here>/$recordlist/sg;
    $allhtml =~ s/{oi_form}/$oi_form/sg;

    my %ch;
    $ch{debug} = $debug;
    $ch{htmltitle} = "Array Order Display";
    $ch{help} = set_help_url($dbh, "array_center_staff_gui");
    $ch{htmldescription} = "";
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n";
    print "$allhtml\n";
    
    $dbh->disconnect;
    exit(0);
}

sub makelist
{
    my ($dbh, $us_fk, $loop_template, $loop_template2) = @_;

    # All the sql is in sql_lib
    my $sth =         getq("orders_by_order_number", $dbh);
    my $billing_sth = getq("billing_info", $dbh);
    my $sample_sth =  getq("sample_ec_and_study", $dbh);
    my $owner_sth =   getq("order_owner_info", $dbh);
    my $am_sth =      getq("am_sample_order_info", $dbh);
    my $al_sth =      getq("al_name", $dbh);

    my $reclist;
    #
    # Put all necessary data in to the $rec hash, and just loop through
    # the keys substituting into the HTML template.
    # This assumes that field names, and anything added to the $rec hash
    # is unique!
    # 
    #write_log("exe orders_by_order_number");
    $sth->execute() || die "execute orders_by_order_number\n$DBI::errstr\n";
    my $o_hr; # order_info hash ref
    while($o_hr = $sth->fetchrow_hashref())
    {
      my $sth = getq("select_sample_by_oi_fk", $dbh);
      $sth->execute($o_hr);
      my $smps;
      my $x;

      while ($x = $sth->fetchrow_array())
      {
        $smps .= "$x,";
      }
      chop($smps);
 
         update_hn($smps);
         my ($isolations, $num_samples) = calcIsolations($dbh, $us_fk, $o_hr->{oi_pk});
   
        $o_hr->{isolations} = $isolations if (! defined $o_hr->{isolations});
        $o_hr->{number_of_samples} = $num_samples;

	#write_log("exe order_owner_info: $o_hr->{oi_pk}");
        $owner_sth->execute($o_hr->{oi_pk}) || die "execute order_owner_info\n$DBI::errstr\n";
        ($o_hr->{login},
	 $o_hr->{contact_fname},
	 $o_hr->{contact_lname},
	 $o_hr->{contact_phone},
	 $o_hr->{us_pk}) = $owner_sth->fetchrow_array();

	($o_hr->{created_by_login},
	 $o_hr->{created_by_fname},
	 $o_hr->{created_by_lname}) = doq($dbh, "order_creator_info", $o_hr->{oi_pk});

       $o_hr->{org_name} = get_order_org_name($dbh, $us_fk, $o_hr->{oi_pk});
        my $loop_instance = $loop_template;
        my $reclist2; # list of loop_instance2 records
        $reclist2 = "";

	#write_log("exe billing_info: $o_hr->{oi_pk}");
        $billing_sth->execute($o_hr->{oi_pk}) || die "execute billing_info\n$DBI::errstr\n";
        my $b_hr = $billing_sth->fetchrow_hashref();

	#write_log("exe am_sample_order_info: $o_hr->{oi_pk}");
        $am_sth->execute($o_hr->{oi_pk}) || die "execute am_sample_order_info\n$DBI::errstr\n";
        my $s_hr; # Messy. Used for results from several queries.
        verify_order_completeness($dbh, $us_fk, $o_hr->{oi_pk});
        my $num_loaded = 0;
        my $am_count = 0;
        while($s_hr = $am_sth->fetchrow_hashref())
        {
            $am_count++;
            $s_hr->{al_name} = "None selected";
            if ($s_hr->{al_fk} > 0)
            {
		#write_log("exe al_name: $s_hr->{al_fk}");
                $al_sth->execute($s_hr->{al_fk}) || die "execute al_name\n$DBI::errstr\n";
                ($s_hr->{al_name}) = $al_sth->fetchrow_array();
            }
	    #write_log("exe sample_ec_and_study: $s_hr->{smp_pk}");
            $sample_sth->execute($s_hr->{smp_pk}) || die "execute sample_ec_and_study\n$DBI::errstr\n";
            ($s_hr->{timestamp}, $s_hr->{ec_name}, $s_hr->{abbrev_name}, $s_hr->{study_name}, $s_hr->{sty_pk}) = $sample_sth->fetchrow_array();
	    $sample_sth->finish();

            {
                verify_study($dbh, $us_fk, $o_hr->{us_pk}, $s_hr->{sty_pk}, 15, $s_hr->{study_name});
                verify_exp($dbh, $us_fk, $s_hr->{sty_pk}, 16, $s_hr->{ec_name}, $s_hr->{abbrev_name});
            }
            $s_hr->{timestamp} = sql2date($s_hr->{timestamp}); # sql2date() is in session_lib

            my $loop_instance2 = $loop_template2;
            #
            # Only one of the hash refs will hit, so it is ok
            # to have both on the right side of the regexp.
            #
            $loop_instance2 =~ s/{(.*?)}/$o_hr->{$1}$b_hr->{$1}$s_hr->{$1}/g;
	    my $loaded_flag = doq($dbh, "am_used_by_ams_date", $s_hr->{am_pk});
	    my $pending = doq($dbh, "am_used_by_ams", $s_hr->{am_pk});
            if ($loaded_flag)
            {
                $num_loaded++;
		# We don't have order_number, and don't need it.
		my $loaded = "<a href=\"view_qc_curator.cgi?state=0&qc_pk=$s_hr->{qc_fk}\">$loaded_flag</a>\n";
                $loop_instance2 =~ s/<form[^<].*?name=\"form1\".*?form>/$loaded/s;
            } elsif ($pending)
            {
		my $loaded = "Data currently loading";
                $loop_instance2 =~ s/<form[^<].*?name=\"form1\".*?form>/$loaded/s;

            }
            $reclist2 .= $loop_instance2;
        }
        $o_hr->{message} .= get_stored_messages($dbh, $us_fk);      
        if (($am_count > 0) && ($num_loaded == 0))
        {
          $o_hr->{load_all} = qq#<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td><form name="form2" method="post" action="load_data1.cgi"><input type="submit" name="submit_all" value="Load All"><input type="hidden" name="oi_pk" value="$o_hr->{oi_pk}"></form></td></tr>#
        }
        $loop_instance =~ s/{(.*?)}/$o_hr->{$1}$b_hr->{$1}/g;
        $loop_instance =~ s/\<loop_here2\>/$reclist2/s;	# no g, only one inner loop
        $loop_instance = fixradiocheck("locked",
                                       $o_hr->{locked},
                                       "checkbox",
                                       $loop_instance);
        $loop_instance = fixradiocheck("chips_ordered",
                                       $o_hr->{chips_ordered},
                                       "checkbox",
                                       $loop_instance);
        $loop_instance = fixradiocheck("have_chips",
                                       $o_hr->{have_chips},
                                       "checkbox",
                                       $loop_instance);
        #
        # Oct 11, 2002 Tom: one checkbox is in the order_info table,
        # but the rest are in the billing table. Go figure.
        # 
        $loop_instance = fixradiocheck("chips_billed",
                                       $b_hr->{chips_billed},
                                       "checkbox",
                                       $loop_instance);
        $loop_instance = fixradiocheck("rna_isolation_billed",
                                       $b_hr->{rna_isolation_billed},
                                       "checkbox",
                                       $loop_instance);
        $loop_instance = fixradiocheck("analysis_billed",
				       $b_hr->{analysis_billed},
                                       "checkbox",
                                       $loop_instance);
        $reclist .= $loop_instance;
    }
    return $reclist;
}

