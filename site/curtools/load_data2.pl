use strict;
use GEOSS::Database;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $debug;
  my $q = new CGI;
  my %ch = $q->Vars();
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
    GEOSS::Session->set_return_message("errmessage", "INVALID_PERMS");
    my $url = index_url($dbh, "webtools"); # see session_lib
      write_log("error: non administrator runs $0");
    print "Location: $url\n\n";
    exit();
  }

  if ($ch{submit} =~ m/cancel/i)
  {
    my $url = index_url($dbh); # see session_lib
    if ($ch{state} == 0)
    {
      $url =~ s/(.*)\/.*/$1\/choose_order_curator.cgi/;
    }
    else
    {
      $url =~ s/(.*)\/.*/$1\/show1_curator.cgi?order_number=$ch{order_number}/;
    }
    $dbh->disconnect();
    print "Location: $url\n\n";
    exit(0);
  }

  my @hybs;
  my %file_txt;
  my %file_rpt;
  my %file_exp;
  my %hyb_name;

  my $key;
  foreach $key (keys(%ch))
  {
    if ($key =~ /am_pk_(.*)/)
    {
      push @hybs, $1;
    }
    if ($key =~ /file_txt_(.*)/)
    {
      $file_txt{$1}  = $ch{$key};
    }
    if ($key =~ /file_rpt_(.*)/)
    {
      $file_rpt{$1} = $ch{$key};
    }
    if ($key =~ /file_exp_(.*)/)
    {
      $file_exp{$1} = $ch{$key};
    }
    if ($key =~ /hyb_name_(.*)/)
    {
      $hyb_name{$1} = $ch{$key};
    }
  }

  (my $allhtml, my $loop_template, my $loop_tween, my $loop_template2) = 
    readtemplate("load_data2.html", "/site/webtools/header.html", 
        "/site/webtools/footer.html");

# need to do this before the disconnect
  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

  my $am_pk;
  foreach $am_pk (@hybs)
  {
    my $loop_instance = $loop_template;
    my $vals = {"am_pk", $am_pk, "hybridization_name", $hyb_name{$am_pk}};
    $loop_instance =~ s/{(.*?)}/$vals->{$1}/g;
    $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
  }

  my $sth = getq("owner_info", $dbh);
  $sth->execute($ch{oi_pk}) || die "execute owner_info\n$DBI::errstr\        n";
  ((my $owner_us_fk, my $owner_gs_fk, my $owner_login)=
   $sth->fetchrow_array()) || die "fetch owner_info\n $DBI::errstr\n";    
  $sth->finish();

#
# Commit and disconnect. We don't want the child process to inherit
# an open db connection. Instead the child needs to make its own
# db connection.
# 
  $dbh->commit();
  $dbh->disconnect();

  my $pid = fork();
  if ($pid != 0)
  {

# This is the parent
#
    $allhtml =~ s/<loop_here>//s;
    if ($ch{state} == 0)
    {
#
# State zero is the full order list. The action URL used by the form tag
# in load_data2.html is pretty simple in this case.
#
      $ch{action_url} = "choose_order_curator.cgi";
    }
    else
    {
# 
# The only other state is 1, and this is the single order case.
# Build a action URL for show1_curator.cgi.
#
      $ch{action_url} = "show1_curator.cgi";
    }
# order_number is a hidden field, and will be filled in from %ch if it was passed in.

    $ch{htmltitle} = "Load Hybridization";
    $ch{help} = set_help_url($dbh, "get_one_array_order");

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";
    exit(0);
  }
  else
  {
    $dbh = GEOSS::Database::new_connection();
#
# This is the child
# Child needs to have its own output streams.
#
    $GEOSS::Session::web_us_fk_output=0;
    my $out_path = "$USER_DATA_DIR/$owner_login/Data_Files/$ch{order_number}";
    open(STDOUT, '>>', "$out_path/load_$ch{order_number}.txt") || die "Can't redirect stdout $out_path/load_$ch{order_number}}.txt $!";
    open(STDERR, ">&STDOUT") || die "load_data2.cgi : Can't dup stdout $!";

# Track time to load
    my $startdate = `date +%s`;
    chomp($startdate);
    print "data load for $ch{order_number} starts running: $startdate\n";

    my $am_pk;
    my $success;
    foreach $am_pk (@hybs)
    {
      doq($dbh, "set_is_loaded", $am_pk);
    }
    $dbh->commit();
    foreach $am_pk (@hybs)
    {
      my $int_time = `date +%s`;
      chomp($int_time);
      print "Time: $int_time\n Start am_pk $am_pk rpt_file $file_rpt{$am_pk} txt $file_txt{$am_pk} exp $file_exp{$am_pk}";
      $success = load_brf_data($dbh, $us_fk, {"am_pk", $am_pk, 
          "rpt_file", $file_rpt{$am_pk},
          "txt_file", $file_txt{$am_pk},
          "exp_file", $file_exp{$am_pk}});
      notify_loaded($dbh, $us_fk, $am_pk);
    }
    my $endseconds = `date +%s`;
    chomp($endseconds);
    printf("Total time was %s seconds.\n", $endseconds - $startdate);


    $dbh->commit();
    $dbh->disconnect();
  }
}

sub notify_loaded
{
  my ($dbh, $us_fk, $am_pk) = @_;

# get the oi_pk associated with the am_pk
  my $oi_pk = getq_oi_fk_by_am_pk($dbh, $us_fk, $am_pk);
  my $order_number = getq_order_number_by_oi_pk($dbh, $us_fk, $oi_pk);
# if the order_status is finished, email notification to the owner and
# createdby user that the order load is finished
  my @recipients = getq_order_notify_emails_by_oi_pk($dbh, $us_fk, $oi_pk);
  warn "Recip @recipients\n";
  my $status = get_order_status($dbh, $us_fk, $oi_pk);
  warn "Status is $status\n";
  if ($status eq "LOADED")
  {
    my $email_file = "./order_loaded_email.txt";
    my @recipients = getq_order_notify_emails_by_oi_pk($dbh, $us_fk, $oi_pk);
    my $last_recip;
    my $url = index_url($dbh);
    $url =~ /(.*)\//;
    $url = $1;
    my $contact = get_config_entry($dbh, "admin_email"); 
    foreach (@recipients)
    {
      my $info = 
      {
        "email" => $_,
        "oi_pk" => $oi_pk,
        "order_number" => $order_number,
        "GEOSS_url" => $url,
        "contact" => $contact,
      };
      email_generic($dbh, $email_file, $info) 
        if (($info->{'email'} ne "") && ($last_recip ne $info->{'email'}));
      $last_recip = $info->{'email'};
    }
  }
}
