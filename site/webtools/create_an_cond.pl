use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $debug;
  my $q = new CGI;
    
  my $dbh = new_connection(); # session_lib
  my $us_fk = get_us_fk($dbh, "webtools/create_an_cond.cgi");
  my %ch = $q->Vars();
  my $login = doq($dbh, "get_login", $us_fk);

  if (($ch{submit} eq "Next") && ($ch{an_cond_name} eq ""))
  {
    set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("NAME_CANT_BE_BLANK"));
  }
  ## Check if new an_cond requested and make new an_cond; redirect to edit an_cond
  if (($ch{submit} eq "Next") && ($ch{an_cond_name} ne ""))
  {
    ($ch{owner_us_pk}, $ch{owner_gs_pk}) = split(',', $ch{pi_info});
    my $an_cond_pk = create_an_cond($dbh, $ch{an_cond_name}, $ch{an_cond_desc}, $ch{owner_us_pk}, $ch{owner_gs_pk});

   post_redirect($dbh, $us_fk, "add_am_to_an_cond", "an_cond_pk", $an_cond_pk, "add_am_to_an_cond.cgi");
  #    post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk", $an_cond_pk, "edit_an_cond.cgi");
  }
  else
  {
    $ch{htmltitle} = "Create Analysis Condition";
    $ch{html} = set_help_url($dbh,"create_new_analysis_condition");
    $ch{htmldescription} = "Define a new analysis condition.";

    ## Get user group information for GUI
    $ch{select_groups_html} = get_select_groups_html($dbh, $us_fk, $login);

    my $allhtml = get_allhtml($dbh, $us_fk, "create_an_cond.html", "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
    $allhtml = fixselect("pi_info", $ch{pi_info}, $allhtml);
    print "Content-type: text/html\n\n$allhtml";
  }
  $dbh->disconnect;
  exit(0);
}
