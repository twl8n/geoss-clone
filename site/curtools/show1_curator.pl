use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $q = new CGI;
  my %ch = $q->Vars();
    
  my $dbh = new_connection(); # session_lib
    
  my $us_fk = get_us_fk($dbh, "curtools/index.cgi");

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
    write_log("error: non array center staff runs $0");
    print "Location: $url\n\n";
    exit();
  }

  (my $allhtml, my $loop_template, my $tween, my $loop_template2) = 
    readtemplate("show1_curator.html", "/site/webtools/header.html", 
    "/site/webtools/footer.html"); 

  my $sth = getq("select_sample_by_oi_fk", $dbh);
  $sth->execute($ch{oi_pk});
  my $smps;
  my $x;

  while ($x = $sth->fetchrow_array())
  {
    $smps .= "$x,";
  }
  chop($smps);
  my $ret = update_hn($smps);
  if ($ret)
  {
    draw_index_curtools($dbh, $us_fk, $q);
  }
  else
  {
    my $recordlist = makelist($dbh, $us_fk, $loop_template,
      $loop_template2, $ch{oi_pk}, $ch{order_number});
    my $oi_form = oi_form($dbh); # see session_lib

    $allhtml =~ s/<loop_here>/$recordlist/sg;

    $ch{htmltitle} = "Single Array Order Display";
    $ch{help} = set_help_url($dbh, "get_one_array_order");
    $ch{htmldescription} = "";
    $ch{oi_form} = "$oi_form";
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n";
    print "$allhtml\n";
  }
  $dbh->disconnect;
  exit(0);
}


sub makelist
{
    my ($dbh, $us_fk, $loop_template, $loop_template2, $oi_pk, $order_number) 
	= @_;
    
    # sql statements
    my $sql =          "select * from order_info where oi_pk=$oi_pk";
    my $billing_sql =  "select * from billing where oi_fk=?";
    my $sample_sql =   "select timestamp, exp_condition.name as ec_name, abbrev_name, study.study_name, study.sty_pk from sample,exp_condition,study where study.sty_pk=exp_condition.sty_fk and exp_condition.ec_pk=sample.ec_fk and smp_pk=?";
    my $sc_sql =       "select count(smp_pk) from sample where oi_fk=?";
    my $am_sql =       "select hybridization_name,smp_pk,am_pk,al_fk,qc_fk from arraymeasurement,sample,order_info where oi_pk=? and order_info.oi_pk=sample.oi_fk and arraymeasurement.smp_fk=sample.smp_pk order by smp_pk,am_pk";
    my $al_sql =       "select arraylayout.name as al_name from arraylayout where al_pk=?";

    # sth vars
    my $sth =         $dbh->prepare($sql) || die "prepare: $sql\n$DBI::errstr\n" ;
    my $billing_sth = $dbh->prepare($billing_sql)  || die "prepare: $billing_sql\n$DBI::errstr\n";
    my $sample_sth =  $dbh->prepare($sample_sql) || die "prepare: $sample_sql\n$DBI::errstr\n";
    my $sc_sth =      $dbh->prepare($sc_sql)  || die "prepare: $sc_sql\n$DBI::errstr\n";
    my $owner_sth =   getq("order_owner_info", $dbh);
    my $am_sth =      $dbh->prepare($am_sql)  || die "prepare: $am_sql\n$DBI::errstr\n";
    my $al_sth =      $dbh->prepare($al_sql)  || die "prepare: $al_sql\n$DBI::errstr\n";

    my $reclist;
    #
    # Put all necessary data in to the $rec hash, and just loop through
    # the keys substituting into the HTML template.
    # This assumes that field names, and anything added to the $rec hash
    # is unique!
    # 
    $sth->execute() || die "$sql\n$DBI::errstr\n";
    my $o_hr; # order_info hash ref
    while($o_hr = $sth->fetchrow_hashref())
    {
        $sc_sth->execute($o_hr->{oi_pk}) || die "$sc_sql\n$DBI::errstr\n";
        ($o_hr->{number_of_samples}) = $sc_sth->fetchrow_array();

        $owner_sth->execute($o_hr->{oi_pk}) || die "Query order_owner_info execute failed. $DBI::errstr\n";
        ($o_hr->{login},$o_hr->{contact_fname},$o_hr->{contact_lname},$o_hr->{contact_phone},$o_hr->{us_pk}) = $owner_sth->fetchrow_array();
	($o_hr->{created_by_login}, $o_hr->{created_by_fname}, $o_hr->{created_by_lname}) = doq($dbh, "order_creator_info", $oi_pk);
         $o_hr->{org_name} = get_order_org_name($dbh, $us_fk, $oi_pk);

        my $loop_instance = $loop_template;
        my $reclist2; # list of loop_instance2 records
        $reclist2 = "";

        $billing_sth->execute($o_hr->{oi_pk}) || die "$billing_sql\n$DBI::errstr\n";
        my $b_hr = $billing_sth->fetchrow_hashref();

        $am_sth->execute($o_hr->{oi_pk}) || die "$am_sql\n$DBI::errstr\n";
        verify_order_completeness($dbh, $us_fk, $o_hr->{oi_pk}); 
        my $s_hr; # Messy. Used for results from several queries.
        my $num_loaded = 0;
        my $am_count = 0;
        while($s_hr = $am_sth->fetchrow_hashref())
        {
            $am_count++;
            $s_hr->{al_name} = "None selected";
            if ($s_hr->{al_fk} > 0)
            {
                $al_sth->execute($s_hr->{al_fk}) || die "$al_sql\n$DBI::errstr\n";
                ($s_hr->{al_name}) = $al_sth->fetchrow_array();
            }
            $sample_sth->execute($s_hr->{smp_pk}) || die "$sample_sql\n$DBI::errstr\n";
            ($s_hr->{timestamp}, $s_hr->{ec_name}, $s_hr->{abbrev_name}, $s_hr->{study_name}, $s_hr->{sty_pk}) = $sample_sth->fetchrow_array();

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
		my $loaded;
    if ($s_hr->{qc_fk} > 0)
    { 
      $loaded = "<a href=\"view_qc_curator.cgi?state=1&qc_pk=$s_hr->{qc_fk}&order_number=$order_number\">$loaded_flag</a>\n";
    }
    else
    {
      $loaded = $loaded_flag;
    }
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
          $o_hr->{load_all} = qq#<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td><form name="form2" method="post" action="load_data1.cgi"><input type="submit" name="submit_all" value="Load All"><input type="hidden" name="state" value="1"><input type="hidden" name="oi_pk" value="$o_hr->{oi_pk}"></form></td></tr>#
        }


        $loop_instance =~ s/{(.*?)}/$o_hr->{$1}$b_hr->{$1}/g;
        $loop_instance =~ s/\<loop_here2\>/$reclist2/s; # no g, only one inner loop
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
