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
}
if (! is_curator($dbh, $us_fk))
{
  GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
}
else
{
  if ($ch{submit} eq "Assign Order To Study")
  {
    if (! $ch{oi_pk})
    {
      GEOSS::Session->set_return_message("errmessage",
          "FIELD_MANDATORY", "Select Order");
    }
    elsif (! $ch{sty_pk})
    {
      GEOSS::Session->set_return_message("errmessage",
          "FIELD_MANDATORY", "Select Study");
    }
    else
    {
      my $order = GEOSS::Arraycenter::Order->new(pk => $ch{oi_pk});
      my $study = GEOSS::Experiment::Study->new(pk => $ch{sty_pk});

      my $order_status = $order->status;
      my $study_status = $study->status;
      if (($order_status eq "LOADED") ||
          ($order_status eq "LOADING IN PROGRESS"))
      {
        GEOSS::Session->set_return_message("errmessage", "ERROR_STATUS", 
            "Order $order ($order_status)", "INCOMPLETE, COMPLETE,
            SUBMITTED, or APPROVED");
      }
      if ($study_status ne "COMPLETE")
      {
        GEOSS::Session->set_return_message("errmessage", "ERROR_STATUS", 
            "Study " . $study->name . " ($study_status)", "COMPLETE");
      }
      eval { $study->assign_order($order) };
      if ($@)
      {
        $dbh->rollback();
        $@ =~ /(ERROR.*)/;
        GEOSS::Session->set_return_message("errmessage", 
            "ERROR_ASSIGN_ORDER", "order $order", "study " . $study->name .
            " $1");
      }
      else
      {
        $dbh->commit();
        GEOSS::Session->set_return_message("errmessage", 
            "SUCCESS_ASSIGN", "order $order", "study " . $study->name);
      }
      my $url = index_url($dbh, "curtools");
      print "Location: $url\n\n";
      exit(0);
    }
  }

  my ($allhtml, $loop_template, undef, $loop_template2) = readtemplate(
      "link_order_number.html", "/site/webtools/header.html", 
      "/site/webtools/footer.html"); 

  foreach my $study (reverse (GEOSS::Experiment::Study->new_list()))
  {
    my %rec;
    $rec{sty_pk} = $study->pk;
    $rec{name} = $study->name;
    $rec{owner} = $study->owner->name;
    $rec{group} = $study->group->name;
    $rec{status} = $study->status;
    next if ($rec{status} ne "COMPLETE");
    foreach my $s ($study->samples)
    {
      if (! $s->order)
      {
        $rec{number_of_samples}++;
        my @arr = $s->arraymeasurements;
        $rec{number_of_chips} += @arr;
      }
    }; 
    next if (! $rec{number_of_samples});
    my $loop_instance = $loop_template2;
    $loop_instance =~ s/{(.*?)}/$rec{$1}/g;
    $allhtml =~ s/<loop_here2>/$loop_instance<loop_here2>/s
  }
  foreach my $order (reverse (GEOSS::Arraycenter::Order->new_list()))
  {
    my %rec;
    $rec{oi_pk} = $order->pk;
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

  $ch{htmltitle} = "Link a Historical Order Number to an Existing Array
    Study";
  $ch{help} = set_help_url($dbh,
      "assign_a_historical_order_to_an_existing_study");
  $ch{htmldescription} = "If you previously created an order using 'Create a
    New Array Order', it can be assigned to an existing study.  Assigning
    an order number will associate all samples in that study that are not
    currently associate with an order to the specified historical order.";

  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  $allhtml = fixradiocheck("oi_pk", $ch{oi_pk}, "radio", $allhtml);
  print "Content-type: text/html\n\n";
  print "$allhtml\n";
} 
exit(0);
