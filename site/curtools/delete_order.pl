use strict;
use CGI;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_insert_lib";
use GEOSS::Database;
use GEOSS::Session;

my $q = new CGI;
my %ch = $q->Vars();

my $us_fk = GEOSS::Session->user->pk;

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
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
}
else
{
  if ($ch{submit} eq "Delete Order")
  {
    my $rows;
    if (! $ch{oi_pk})
    {
      GEOSS::Session->set_return_message("errmessage",
          "FIELD_MANDATORY", "Select Order");
    }
    else
    {
      my $order = GEOSS::Arraycenter::Order->new(pk => $ch{oi_pk});
      eval { $rows = $order->delete };
      if (($@) || ($rows != 1))
      {
        $dbh->rollback();
        GEOSS::Session->set_return_message("errmessage", 
            "CANT_DELETE", "order" . $order);
      }
      else
      {
        $dbh->commit();
        GEOSS::Session->set_return_message("errmessage", 
            "SUCCESS_DELETE", "order", $order);
      }
      my $url = index_url($dbh, "curtools");
      print "Location: $url\n\n";
      $dbh->disconnect();
      exit();
    }
  }
  my ($allhtml, $loop_template) = readtemplate("delete_order.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html"); 

  foreach my $order (reverse (GEOSS::Arraycenter::Order->new_list()))
  {
    my %rec;
    $rec{pk} = $order->pk;
    $rec{name} = $order->name? $order->name : "Not yet assigned";
    $rec{owner} = $order->owner->name;
    $rec{group} = $order->group->name;
    $rec{status} = $order->status;
    next if (($rec{status} eq "LOADED") || 
        ($rec{status} eq "LOADING IN PROGRESS"));
    my @samples = $order->samples;
    $rec{number_of_samples} = @samples;
    my @arraymeasurements = map {
      $_->arraymeasurements;
    } @samples;
    $rec{number_of_chips} = @arraymeasurements;
    my $layout_str;
    my $loaded = 0;
    foreach my $am (@arraymeasurements)
    {
      my $am_status = $am->status;
      $loaded = 1 if (($am_status eq "LOADED") || 
          ($am_status eq "LOADING IN PROGRESS"));
      my $layout = $am->layout;
      if ($layout)
      {
        my $name = $layout->name;
        $layout_str .= "$name " if ($layout_str !~ /$name /); 
      }
    }; 
    next if $loaded;
    $rec{chip_type} = $layout_str;
    my $study = $order->study;
    $rec{study} = $study->name if $study;
    my $organization = $order->organization;
    $rec{organization} = $organization->name if $organization;
    $rec{billing_code} = $order->billing_code;


    my $loop_instance = $loop_template;
    $loop_instance =~ s/{(.*?)}/$rec{$1}/g;
    $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s
  }

  $ch{htmltitle} = "Delete an Array Order";
  $ch{help} = set_help_url($dbh, "delete_an_array_order");
  $ch{htmldescription} = "Only orders with no loaded data can be deleted.";

  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  $allhtml = fixradiocheck("oi_pk", $ch{oi_pk}, "radio", $allhtml);
  print "Content-type: text/html\n\n";
  print "$allhtml\n";
} 
$dbh->disconnect;
exit(0);
