use strict;
use CGI;
require "$LIB_DIR/geoss_session_lib";

main:
{
  my $debug;
  my $sql;
  my $q = new CGI;
    
  my $dbh = new_connection(); 
  my $us_fk = get_us_fk($dbh, "webtools/view_orders.cgi");
    
  if (is_public($dbh, $us_fk))
  {
    set_return_message($dbh, $us_fk, "message","errmessage", "INVALID_PERMS");
    my $url = index_url($dbh, "webtools");
    print "Location: $url\n\n";
  }
  else
  {

    my ($allhtml, $loop_template) = readtemplate("view_orders.html", 
        "/site/webtools/header.html", "/site/webtools/footer.html"); 

    my ($fclause,$wclause) = read_where_clause("order_info", "oi_pk", 
        $us_fk );
    $sql = "select order_number,oi_pk from order_info,$fclause " .
      "where $wclause order by order_number desc";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $rec;
    while($rec = $sth->fetchrow_hashref())
    {
      my $all_smp = get_all_sample_info($dbh, $us_fk, $rec->{oi_pk});
      $rec->{number_of_samples} = 0;
      $rec->{number_of_chips} = 0;
      $rec->{study_name} = "";
      $rec->{chip_type} = "";
      my %study_name = ();
      my %chip_name = ();
      foreach my $smp_ref (@$all_smp)
      {
        $rec->{number_of_samples}++;
        $rec->{number_of_chips} += $smp_ref->{num_am};
        # should all have the same study name now, but legacy installs
        # mae have orders with samples from more than one study
        my $sth2=getq("select_study_name_by_smp_pk", $dbh);
        $sth2->execute($smp_ref->{smp_pk});
        my ($name) = $sth2->fetchrow_array();
        $study_name{$name} = 1;

        my $chip=getq_arraylayout_name_by_al_pk($dbh, $us_fk,
            $smp_ref->{al_fk}) if ($smp_ref->{al_fk});
        $chip_name{$chip} = 1;
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
    my %ch;
    $ch{htmltitle} = "All Array Orders";
    $ch{help} = set_help_url($dbh, "view_all_array_orders");
    $ch{htmldescription} = "Once submitted, array orders are locked.  If
      changes are necessary, you must contact array center staff.";
    $ch{debug} = $debug;

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n";
    print "$allhtml\n";
    
    }
    $dbh->disconnect;
    exit(0);
}

