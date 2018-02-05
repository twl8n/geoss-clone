use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $sty_pk = $q->param("sty_pk");
    my %ch = $q->Vars();

    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "curtools/show_study_curator.cgi");

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
        warn("non administrator user pk $us_fk runs $0");
      print "Location: $url\n\n";
      exit();
    }



    my $sql = "select us_fk from study, groupref where sty_pk=ref_fk and sty_pk = '$sty_pk'";
    my ($sty_us_fk) = $dbh->selectrow_array($sql) || die "Select failed: $sql\n$DBI::errstr\n";

    my $valid = 0;
    # get organizations the requested user is part of
    my $sth = getq("get_orgs_by_user", $dbh, $sty_us_fk);
    $sth->execute() || die "get_orgs_by_user $sty_us_fk $DBI::errstr\n";
    # foreach organization, check if the requestor is part of that org
    my $org_pk;
    while (($org_pk, undef) = $sth->fetchrow_array())
    {
      $valid = 1 if (is_org_curator($dbh, $us_fk, $org_pk));
    }
    if ((! (is_curator($dbh, $us_fk))) && (! $valid))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
                                                      
    }

    my $sql = "select * from study where sty_pk=$sty_pk";
    my $sth = $dbh->prepare($sql);
    $sth->execute() || die "$sql\n$DBI::errstr\n";

    # r_hr record hash reference
    my $r_hr = $sth->fetchrow_hashref();
    $sth->finish();

    draw_study($dbh, $us_fk, $q);

    $dbh->commit;
    $dbh->disconnect;

    exit(0);
}


sub draw_study
{
    (my $dbh, my $us_fk, my $q) = @_;
    my $sth;

    my %ch = $q->Vars();

    #


    $ch{exp_select1} = select_exp($dbh, $us_fk, "paste_ec_fk1");
    $ch{exp_select2} = select_exp($dbh, $us_fk, "paste_ec_fk2");

    my $sql = "select study_name,sty_comments,start_date from study where sty_pk=$ch{sty_pk}";
    (($ch{study_name}, $ch{sty_comments}, $ch{start_date}) = $dbh->selectrow_array($sql)) || die "$sql\n$DBI::errstr\n" ;

    # The record creation date of the study is study_date
    # The date work on the study started.
    $ch{start_date} = sql2date($ch{start_date});

    #
    # Sep 09, 2002 Tom: get all the readable exp_conditions. We'll check to see
    # which are readonly and not allow them to be changed.
    # Even if we make a mistake here, the writing code in edit_study2.cgi won't
    # write a readonly record.
    #
    $sql = "select * from exp_condition where sty_fk=$ch{sty_pk} order by ec_pk";
    $sth = $dbh->prepare($sql) || die "$sql\n$DBI::errstr\n";
    $sth->execute() || die "$sql\n$DBI::errstr\n";
    

    my $allhtml = readfile("show_study_curator.html", "/site/webtools/header.html", "/site/webtools/footer.html");
    $allhtml =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
    my $loop_template = $1;

    my $xx = 0;
    while(my $s_hr = $sth->fetchrow_hashref())
    {	
        my %species_name;
        my $loop_instance = $loop_template; 
        ($s_hr->{species_select}, %species_name) = species_select($dbh);
        $loop_instance =~ s/{species_select}/$s_hr->{species_select}/s;
        #
        # species select needs to be in the $loop_template before tag_to_value()
        #
        if (1 !=  is_writable($dbh, "exp_condition", "ec_pk", $s_hr->{ec_pk}, $us_fk))
        {
            $loop_instance = tag_to_value("input", "delete", $loop_instance);
            $loop_instance = tag_to_value("input", "name", $loop_instance);
            # $loop_instance = tag_to_value("input", "ec_pk", $loop_instance);
            $loop_instance = tag_to_value("input", "abbrev_name", $loop_instance);
            $loop_instance = tag_to_value("textarea", "notes", $loop_instance);
            $loop_instance = tag_to_value("select", "spc_fk", $loop_instance);
            $loop_instance = tag_to_value("select", "sample_type", $loop_instance);
            $loop_instance = tag_to_value("input", "cell_line", $loop_instance);
            $loop_instance = tag_to_value("input", "tissue_type", $loop_instance);
            $loop_instance = tag_to_value("input", "description", $loop_instance);
            # convert species from numeric to string for display
            $s_hr->{delete} = "";
            $s_hr->{spc_fk} = $species_name{$s_hr->{spc_fk}};
            $s_hr->{ec_pk} = "";
        }
        else
        {
            # write_log("writable ec_pk: $s_hr->{ec_pk}");
        }
        $loop_instance =~ s/{(.*?)}/$s_hr->{$1}/g;
        if ((exists($s_hr->{spc_fk})) && ($s_hr->{spc_fk} != 0))
        {
            $loop_instance = fixselect("spc_fk", $s_hr->{spc_fk}, $loop_instance);
        }
        else
        {
            # if the value is undefined or zero, default to human
            $loop_instance = fixselect("spc_fk", 50, $loop_instance);
        }
        $loop_instance = fixselect("sample_type", $s_hr->{sample_type}, $loop_instance);
        $loop_instance =~ s/name=\"(.*?)\"/name=\"$1_$xx\"/g;
        $xx++;
        $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
    }
    $sth->finish();

    my $sql_num = "select count(*) from exp_condition where sty_fk=$ch{sty_pk}";
    ($ch{number_of_conditions})  = $dbh->selectrow_array($sql_num);

    my $sql_sn = "select study_name from study where sty_pk<>$ch{sty_pk}";
    my $sth_sn = $dbh->prepare($sql_sn);
    $sth_sn->execute();
    my $fflag = 0;
    while( (my $study_name) = $sth_sn->fetchrow_array())
    {
        if ($fflag == 0)
        {
            $ch{sn_list} .= "$study_name";
            $fflag = 1;
        }      
        else
        {
            $ch{sn_list} .= ", $study_name";
        }
    }

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $allhtml =~ s/<loop_here>//;     # remove lingering template loop tag
    $allhtml =~ s/{(.*?)}/$ch{$1}/g; # substitute fields outside the loop, especially primary keys
    
    # curator version specific feature: remove any submit buttons.
    $allhtml =~ s/<input[^<>]*?submit[^<>]*?>//isg;

    print "Content-type: text/html\n\n$allhtml\n";
}

sub species_select
{
    my $dbh = $_[0];
    #
    # Old code gets all entries from the species table.
    # my $sql = "select spc_pk,primary_scientific_name from species order by primary_scientific_name";
    # New code only gets a select group.
    #
    my $sql = "select spc_pk,primary_scientific_name from species where spc_pk in (4,5,6,41,44,50,53,108) order by primary_scientific_name";

    my $sth = $dbh->prepare($sql);
    $sth->execute() || die "$sql\n$DBI::errstr\n";
    
    my %species_name;
    my $sample_select = "<select name=\"spc_fk\">\n";
    my $spc_pk;
    my $psn;
    while(($spc_pk, $psn) = $sth->fetchrow_array())
    {
        $sample_select .= "<option value=\"$spc_pk\">$psn</option>\n";
        $species_name{$spc_pk} = $psn;
    }
    $sample_select .= "</select>\n";
    return ($sample_select, %species_name);
}
