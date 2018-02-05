use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{

  my $debug;
  my $q = new CGI;
    
  my $dbh = new_connection(); # session_lib
  my $us_fk = get_us_fk($dbh, "webtools/edit_an_set.cgi");
  my %ch = $q->Vars();
  my $login = doq($dbh, "get_login", $us_fk);

  ## Check if no an_set_pk in post and get session an_set_pk if necessary
  if ($ch{an_set_pk} eq ""){

    my $value_array_ref = get_session_val($dbh, $us_fk, "edit_an_set", "an_set_pk");
    my @value_array = @$value_array_ref;
    $ch{an_set_pk} = $value_array[1];

  }

  check_redirect($dbh, $us_fk, \%ch);
  if ($ch{submit} eq "Add Conditions")
  {
    post_redirect($dbh, $us_fk, "add_an_cond_to_an_set", "an_set_pk",
        $ch{an_set_pk}, "add_an_cond_to_an_set.cgi");
  }

  ##  Check if update requested; update and delete as necessary
  if ($ch{submit} eq "Update"){

    update_an_set($ch{an_set_pk}, $ch{an_set_name}, $ch{an_set_desc}, $dbh);
    my @an_cond_pk_array = split(/\0/, $ch{an_cond_pk});
    delete_an_set_cond_links(\@an_cond_pk_array, $ch{an_set_pk}, $dbh);

  }

  if ($ch{submit} eq "Create Tree Using This Set"){
     draw_insert_tree($dbh, $us_fk, {
         "source" => "an_set",
         "an_set_pk" => $ch{an_set_pk}, 
         "source_html" => get_an_set_html($dbh, $us_fk, \%ch),
         });
     $dbh->disconnect();
     exit();
  }

  my $all_html = readfile("edit_an_set.html", "/site/webtools/header.html", "/site/webtools/footer.html");
  $all_html =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
  my $loop_template = $1;
  my $loop_instance;

  ## Get an_set values for GUI
  ($ch{an_set_name}, $ch{an_set_desc}, $ch{an_set_created}) = get_an_set($dbh, $ch{an_set_pk});
  $ch{chiptype} = getq_an_set_chiptype($dbh, $us_fk, $ch{an_set_pk});
  my $num_am_cond = get_number_an_conds_in_an_set($ch{an_set_pk}, $dbh);
  if ($num_am_cond > 1)
  {
    $ch{create_tree} = qq!<input type="submit" name="submit"! .
     qq! value="Create Tree Using This Set">!;
  }
  else
  {
    $ch{create_tree} = "&nbsp";
  }
  ## Get html list of an_conds in set
  $all_html = get_an_conds_in_an_set(\%ch, $dbh, $all_html, $us_fk);

  $ch{htmltitle} = "Edit Set of Conditions";
  $ch{help} = set_help_url($dbh, "edit_existing_set_of_conditions");
  $ch{htmldescription} = "You may use this page to change the name or
    description of a set and modify the conditions in the
    set.  To delete conditions, check the appropriate checkbox and click on
    'Update'.  To add conditions, click on 'Add Conditions'.  To modify a
    condition, click on the pencil graphic adjacent to the condition.";

  my %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
  $all_html =~ s/{(.*?)}/$ch{$1}/g; 
  print "Content-type: text/html\n\n$all_html";

  $dbh->commit;
  $dbh->disconnect;
  exit(0);

}


## get_an_conds_in_an_set
## 8-10-04  Steve Tropello
## Display all readable an_conds in specific an_set to us_fk
## Return $all_html
sub get_an_conds_in_an_set
{

  my ($chref, $dbh, $all_html, $us_fk) = @_;
  my %ch = %$chref;

  $all_html =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
  my $loop_template = $1;
  my $loop_instance;

  ## Display readable an_conds only
  my ($fclause, $wclause) = read_where_clause("an_cond", "an_cond_pk", $us_fk);

  ## Set default order variables
  my $field = "an_cond_pk";
  my $order = "desc";

  ## Check if order was specified
  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }

  my $sql = "select an_cond_pk, an_cond_name, an_cond_desc, an_cond_created, login, gs_name from an_cond, an_set_cond_link, groupsec, usersec, $fclause where $wclause and an_set_cond_link.an_set_fk=$ch{an_set_pk} and an_set_cond_link.an_cond_fk=an_cond.an_cond_pk and groupref.gs_fk=groupsec.gs_pk and groupsec.gs_owner=usersec.us_pk order by $field $order";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";

  while($chref = $sth->fetchrow_hashref()){

    #format date
    $chref->{an_cond_created} = sql2date($chref->{an_cond_created});

    #create short description
    $chref->{an_cond_desc} = substr($chref->{an_cond_desc}, 0, 40);
    $chref->{an_cond_desc} .= "..." if (length($chref->{an_cond_desc}) > 39);

    $chref->{number_of_hybridizations}  = get_number_ams_in_an_cond($chref->{an_cond_pk}, $dbh);

    ## Check if an_cond is writable; permit editing if writable
    if (is_writable($dbh, "an_cond", "an_cond_pk", $chref->{an_cond_pk}, $us_fk)){
  
     $chref->{edit} = "<input type=image border=0
       name=edit_an_cond_$chref->{an_cond_pk} value=$chref->{an_cond_pk}
     SRC=\"../graphics/pencil.gif\" width=25 height=25>\n";

    }
    else {

      $chref->{edit} = "---\n";

    }

    $loop_instance = $loop_template;
    $loop_instance =~ s/{(.*?)}/$chref->{$1}/g;
    $all_html =~ s/<loop_here>/$loop_instance\n<loop_here>/;
                                                                                                            
  }

  $all_html =~ s/<loop_here>//; # remove lingering template loop tag

  return $all_html;

} #get_an_conds_in_an_set

