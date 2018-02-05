use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";


my $SUBMIT_VALUE = "Add Hybrids to Condition";

main:
{
    my $debug;
    my $q = new CGI;
    my $dbh = new_connection(); 
    my $us_fk = get_us_fk($dbh, "add_am_to_an_cond.cgi");
    my %ch = $q->Vars();
    my %criteria_hash = ();
    my $login = doq($dbh, "get_login", $us_fk);

 ## Check if no an_cond_pk in post and get session an_cond_pk if necessary
  if ($ch{an_cond_pk} eq ""){

    my $value_array_ref = get_session_val($dbh, $us_fk, "add_am_to_an_cond", "an_cond_pk");
    my @value_array = @$value_array_ref;
    $ch{an_cond_pk} = $value_array[1];

  }

  ## Check if request to edit an_cond and redirect if necessary
  check_redirect($dbh, $us_fk, \%ch);

  ## Functions for when source == an_cond
  if ($ch{source} eq "an_cond"){

    ## On submit insert an_conds' ams into an_cond; redirect to edit an_cond
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{an_cond_pks});  # keys stored in form string delimited by perl null
      insert_an_conds_into_an_cond($ch{an_cond_pk}, \@key_array, $dbh);
      post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk", $ch{an_cond_pk}, "edit_an_cond.cgi");

    }

    ## Default source html for an_cond
    $ch{source_html} = get_an_cond_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";
 
  }


  ## Functions for when source == study
  if ($ch{source} eq "study"){

    ## On submit insert studies' ams into an_cond; redirect to edit an_cond
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{sty_pk});  # keys stored in form string delimited by perl null
      insert_studies_into_an_cond($ch{an_cond_pk}, \@key_array, $dbh);
      post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk", $ch{an_cond_pk}, "edit_an_cond.cgi");

    }

    ## Default source html for study; use checkbox for multiple selection
    $ch{source_form_type} = "checkbox";
    $ch{source_html} = get_study_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

}


  ## Functions for when source == exp_condition
  if ($ch{source} eq "exp_condition"){

    ## On submit insert exp_conditions' ams into an_cond; redirect to edit an_cond
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{ec_pk});  # keys stored in form string delimited by perl null
      insert_exp_conditions_into_an_cond($ch{an_cond_pk}, \@key_array, $dbh);
      post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk", $ch{an_cond_pk}, "edit_an_cond.cgi");

    }

    ## Default source html for exp_condition
    $ch{source_html} = get_exp_condition_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

  }


  ## Functions for when source == arraymeasurement
  if ($ch{source} eq "arraymeasurement"){

    ## On submit insert ams into an_cond; redirect to edit an_cond
    if ($ch{submit} eq $SUBMIT_VALUE){

      my @key_array = split('\0', $ch{am_pk});  # keys stored in form string delimited by perl null
      insert_ams_into_an_cond($ch{an_cond_pk}, \@key_array, $dbh, "am_pk");
      post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk", $ch{an_cond_pk}, "edit_an_cond.cgi");

    }

    ## Default source html for ams
    $ch{source_html} = get_am_html(\%ch, $dbh, $us_fk);
    $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

  }

  ## Functions for when source == criteria file
  if ($ch{source} eq "criteria_file"){

    ## Check if no file selected; if no file print select menu; if file make criteria has
    if ($ch{criteria_file_fk} ne ""){

      %criteria_hash = parse_criteria_file($dbh, $ch{criteria_file_fk});

      ## On submit insert criteria ams (using am names) into an_cond; redirect to edit an_cond
      if ($ch{submit} eq $SUBMIT_VALUE){

        insert_criteria_into_an_cond(\%criteria_hash, \%ch, $dbh);
        post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk", $ch{an_cond_pk}, "edit_an_cond.cgi");

      }

      ## Default source html for criteria
      $ch{source_html} = get_criteria_html(\%criteria_hash);
      $ch{source_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

    }
  
    ## Default html of file select menu
    $ch{criteria_file_html} = get_criteria_file_html($dbh, $us_fk, \%ch);
    $ch{criteria_file_html} .= "<input type=submit name=submit value=\"Get Criteria File\">\n";


  }

  ## Default page draw
  draw_page($dbh, $us_fk, \%ch);
  $dbh->commit;
  $dbh->disconnect;
  exit(0);

}


sub draw_page
{
    my ($dbh, $us_fk, $chref) = @_;

    my %ch = %$chref;

    ## Get an_cond object values for GUI
    ($ch{an_cond_name}, $ch{an_cond_desc}, $ch{an_cond_created}) = get_an_cond($dbh, $ch{an_cond_pk});

    $ch{message} = get_message($ch{message});
    $ch{htmltitle} = "Add Hybridization(s) to Analysis Condition";
    $ch{help} = set_help_url($dbh, "edit_existing_analysis_conditions");
    $ch{htmldescription} = "Use the tools to add hybridizations to the analysis condition.";

    (my $allhtml) = readtemplate("add_am_to_an_cond.html","/site/webtools/header.html", "/site/webtools/footer.html"); 

    ## Get user selected radio source for GUI
    %ch = radio_source(\%ch);

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";

} # draw_page

