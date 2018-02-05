use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $q = new CGI;
   
  my $dbh = new_connection();
  my $us_fk = get_us_fk($dbh, "webtools/delete_an_cond.cgi");
  my %ch = $q->Vars();

  ## Check if user has double checked deletion; redirect to choose_an_cond after deletion
  if($ch{delete_check} eq "true"){
    
    ## Check if user has privileges to delete an_cond
    if (is_writable($dbh, "an_cond", "an_cond_pk", $ch{an_cond_pk}, $us_fk) == 1)
    {
	    delete_an_cond($dbh, $ch{an_cond_pk});
    }

    post_redirect($dbh, $us_fk, "", "", "", "choose_an_cond.cgi");


  }
  else{

    ##  Get an_cond information for GUI
    ($ch{an_cond_name}, $ch{an_cond_desc}, $ch{an_cond_created}) = get_an_cond($dbh, $ch{an_cond_pk});

    # format creation date of analysis condition
    $ch{an_cond_created} = sql2date($ch{an_cond_created});

    #create short description
    $ch{an_cond_desc} = substr($ch{an_cond_desc}, 0, 40);
    $ch{an_cond_desc} .= "..." if (length($ch{an_cond_desc}) > 39);

    ## Get number of ams in an_cond
    $ch{number_of_hybridizations} = get_number_ams_in_an_cond($ch{an_cond_pk}, $dbh);

    my $allhtml = readfile("delete_an_cond.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    $ch{htmltitle} = "Delete Analysis Condition";
    $ch{help} = set_help_url($dbh, "edit_existing_set_of_conditions");
    $ch{htmldescription} = "Double check analysis condition deletion.";
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g; # substitute fields outside the loop
    print "Content-type: text/html\n\n $allhtml\n";
  
  }

  $dbh->disconnect;
  exit(0);

}

