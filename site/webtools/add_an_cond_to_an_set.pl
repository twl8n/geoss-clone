use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";


my $SUBMIT_VALUE = "Add Conditions";

main:
{
    my $debug;
    my $q = new CGI;
    my $dbh = new_connection(); 
    my $us_fk = get_us_fk($dbh, "add_an_cond_to_an_set.cgi");
    my %ch = $q->Vars();
    my %criteria_hash = ();
    my $login = doq($dbh, "get_login", $us_fk);

  ## Check if no an_set_pk in post and get session an_set_pk if necessary
  if ($ch{an_set_pk} eq ""){

    my $value_array_ref = get_session_val($dbh, $us_fk, "add_an_cond_to_an_set", "an_set_pk");
    my @value_array = @$value_array_ref;
    $ch{an_set_pk} = $value_array[1];

  }

  check_redirect($dbh, $us_fk, \%ch);

  ## Function calls for when source == criteria file
  if ($ch{source} eq "criteria_file"){

    ## Check if criteria file was selected
    if ($ch{criteria_file_fk} ne ""){
                                                                                                                       
      my %criteria_hash = parse_criteria_file($dbh, $ch{criteria_file_fk});
                                                                                                                       
      ## On submit insert criteria field::condition into an_set; redirect to edit an_set
      if ($ch{submit} eq $SUBMIT_VALUE){

        insert_criteria_an_conds_into_an_set($ch{an_set_pk}, \%criteria_hash, $dbh);
        post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", $ch{an_set_pk}, "edit_an_set.cgi");

      }


    }
  
    ## Default print criteria file and source html
    $ch{criteria_file_html} = get_criteria_file_html($dbh, $us_fk, \%ch);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";


  }

  ## Function calls for when source == an_cond
  if ($ch{source} eq "an_cond"){

    ## On submit insert an_conds into set; redirect to edit an_set
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{an_cond_pks}); # keys come in form string delimited by perl null
      insert_an_conds_into_an_set($ch{an_set_pk}, \@key_array, $dbh);
      post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", $ch{an_set_pk}, "edit_an_set.cgi");

    }

    ## Default print source html for an_cond
    $ch{source_html} = get_an_cond_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

  }

  ## Function calls for when source == exp_condition
  if ($ch{source} eq "exp_condition"){

    ## On submit insert exp_conditions into an_set; redirect to edit an_set
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{ec_pk});  # keys come in form string delimited by perl null
      insert_exp_conditions_into_an_set($ch{an_set_pk}, \@key_array, $dbh);
      post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", $ch{an_set_pk}, "edit_an_set.cgi");

    }

    ## Default print source html for exp_condition
    $ch{source_html} = get_exp_condition_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";
 
  }

  ## Function calls for when source == study
  if ($ch{source} eq "study"){

    ## On submit insert studies into an_set; redirect to edit an_set
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{sty_pk});  # keys come in form string delimited by perl null
      insert_studies_into_an_set($ch{an_set_pk}, \@key_array, $dbh);
      post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", $ch{an_set_pk}, "edit_an_set.cgi");

    }

    ## Default print source html for studies; set to checkbox to allow multiple selection
    $ch{source_form_type} = "checkbox";
    $ch{source_html} = get_study_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

  }

  ## Default draw page and exit
  draw_page($dbh, $us_fk, \%ch);
  $dbh->commit;
  $dbh->disconnect;
  exit(0);

}


sub draw_page
{
    my ($dbh, $us_fk, $chref) = @_;

    my %ch = %$chref;

    ## Get an_set values for GUI
    ($ch{an_set_name}, $ch{an_set_desc}, $ch{an_set_created}) = get_an_set($dbh, $ch{an_set_pk});

    $ch{message} = get_message($ch{message});
    $ch{htmltitle} = "Add Conditions to Set";
    $ch{help} = set_help_url($dbh, "edit_existing_set_of_conditions");
    $ch{htmldescription} = "Use the tools to add conditions to the set.";

    (my $allhtml) = readtemplate("add_an_cond_to_an_set.html","/site/webtools/header.html", "/site/webtools/footer.html"); 

    ## Get specified radio button source for GUI
    %ch = radio_source(\%ch);

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";

} # draw_page

