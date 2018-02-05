use strict;
use CGI;
use GEOSS::Database;
use GEOSS::Arraycenter::Order;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $debug;
    my $sql;
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "curtools/load_data1.cgi");

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

    my $order = GEOSS::Arraycenter::Order->new(pk => $ch{oi_pk});
    if (! $order->name)
    {
        GEOSS::Session->set_return_message("errmessage",
            "ERROR_LOAD_NO_ORDER_NUM");
        print "Location: " . index_url($dbh, "curtools") .
          "/show1_curator.cgi?oi_pk=$ch{oi_pk}\n\n"; 
        exit;
    }
    my $confref = get_all_config_entries($dbh);
    @ch{keys %$confref} = values %$confref; 
    $ch{geoss_dir} = $GEOSS_DIR; 
    $ch{version} = $VERSION;

    my @hybs_to_load;
    # make a list of all hybridizations to load
    if ($ch{submit_all}) 
    {
      my $sth = getq("am_sample_order_info", $dbh);
      $sth->execute($ch{oi_pk}) || die "execute am_sample_order_info\n $DBI::errstr\n";
      my $hr;
      while ($hr = $sth->fetchrow_hashref())
      {
        push @hybs_to_load, $hr->{am_pk};
      }
    }
    else
    {
      push @hybs_to_load, $ch{am_pk};
    }
    
    # get info and error checking for each hybridization
    my $am_pk;
    my %hybs_to_load_str;
    my %txt_files;
    my %rpt_files;
    my %exp_files;
    foreach $am_pk (@hybs_to_load)
    {
      $ch{am_pk} = $am_pk;
      my $success = "";
      ($ch{hybridization_name}, $ch{order_number}) = get_info($dbh, $am_pk);
      $hybs_to_load_str{$am_pk} = $ch{hybridization_name};
      
      # find all available files for this hybridization
      my $filesref; # hash that contains cel, dat, chp, dtt, cab, exp, rpt, txt
      ($filesref, $success) = get_file_hash($dbh, $us_fk, $ch{hybridization_name});
      # perform error checking and preparation
      my $new_filesref;
      ($success, $new_filesref)=prepare_load_brf($dbh, $us_fk, \%ch, $filesref) if ($success eq "");
      $txt_files{$am_pk} = $new_filesref->{txt}; 
      $exp_files{$am_pk} = $new_filesref->{exp}; 
      $rpt_files{$am_pk} = $new_filesref->{rpt}; 
   }

   (my $allhtml, my $loop_template, my $loop_tween, my $loop_template2) = readtemplate("load_data1.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    $ch{htmltitle} = "Load Hybridization";
    $ch{htmldescription} = "This verifies which data to load and provides diagnostic errors for the loading process.";

    if (is_value($dbh, $us_fk, "message", "errmessage"))
    {
        $allhtml =~ s/(<input[^<]*?name=\"submit\".*?>)/Error in data load. Error must be fixed before data load can be initiated./is;
    }

    foreach $am_pk (@hybs_to_load)
    {
      my $loop_instance = $loop_template;
      my $hr = {"am_pk", "$am_pk", "hybridization_name", $hybs_to_load_str{$am_pk}, "file_txt", $txt_files{$am_pk}, "file_exp", $exp_files{$am_pk}, "file_rpt", $rpt_files{$am_pk}};
      $loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
      $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
    }
    $allhtml =~ s/<loop_here>//;
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};


    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";
    $dbh->disconnect();
    exit(0);
}
