use strict;
use CGI;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_insert_lib";

main:
{
  my $debug;
  my $sql;
  my $q = new CGI;
  my %ch = $q->Vars();
    
  my $dbh = new_connection(); 
  my $us_fk = get_us_fk($dbh, "webtools/view_orders.cgi");
    
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
    my $url = index_url($dbh, "webtools");
    write_log("error: non administrator runs $0");
    print "Location: $url\n\n";
  }
  else
  {
    if ($ch{submit} eq "Assign Order Number")
    {
      my $success = 1;
      if (! $ch{oi_pk})
      {
        set_return_message($dbh, $us_fk, "message","errmessage",
         "FIELD_MANDATORY", "Select Order");
        $success = 0;
      }
      else
      {
        my $curnum = getq_order_number_by_oi_pk($dbh, $us_fk, $ch{oi_pk});
        if ($curnum)
        {
          set_return_message($dbh, $us_fk, "message","errmessage",
           "ERROR_ASSIGN_ORDER_NUMBER", $curnum);
          $success=0;
        }
      }
      if ($success)
      {
        my $ord_num_format = get_config_entry($dbh, "ord_num_format");
        if (($ord_num_format eq "year_seq") ||
            ($ord_num_format eq "seq"))
        {
          $ch{order_number} = generate_order_number($dbh, $us_fk);
        }
        doq_update_order_number($dbh, $us_fk, $ch{oi_pk}, $ch{order_number});
        my $url = index_url($dbh, "curtools");
        print "Location: $url\n\n";
        $dbh->commit();
        $dbh->disconnect();
        exit();
      }
    }
    my ($allhtml, $loop_template) = readtemplate("assign_order_number.html", 
        "/site/webtools/header.html", "/site/webtools/footer.html"); 

    my ($fclause,$wclause) = read_where_clause("order_info", "oi_pk", 
        $us_fk );
    $sql = "select order_number,oi_pk from order_info,$fclause " .
      "where order_number is NULL and $wclause order by oi_pk desc";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $rec;
    while($rec = $sth->fetchrow_hashref())
    {
      (undef, $rec->{pi_name}, $rec->{pi_group}) = doq($dbh, "get_order_info", 
          $us_fk, $rec->{oi_pk});
      $rec->{owner_group} = "$rec->{pi_name}/$rec->{pi_group}";
      my $all_smp = get_all_sample_info($dbh, $us_fk, $rec->{oi_pk});
      $rec->{number_of_samples} = 0;
      $rec->{number_of_chips} = 0;
      $rec->{study_name} = "";
      $rec->{chip_type} = "";
      my %study_name = ();
      my %chip_name = ();
      foreach my $smp_ref (@$all_smp)
      {
        if ($smp_ref)
        {
          $rec->{number_of_samples}++;
          $rec->{number_of_chips} += $smp_ref->{num_am};
# should all have the same study name now, but legacy installs
# mae have orders with samples from more than one study
          my $sth2=getq("select_study_name_pk_by_smp_pk", $dbh);
          $sth2->execute($smp_ref->{smp_pk});
          my ($name, undef) = $sth2->fetchrow_array();
          $study_name{$name} = 1;

          my $chip=getq_arraylayout_name_by_al_pk($dbh, $us_fk,
              $smp_ref->{al_fk}) if ($smp_ref->{al_fk});
          $chip_name{$chip} = 1;
        }
      }
      my $sth2 = getq("get_billing_code", $dbh);
      $sth2->execute($rec->{oi_pk});
      $rec->{billing_code} = $sth2->fetchrow_array();

      my @names =  keys(%study_name);
      foreach (@names)
      {
        $rec->{study_name} .= "$_ ";
      }
      @names =  keys(%chip_name);
      foreach (@names)
      {
        $rec->{chip_type} .= "$_ ";
      }

      $rec->{order_status} = get_order_status($dbh, $us_fk, $rec->{oi_pk});
      $rec->{org_name} = get_order_org_name($dbh, $us_fk, $rec->{oi_pk});
      $rec->{order_number} = "Not yet assigned" if (! $rec->{order_number});
      my $loop_instance = $loop_template;
      $loop_instance =~ s/{(.*?)}/$rec->{$1}/g;
      $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s
    }
    $ch{assign_html} = generate_assign_html($dbh, $us_fk);

    $ch{htmltitle} = "Assign Array Order numbers.";
    $ch{help} = set_help_url($dbh, "assign_a_new_order_number");
    $ch{htmldescription} = "This page can be used to assign an order number
      to an order.";
    $ch{debug} = $debug;

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    $allhtml = fixradiocheck("oi_pk", $ch{oi_pk}, "radio", $allhtml);
    print "Content-type: text/html\n\n";
    print "$allhtml\n";
    } 
    $dbh->disconnect;
    exit(0);
}

sub generate_assign_html
{
  my ($dbh, $us_fk) = @_;

  my $ord_num_format = get_config_entry($dbh, "ord_num_format");
  my $assign_html = "";

  if ($ord_num_format eq "user_conf")
  {
    $assign_html .= '<b>Order Number:<\b>&nbsp;&nbsp;';
    $assign_html .=  '<input type="text" name="order_number"
      value="" size="6" maxlength="6">'; 
  }
  elsif (! (($ord_num_format eq "seq") || 
           ($ord_num_format eq "year_seq")) )
  {
    set_return_message($dbh, $us_fk, "message","errmessage",
      "ERROR_NO_ORD_NUM_FORMAT");
    $assign_html = "";
  }
  return ($assign_html);
}
