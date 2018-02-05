use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my %ch = $q->Vars();

my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "curtools/view_reports2.cgi");

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
  warn "non administrator $us_fk runs $0";
  print "Location: $url\n\n";
  exit();
}
$ch{htmltitle} = "Billing Log";
$ch{help} = set_help_url($dbh, "array_center_staff_view_reports", "billing_log");
$ch{htmldescription} = "";
$ch{formaction} = "view_reports2.cgi";

my $allhtml = make_report($dbh, $us_fk, \%ch,
  \&define_billing_report_columns, \&get_billing_report_data);

print $q->header . "$allhtml\n" . $q->end_html;

$dbh->disconnect;

sub define_billing_report_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = 
    (
      {
        "display_name" => "Order #",
        "column_type" => "string",
        "name" => "order_num",
      },
      {
        "display_name" => "PI First",
        "column_type" => "string",
        "name" => "pi_first",
      },
      {
        "display_name" => "PI Last",
        "column_type" => "string",
        "name" => "pi_last",
      },
      {
        "display_name" => "PATEO",
        "column_type" => "string",
        "name" => "pateo",
      },
      {
        "display_name" => "Dept",
        "column_type" => "string",
        "name" => "dept",
      },
      {
        "display_name" => "Special Center",
        "column_type" => "string",
        "name" => "special_center",
      },
      {
        "display_name" => "Isolations",
        "column_type" => "integer",
        "name" => "isolations",
      },
      {
        "display_name" => "Preps",
        "column_type" => "integer",
        "name" => "preps",
      },
      {
        "display_name" => "Chips",
        "column_type" => "integer",
        "name" => "chips",
      },
      {
        "display_name" => "Total",
        "column_type" => "money",
        "name" => "total",
      },
      {
        "display_name" => "Isolation Bill Data",
        "column_type" => "date",
        "name" => "isolation_bill_date",
      },
      {
        "display_name" => "Preps Bill Data",
        "column_type" => "date",
        "name" => "preps_bill_date",
      },
      {
        "display_name" => "Chips Bill Data",
        "column_type" => "date",
        "name" => "chips_bill_date",
      },
    );
    return(\@report_columns);
  }

  sub get_billing_report_data
  {
    my ($dbh, $us_fk, $columns_ref, $chref) = @_;
    my @data = ();

    my $sql = "select oi_pk, order_number, billing_code, contact_fname, contact_lname, department, isolations, isolation_bill_date, preps_bill_date, chips_bill_date from order_info, usersec, groupref, contact, billing where oi_fk=oi_pk and oi_pk = ref_fk and us_fk = us_pk and con_fk = con_pk";

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref())
    {
       my %temp = ();

       # Order Number
       $temp{'order_num'} =  "<a href=\"show1_curator.cgi?oi_pk=" .
         "$ref->{'oi_pk'}\">$ref->{'order_number'}</a>";

       # PI Last
       $temp{'pi_first'}=$ref->{'contact_fname'};

       # PI First
       $temp{'pi_last'}=$ref->{'contact_lname'};

       # PATEO
       $temp{'pateo'}=$ref->{'billing_code'};

       # Department
       $temp{'dept'}=$ref->{'department'};

       # Organization Name
       my $sql2 = "select org_name, chip_discount from order_info,". 
        " organization where $ref->{oi_pk} = oi_pk and org_fk = org_pk";

       my $sth2 = $dbh->prepare($sql2);
       $sth2->execute();
       my $org_name = "";
       my $chip_discount = 0;
       ($org_name, $chip_discount) = $sth2->fetchrow_array();
       $temp{'special_center'} = $org_name;

       # Isolations
       my ($isolations, $num_samples) = calcIsolations($dbh, $us_fk, $ref->{oi_pk});

       $isolations = $ref->{isolations} if (defined $ref->{isolations});
       $temp{'isolations'} = $isolations;

       # Preps
       $temp{'preps'} = $num_samples;

       # Chips
       my %chip_count;
       my %chip_cost;
       my $total_num_chips = 0;
       
       my $sql2 = "select name, chip_cost from arraylayout, sample," .
        " order_info, arraymeasurement where al_fk = al_pk and oi_fk = " .
        "oi_pk and oi_pk = $ref->{oi_pk} and smp_fk = smp_pk";
       my $sth2 = $dbh->prepare($sql2);
       $sth2->execute();
       while (my ($name, $cost) =  $sth2->fetchrow_array())
       {
         $total_num_chips++;
         $chip_count{$name}++;
         $chip_cost{$name} = $cost; 
       }
       $temp{'chips'} = $total_num_chips;

       # Total
       my $isolation_cost =  38 * $isolations;
       my $prep_cost = 325 * $num_samples;
       my $total = ($isolation_cost + $prep_cost);
       my $mult = 1 - ($chip_discount/100);
       $total *= $mult;

       my $price = 0;
       while (my ($name, $count) = each(%chip_count))
       {
	  $price += $chip_cost{$name} * $count;
       }
       $total += $price;

       # Alyson wants total formatted with $ and ,
       # not sure if we'll have decimals, but try to handle just in case
       my $decimal = "";
       if ($total =~ /(.*)\.(.*)/)
       {
         $decimal = $2;
         $total = $1;
       }
       my @total = split(//, $total);
       my $totalStr = "";
       my $i;
       for ($i = $#total; $i > -1; $i-=3)
       {
         $totalStr = "," . $totalStr;
         $totalStr = $total[$i] . $totalStr if ($i >= 0); 
         $totalStr = $total[$i-1] . $totalStr if (($i - 1) >= 0); 
         $totalStr = $total[$i-2] . $totalStr if (($i -2 ) >= 0);
       }
       chop($totalStr); # remove last comma
       $totalStr = "\$" . "$totalStr";
       $decimal .= "0" if ($decimal =~ /^\d$/);
       $totalStr .= ".$decimal" if ($decimal ne "");
       $temp{'total'}= $totalStr;

       # Isolation Bill Date
       $temp{'isolation_bill_date'}=transform_date($ref->{isolation_bill_date});

       # Preps Bill Date
       $temp{'preps_bill_date'}=transform_date($ref->{preps_bill_date});

       # Chips Bill Date
       $temp{'chips_bill_date'}=transform_date($ref->{chips_bill_date});

       push @data, \%temp;
    }
    return(@data);
  }
