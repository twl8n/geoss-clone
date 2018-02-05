use strict;
use CGI;
use GEOSS::Util;
use GEOSS::Database;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
my $us_fk = get_us_fk($dbh, "curtools/index.cgi");

if (! get_config_entry($dbh, "array_center"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_ARRAY_CENTER_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}

if (! (is_curator($dbh, $us_fk)))
{
  GEOSS::Session->set_return_message("errmessage", "INVALID_PERMS");
  my $url = index_url($dbh, "webtools"); # see session_lib
    write_log("error: non administrator runs $0");
  print "Location: $url\n\n";
  exit();
}

my $oi_pk = $q->param("oi_pk");
my $state = $q->param("state");
my $order_number = $q->param("order_number");
write_order_billing($dbh, $us_fk, $q);

my $url;
if ($state == 1)
{
  $url = index_url($dbh); # see session_lib
    $url .="/show1_curator.cgi";
  $url .= "?oi_pk=$oi_pk";
}
else
{
  $url = index_url($dbh); # see session_lib
    $url .= "/choose_order_curator.cgi#__$oi_pk";
}
print "Location: $url\n\n";
exit();


sub write_order_billing
{
  (my $dbh, my $us_fk, my $q) = @_;
  my $sql;
  my $success = 1;
  my %ch = $q->Vars();

  my @bools = ("chips_ordered", "signed_analysis_report", 
      "meeting_scheduled", "chips_billed", "have_chips", 
      "rna_isolation_billed", "analysis_billed", "locked");

  foreach my $var (@bools)
  {
    if (! exists($ch{$var}))
    {
      $ch{$var} = 0; # undef or null string is bad for SQL
    }
  }

  $sql = "update order_info set locked='$ch{locked}', chips_ordered=
    '$ch{chips_ordered}', have_chips='$ch{have_chips}', 
    signed_analysis_report='$ch{signed_analysis_report}',
    meeting_scheduled='$ch{meeting_scheduled}',";
  if ( (defined($ch{isolations})) and ($ch{isolations} ne ""))
  {
    $ch{isolations} = $dbh->quote($ch{isolations});
    $sql .= "isolations=$ch{isolations},";
  }
  if ($ch{date_samples_received} eq "")
  {
    $sql .= "date_samples_received=NULL,";
  } else 
  {
    $ch{date_samples_received} = $dbh->quote($ch{date_samples_received});
    $sql .= "date_samples_received=$ch{date_samples_received},";
  }
  if ($ch{date_report_completed} eq "")
  {
    $sql .= "date_report_completed=NULL,";
  } else 
  {
    $ch{date_report_completed} = $dbh->quote($ch{date_report_completed});
    $sql .= "date_report_completed=$ch{date_report_completed},";
  }
  chop($sql); # remove trialing comma
    $sql .= " where oi_pk=$ch{oi_pk}";
  eval { $dbh->do($sql); }; 
  if ($@)
  {
    $success = GEOSS::Util->report_postgres_err($@);
    $dbh->rollback();
  }
  else
  {  
    $sql = "update billing set chips_billed='$ch{chips_billed}',
      rna_isolation_billed='$ch{rna_isolation_billed}',
      analysis_billed='$ch{analysis_billed}',
      billing_code='$ch{billing_code}',";
    if ($ch{chips_bill_date} eq "")
    {
      $sql .= "chips_bill_date=NULL,";
    } else 
    {
      $ch{chips_bill_date} = $dbh->quote($ch{chips_bill_date});
      $sql .= "chips_bill_date=$ch{chips_bill_date},";
    }
    if ($ch{isolation_bill_date} eq "")
    {
      $sql .= "isolation_bill_date=NULL,";
    } else 
    {
      $ch{isolation_bill_date} = $dbh->quote($ch{isolation_bill_date});
      $sql .= "isolation_bill_date=$ch{isolation_bill_date},";
    }
    if ($ch{preps_bill_date} eq "")
    {
      $sql .= "preps_bill_date=NULL,";
    } else 
    {
      $ch{preps_bill_date} = $dbh->quote($ch{preps_bill_date});
      $sql .= "preps_bill_date=$ch{preps_bill_date},";
    }
    chop($sql); # remove trialing comma
      $sql .= " where oi_fk=$ch{oi_pk}";
    eval { $dbh->do($sql); };
    if ($@)
    {
      $success = GEOSS::Util->report_postgres_err($@);
      $dbh->rollback();
    }
    else
    {
      if ($ch{locked})
      {
        lock_order($dbh, $ch{oi_pk}, 0); # zero to lock (any value except one locks)
      }
      else
      {
        lock_order($dbh, $ch{oi_pk}, 1); # one to unlock
      }
    }
  }
  $dbh->commit if ($success);
}

