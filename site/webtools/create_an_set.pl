use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
  my $debug;
  my $q = new CGI;
    
  my $dbh = new_connection(); # session_lib
  my $us_fk = get_us_fk($dbh, "webtools/create_an_set.cgi");
  my %ch = $q->Vars();
  my $login = doq($dbh, "get_login", $us_fk);

  if (($ch{submit} eq "Next") && ($ch{an_set_name} eq ""))
  {
    set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("NAME_CANT_BE_BLANK"));
  }

  ## Check if new an_set requested and create an_set; redirect to edit an_set
  if (($ch{submit} eq "Next") && ($ch{an_set_name} ne ""))
  {
    ($ch{owner_us_pk}, $ch{owner_gs_pk}) = split(',', $ch{pi_info});
    my $an_set_pk = create_an_set($dbh, $ch{an_set_name}, $ch{an_set_desc}, $ch{owner_us_pk}, $ch{owner_gs_pk});
    $ch{just_created} = 1;

    post_redirect($dbh, $us_fk, "add_an_cond_to_an_set", "an_set_pk", $an_set_pk, "add_an_cond_to_an_set.cgi");
#    post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", $an_set_pk, "edit_an_set.cgi");
  }

  $ch{htmltitle} = "Create Analysis Set";
  $ch{help} = set_help_url($dbh, "create_new_set_of_conditions");
  $ch{htmldescription} = "Define a new analysis set.";

  ## Get user group information for GUI
  $ch{select_groups_html} = get_select_groups_html($dbh, $us_fk, $login);

  my $allhtml = get_allhtml($dbh, $us_fk, "create_an_set.html", "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
  $allhtml = fixselect("pi_info", $ch{pi_info}, $allhtml);

  print "Content-type: text/html\n\n$allhtml";

  $dbh->commit;
  $dbh->disconnect;
  exit(0);
}
