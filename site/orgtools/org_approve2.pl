use strict;
use CGI;
use GEOSS::Database;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;

my $us_fk = get_us_fk($dbh, "orgtools/index.cgi");
if (! get_config_entry($dbh, "array_center"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_ARRAY_CENTER_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}

if ((!is_administrator($dbh, $us_fk)) && (! is_org_curator($dbh, $us_fk)))
{
  set_session_val($dbh, $us_fk, "message", "errmessage",
      get_message("INVALID_PERMS"));
  write_log("$us_fk runs org_approve2.cgi");
  my $url = index_url($dbh, "webtools"); # see session_lib
    print "Location: $url\n\n";
  $dbh->disconnect;
  exit();
};

my $oi_pk = $q->param("oi_pk");
my $approve_str = $q->param("submit");
$approve_str =~ /Approve Order (.*)/;
my $order_number = $1;
my $app_comments = $q->param("approval_comments_$oi_pk");
approve_order($dbh, $us_fk, $oi_pk, $app_comments);

$dbh->commit;

my $url = index_url($dbh); # see session_lib
print "Location: $url\n\n";
exit();

sub approve_order
{
  my ($dbh, $us_fk, $oi_pk, $app_comments) = @_;

  my $email_file;
  my $approve = 1;

# we can only approve an order if the order is in a "SUBMITTED" state
# and if current user is an org_curator

  my $sql = "select * from order_info where oi_pk=$oi_pk";
  my $sth = $dbh->prepare($sql) || die "prepare:$sql\n$DBI::errstr\n";
  $sth->execute() || die "$sql\n$DBI::errstr\n";
  my $o_hr;
  $o_hr = $sth->fetchrow_hashref();
  $sth->finish();

  if (! is_org_curator($dbh, $us_fk, $o_hr->{org_pk})) 
  {
    set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("INVALID_PERMS"));
    $approve = 0;
    warn "Not org_curator";
  }

  if (get_order_status($dbh, $us_fk, $oi_pk) ne "SUBMITTED") 
  {
    my $gos = get_order_status($dbh, $us_fk, $oi_pk);
    set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("INCORRECT_ORDER_STATUS", "SUBMITTED", "approved"));
    $approve = 0;
  }

  my $order_number = $o_hr->{order_number};
  my $org_fk = $o_hr->{org_pk};
  if ($approve == 1)
  {
    $email_file = "../webtools/order_submit_curator_email.txt";
    my $curator_email = get_config_entry($dbh, "curator_email");
    my $assign_url = index_url($dbh, "curtools") . 
          "/assign_order_number.cgi?oi_pk=$oi_pk";
    my $info = 
    {
      "email" => $curator_email,
      "oi_pk" => $oi_pk,
      "order_assign_url" => $assign_url,
    };
    email_generic($dbh, $email_file, $info);
    doq_approve_order($oi_pk, $org_fk, $app_comments);
    set_session_val($dbh, $us_fk, "message", "goodmessage", 
         get_message("SUCCESS_ORDER_APPROVED", $order_number));
  }
  return $approve;  
}
