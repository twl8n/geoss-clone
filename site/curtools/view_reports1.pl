use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my %ch = $q->Vars();

my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "curtools/view_reports1.cgi");

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

$ch{htmltitle} = "Order Log";
$ch{help} = set_help_url($dbh, "array_center_staff_view_reports", "order_log");
$ch{htmldescription} = "";
$ch{formaction} = "view_reports1.cgi";

my $allhtml = make_report($dbh, $us_fk, \%ch, \&define_order_report_columns,
    \&get_order_report_data);

print $q->header;
print "$allhtml\n";
print $q->end_html;

$dbh->disconnect;
    
sub define_order_report_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = (
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
        "display_name" => "Order Placed",
        "column_type" => "date",
        "name" => "order_placed",
      },
      {
        "display_name" => "Chips Scanned",
        "column_type" => "date",
        "name" => "chips_scanned",
      },
      {
        "display_name" => "Samples Received",
        "column_type" => "date",
        "name" => "samples_received",
      },
      {
        "display_name" => "Report Completed",
        "column_type" => "date",
        "name" => "report_completed",
      },
      {
        "display_name" => "# Samples",
        "column_type" => "integer",
        "name" => "num_samples",
      },
      {
        "display_name" => "# Chips",
        "column_type" => "integer",
        "name" => "num_chips",
      },
      {
        "display_name" => "Chip Type",
        "column_type" => "integer",
        "name" => "chip_type",
      },
      {
        "display_name" => "Have Chips",
        "column_type" => "integer",
        "name" => "have_chips",
      },
  );
  return(\@report_columns);
}

sub get_order_report_data
{
  my ($dbh, $us_fk, $columns_ref, $chref) = @_;
  my @data = ();

  my $sql = "select oi_pk, order_number, contact_fname, contact_lname, date_samples_received, date_last_revised, date_report_completed, have_chips from order_info, usersec, groupref, contact where oi_pk = ref_fk and us_fk = us_pk and con_fk = con_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref())
  {
       my %temp = ();
       # Order Number
       $temp{'order_num'} = "<a href=\"show1_curator.cgi?" .
         "oi_pk=$ref->{oi_pk}\">$ref->{order_number}</a>";

       # PI Last
       $temp{'pi_first'} = $ref->{contact_fname};

       # PI First
       $temp{'pi_last'}= $ref->{contact_lname};

       # Date Order Placed
       $temp{'order_placed'}=transform_date($ref->{date_last_revised});

       # Date Chips Scanned
       my ($date) = $dbh->selectrow_array("select max(date_loaded) from" .
          " arraymeasurement, sample where smp_fk = smp_pk and oi_fk " .
          " = $ref->{oi_pk}");
       $temp{'chips_scanned'}= transform_date($date);

       # Date Samples Received 
       $temp{'samples_received'}=transform_date($ref->{date_samples_received});
   
       # Date Report Completed
       $temp{'report_completed'}=transform_date($ref->{date_report_completed});

       # Number of Samples
       my $sql2 = "select count(*) from sample, order_info where " .
         "oi_fk = oi_pk and oi_pk = $ref->{oi_pk}";
       my $sth2 = $dbh->prepare($sql2);
       $sth2->execute();

       $temp{'num_samples'} = $sth2->fetchrow_array();

       # Number of Chips
       $sql2 = "select count(*) from sample, order_info, arraymeasurement" .
         " where oi_fk = oi_pk and smp_fk = smp_pk and oi_pk = $ref->{oi_pk}";
       $sth2 = $dbh->prepare($sql2);
       $sth2->execute();

       $temp{'num_chips'} =  $sth2->fetchrow_array();

       # Chip Type  
       # TODO - provide for the case where there are layouts of different types
       $sql2 =  "select name from arraylayout, sample, order_info, " .
         "arraymeasurement where al_fk = al_pk and oi_fk = oi_pk and " .
         " oi_pk = $ref->{oi_pk} and smp_fk = smp_pk";
       $sth2 = $dbh->prepare($sql2);
       $sth2->execute();
       my %chip_types;
       while (my ($name) = $sth2->fetchrow_array())
       {
         $chip_types{$name}++; 
       }
       my $chip_type_str = " ";
       while (my ($k, $v) = each(%chip_types))
       {
	       $chip_type_str .= " $k ($v)"; 
       }
       $temp{'chip_type'} = $chip_type_str;
 

       # Have Chips
       if ($ref->{have_chips} == 1)
       {
         $temp{'have_chips'} = "Yes";
       }
       else
       {
         $temp{'have_chips'} = "No";
       }

       push @data, \%temp;
    }
  return(@data);
}
