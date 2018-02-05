use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my %ch = $q->Vars(); 

my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "webtools/order_viewer.cgi");

$ch{htmltitle} = "View all array orders";
$ch{help} = set_help_url($dbh, "view_all_array_orders");
$ch{htmldescription} = "To sort data based on a column of data, click on the
column header.  To search data, click on the checkbox for the column(s) you
wish to search and specify search parameters.";
$ch{formaction} = "order_viewer.cgi";
my $allhtml = make_report($dbh, $us_fk, \%ch, \&define_order_report_columns,
    \&get_order_report_data);

print $q->header . "$allhtml\n" . $q->end_html;
$dbh->disconnect;

    
sub define_order_report_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = (
     {
       "name" => "search",
       "button" => qq!<input type="submit" name="search" value="Search">!,
     }, 
     {
       "display_name" => "Order Number",
       "column_type" => "linked_string",
       "name" => "order_number",
       "searchable" => 1, 
       "search_input" => qq!<input type="text" size=12
           name="val_order_number" value="{val_order_number}">!,
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Status",
       "column_type" => "string",
       "name" => "order_status",
       "searchable" => 1,
       "search_input" => select_order_status($dbh, "val_order_status"),
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Samples",
       "column_type" => "integer",
       "name" => "number_of_samples",
       "searchable" => 1,
       "search_operator" => qq!>=!,
       "search_input" => qq!<input type="text" name="val_number_of_samples"!  . 
         qq! size=4 value="{val_number_of_samples}">!,
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
             {
               "name" => "op_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Chips",
       "column_type" => "integer",
       "name" => "number_of_chips",
       "searchable" => 1,
       "search_operator" => qq!>=!,
       "search_input" => qq!<input type="text" name="val_number_of_chips"!  . 
         qq! size=4 value="{val_number_of_chips}">!,
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
             {
               "name" => "op_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Chip Type",
       "column_type" => "string",
       "name" => "chip_type",
       "searchable" => 1,
       "search_input" => qq!<input type="text" size=12 
           name="val_chip_type" value="{val_chip_type}">!,
       "search_input" => build_al_select($dbh, "val_chip_type"), 
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Study Name",
       "column_type" => "linked_string",
       "name" => "study_name",
       "searchable" => 1,
       "search_input" => qq!<input type="text" size=12 
           name="val_study_name" value="{val_study_name}">!,
       "fixvalues" =>
           [ 
             {
               "name" => "val_",
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Organization",
       "column_type" => "string",
       "name" => "org_name",
       "searchable" => 1,
       "search_input" => qq!<input type="text" size=12 
           name="val_org_name" value="{val_org_name}">!,
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Billing Code",
       "column_type" => "linked_string",
       "name" => "billing_code",
       "searchable" => 1,
       "search_input" => qq!<input type="text" size=12 
           name="val_billing_code" value="{val_billing_code}">!,
       "fixvalues" =>
           [ 
             {
               "name" => "val_",
               "type" => "select",
             },
           ],
     },
  );
  return (\@report_columns);
}

sub get_order_report_data
{ 
  my ($dbh, $us_fk, $columns_ref, $chref)= @_;

  my @data;
  my ($fclause, $wclause) =
    read_where_clause("order_info","oi_pk",$us_fk);
  
  my $sql = "select order_number,oi_pk from order_info,$fclause " .
          "where $wclause order by order_number desc";

  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref())
  {
    my %temp = ();
    my $all_smp = get_all_sample_info($dbh, $us_fk, $ref->{oi_pk});
    $temp{number_of_samples} = 0;
    $temp{number_of_chips} = 0;
    $ref->{study_name} = "";
    $ref->{chip_type} = "";

    my %study_name = ();
    my %chip_name = ();
    foreach my $smp_ref (@$all_smp)
    {
      $temp{number_of_samples}++;
      $temp{number_of_chips} += $smp_ref->{num_am};
      # should all have the same study name now, but legacy installs
      # mae have orders with samples from more than one study
      my $sth2=getq("select_study_name_pk_by_smp_pk", $dbh);
      $sth2->execute($smp_ref->{smp_pk});
      ($temp{'study_name'}, $temp{'sty_pk'}) = $sth2->fetchrow_array();

      my $chip=getq_arraylayout_name_by_al_pk($dbh, $us_fk,
          $smp_ref->{al_fk}) if ($smp_ref->{al_fk});
      $chip_name{$chip} = 1;
    }

    #Search
    $temp{'search'}= "&nbsp";
    
    # Order Number
    $temp{'order_number'} = (! $ref->{'order_number'}) ? "UNASSIGNED" :
       $ref->{order_number};
    next if (($chref->{'use_order_number'}) &&
             ($ref->{order_number} !~ /$chref->{'val_order_number'}/i));

    # Status 
    $temp{'order_status'} = get_order_status($dbh, $us_fk, $ref->{oi_pk});
    next if (($chref->{'use_order_status'}) && 
             ($temp{'order_status'} ne $chref->{'val_order_status'}));

    # Samples $temp{number_of_samples}
    next if (($chref->{'use_number_of_samples'}) && 
             ($temp{'number_of_samples'} <= $chref->{'val_number_of_samples'}));
  
    # Chips $temp{number_of_chips}
    next if (($chref->{'use_number_of_chips'}) && 
             ($temp{'number_of_chips'} <= $chref->{'val_number_of_chips'}));

    #Chip Type
    my @names =  keys(%chip_name);
    foreach (@names)
    {
      $temp{chip_type} .= "$_ ";
    }
    next if (($chref->{'use_order_number'}) &&
             ($ref->{order_number} !~ /$chref->{'val_order_number'}/i));
    next if (($chref->{'use_chip_type'}) && 
             ($temp{'chip_type'} !~ /$chref->{'val_chip_type'}/i));

    # Study Name
    $temp{'study_name'} =  "<a href=" .
      "\"study_viewer_full.cgi?sty_pk=$temp{sty_pk}\">" .
      "$temp{'study_name'}</a>";

    next if (($chref->{'use_study_name'}) && 
             ($temp{'study_name'} !~ /$chref->{'val_study_name'}/));

    # Organization
    $temp{org_name} = get_order_org_name($dbh, $us_fk, $ref->{oi_pk});
    next if (($chref->{'use_organization'}) && 
             ($temp{'org_name'} !~ /$chref->{'val_org_name'}/));
    
    # Billing Code
    my $sth2 = getq("get_billing_code", $dbh);
    $sth2->execute($ref->{oi_pk});
    $temp{billing_code} = $sth2->fetchrow_array();
    next if (($chref->{'use_billing_code'}) && 
             ($temp{'billing_code'} !~ /$chref->{'val_billing_code'}/));

    push @data, \%temp;
  }
  return(@data);
} 
