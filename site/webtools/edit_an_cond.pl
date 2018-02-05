use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{

  my $debug;
  my $q = new CGI;
    
  my $dbh = new_connection(); # session_lib
  my $us_fk = get_us_fk($dbh, "webtools/edit_an_cond.cgi");
  my %ch = $q->Vars();
  my $login = doq($dbh, "get_login", $us_fk);

  ## Check if no an_cond_pk from post; get from session if not in post
  if ($ch{an_cond_pk} eq ""){

    my $value_array_ref = get_session_val($dbh, $us_fk, "edit_an_cond", "an_cond_pk");
    my @value_array = @$value_array_ref;
    $ch{an_cond_pk} = $value_array[1];

  }

  if ($ch{submit} eq "Add Hybridizations")
  {
    post_redirect($dbh, $us_fk, "add_am_to_an_cond", "an_cond_pk",
        $ch{an_cond_pk}, "add_am_to_an_cond.cgi");
  }

  ## Check if updating an_cond; update and delete as necessary
  if ($ch{submit} eq "Update"){

    update_an_cond($ch{an_cond_pk}, $ch{an_cond_name}, $ch{an_cond_desc}, $dbh);
    my @am_pk_array = split(/\0/, $ch{am_pk});
    delete_an_cond_am_links(\@am_pk_array, $ch{an_cond_pk}, $dbh);

  }

  my $all_html = readfile("edit_an_cond.html", "/site/webtools/header.html", "/site/webtools/footer.html");
  $all_html =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
  my $loop_template = $1;
  my $loop_instance;

  ## Get an_cond information for GUI
  ($ch{an_cond_name}, $ch{an_cond_desc}, $ch{an_cond_created}) = get_an_cond($dbh, $ch{an_cond_pk});
  $ch{chiptype} = getq_an_cond_chiptype($dbh, $us_fk, $ch{an_cond_pk});

  ## Gets all readable ams in an_cond
  $all_html = get_ams_in_an_cond(\%ch, $dbh, $us_fk, $all_html);

  $ch{htmltitle} = "Edit Analysis Condition";
  $ch{help} = set_help_url($dbh, "edit_existing_analysis_conditions");
  $ch{htmldescription} = "You may use this page to change the name or
    description of a condition and modify the hybridizations in the
    condition.  To delete hybridizations, check the appropriate delete 
    checkbox and click on 'Update'.  To add hybridizations, click 
    on 'Add Hybridizations'.";

  my %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
                                                                                                               
  $all_html =~ s/{(.*?)}/$ch{$1}/g; # substitute fields outside the loop, especially am_pk
  print "Content-type: text/html\n\n$all_html";

  $dbh->commit;
  $dbh->disconnect;
  exit(0);

}


## get_ams_in_an_cond
## 8-10-04  Steve Tropello
## Display all readable ams in an_cond to us_fk
## Return $all_html
sub get_ams_in_an_cond
{

  my ($chref, $dbh, $us_fk, $all_html) = @_;
  my %ch = %$chref;

  $all_html =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
  my $loop_template = $1;
  my $loop_instance;

  ## Display only readable ams
  my ($fclause, $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk);

  ## Set default order values
  my $field = "am_pk";
  my $order = "desc";

  ## Check if order specified
  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }

  my $sql = "select am_pk, hybridization_name, login, gs_name from arraymeasurement, an_cond_am_link, groupsec, usersec, $fclause where $wclause and an_cond_am_link.an_cond_fk=$ch{an_cond_pk} and an_cond_am_link.am_fk=arraymeasurement.am_pk and groupref.gs_fk=groupsec.gs_pk and groupsec.gs_owner=usersec.us_pk order by $field $order";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";

  while($chref = $sth->fetchrow_hashref()){

    $loop_instance = $loop_template;
    $loop_instance =~ s/{(.*?)}/$chref->{$1}/g;
    $all_html =~ s/<loop_here>/$loop_instance\n<loop_here>/;

  }

  $all_html =~ s/<loop_here>//; # remove lingering template loop tag

  return $all_html;

} #get_ams_in_an_cond

