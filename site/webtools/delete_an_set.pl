use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{

  my $q = new CGI;
  my $dbh = new_connection();
  my $us_fk = get_us_fk($dbh, "webtools/delete_an_set.cgi");
  my %ch = $q->Vars();

  ## Check if user is sure about deletion; delete set if writable by user
  if($ch{delete_check} eq "true"){
    
    if (is_writable($dbh, "an_set", "an_set_pk", $ch{an_set_pk}, $us_fk) == 1)
    {
	    delete_an_set($dbh, $ch{an_set_pk});
    }

    post_redirect($dbh, $us_fk, "", "", "", "choose_an_set.cgi");

  }
  else{

    ## Get an_set values for GUI
    ($ch{an_set_name}, $ch{an_set_desc}, $ch{an_set_created}) = get_an_set($dbh, $ch{an_set_pk});

    # format creation date of analysis set
    $ch{an_set_created} = sql2date($ch{an_set_created});

    #create short description
    $ch{an_set_desc} = substr($ch{an_set_desc}, 0, 40);
    $ch{an_set_desc} .= "..." if (length($ch{an_set_desc}) > 39);

    ## Get number an_conds in an_set
    $ch{number_of_conditions} = get_number_an_conds_in_an_set($ch{an_set_pk}, $dbh);

    my $allhtml = readfile("delete_an_set.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    $ch{htmltitle} = "Delete Analysis Set";
    $ch{htmldescription} = "Double check set deletion.";
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g; # substitute fields outside the loop
    print "Content-type: text/html\n\n $allhtml\n";
  
  }

  $dbh->disconnect;
  exit(0);

}

