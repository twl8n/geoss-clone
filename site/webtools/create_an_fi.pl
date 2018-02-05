use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";


my $SUBMIT_VALUE = "Create File";

main:
{
  my $debug;
  my $q = new CGI;
  my $dbh = new_connection(); 
  my $us_fk = get_us_fk($dbh, "create_an_fi.cgi");
  my %ch = $q->Vars();
  my $login = doq($dbh, "get_login", $us_fk);
  my $directory = "$USER_DATA_DIR/$login/";



  ## Set default html output page
  $ch{html_page} = "create_an_fi.html";

  ## Check if request to edit an_set and redirect
  if ($ch{edit_an_set} ne ""){

    post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", $ch{edit_an_set}, "edit_an_set.cgi");

  }

  ## Check if valid file name on submit
  if ($ch{submit} eq $SUBMIT_VALUE){

    ## Check if file has proper .txt extension; add if necessary
    if (!($ch{file_name} =~ m/.txt/)){

      $ch{file_name} .= ".txt";

    }

    ## Check if file exists on system or if no name was specified;
    # stop submission if so
    if (-e $directory . $ch{file_name})
    { 
      $ch{message} = get_message("ERROR_FILE_EXISTS");
      $ch{submit} = "";
    }
    if ($ch{file_name} eq ".txt")
    {
      $ch{message} = get_message("INVALID_FILE_NAME");
      $ch{submit} = "";
    }

  }

  ## Check if there is a an_set source and present submit option if so
  if ($ch{source} ne ""){

    $ch{submit_html} .= "<input type=submit name=submit value=\"$SUBMIT_VALUE\">\n";

  }

  ## Functions for when source == public
  if ($ch{source} eq "public"){

   if ($ch{submit} eq $SUBMIT_VALUE){

      $ch{file_name} = $directory . $ch{file_name};
      $ch{html_page} =  "get_data4.html";
      
      #link the file from the public directory to this user's
      my ($ana_fk_fi, $file_name, $conds, $cond_labels, $al_fk) =
         getq_miame_ana_fi_info($dbh, $us_fk, $ch{miame_pk});

      `ln $file_name $ch{file_name}`;      

      my $fi_pk = fi_update($dbh, $us_fk, $us_fk,
                            $ch{file_name},
                            $ch{fi_comments},
                            $conds,
                            $cond_labels,
                            undef,
                            1,
                            undef,
                            432,
                            $al_fk);
      
    }

    $ch{source_form_type} = "radio";
    $ch{source_html} = get_public_html($dbh, $us_fk, \%ch);

  }

  ## Functions for when source == an_set
  if ($ch{source} eq "an_set"){

    ## On submit create analysis_hash (key = an_cond_pk; element = array of ams) and write file
    ## Redirect to get_data3.html
    if (($ch{submit} eq $SUBMIT_VALUE) && ($ch{an_set_pk} ne "")){

      my %analysis_hash = create_analysis_hash_from_an_set($ch{an_set_pk}, $dbh, $us_fk);
      $ch{file_name} = $directory . $ch{file_name};
      create_an_fi($dbh, \%ch, \%analysis_hash, $us_fk, "");
      $ch{html_page} =  "get_data3.html";

    }
    if (($ch{submit} eq $SUBMIT_VALUE) && ($ch{an_set_pk} eq "")){

      $ch{message} = get_message("DATA_SOURCE_MANDATORY");

    }

    ## Default html for an_set
    $ch{source_html} = get_an_set_html($dbh, $us_fk, \%ch);

  }

  ## Functions for when source == study
  if ($ch{source} eq "study"){

    ## On submit create an an_set from study; create analysis_hash and write file
    if (($ch{submit} eq $SUBMIT_VALUE) && ($ch{sty_pk} ne "")){


      my $gs_fk = get_users_group($dbh, $us_fk, $login);
      (my $study_name, my $sty_comments) = get_study($dbh, $ch{sty_pk});
      my $an_set_pk = create_an_set($dbh, $study_name, $sty_comments, $us_fk, $gs_fk);

      my @key_array = ($ch{sty_pk});
      insert_studies_into_an_set($an_set_pk, \@key_array, $dbh);
      my %analysis_hash = create_analysis_hash_from_an_set($an_set_pk, $dbh, $us_fk);
      $ch{file_name} = $directory . $ch{file_name};
      create_an_fi($dbh, \%ch, \%analysis_hash, $us_fk, "");
      $ch{html_page} =  "get_data3.html";

    }

    if (($ch{submit} eq $SUBMIT_VALUE) && ($ch{sty_pk} eq "")){

      $ch{message} = get_message("DATA_SOURCE_MANDATORY");

    }


    ## Default html for study; use radio buttons for selection of one study only
    $ch{source_form_type} = "radio";
    $ch{source_html} = get_study_html(\%ch, $dbh, $us_fk);

  }

  ## Draw html
  draw_page($dbh, $us_fk, \%ch);
  $dbh->disconnect;
  exit(0);

}


sub draw_page
{
    my ($dbh, $us_fk, $chref) = @_;

    my %ch = %$chref;

    $ch{htmltitle} = "Create Analysis File";
    $ch{help} = set_help_url($dbh, "user_gui");
    $ch{htmldescription} = "Use the tools to create an analysis file.";

    ## Merge html with main page $ch{html_page}
    (my $allhtml) = readtemplate($ch{html_page},"/site/webtools/header.html", "/site/webtools/footer.html"); 

    ## Check user selected radio source in GUI
    %ch = radio_source(\%ch);

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";

} # draw_page

