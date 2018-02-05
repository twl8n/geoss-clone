use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
my %ch = $q->Vars();

my $debug;
my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, "webtools/choose_miame1.cgi");

if (is_public($dbh, $us_fk))
{
  set_return_message($dbh, $us_fk, "message","errmessage", "INVALID_PERMS");
  my $url = index_url($dbh, "webtools");
  print "Location: $url\n\n";

}
else
{
  if (! get_config_entry($dbh, "data_publishing"))
  {
    GEOSS::Session->set_return_message("errmessage",
        "ERROR_DATA_PUBLISHING_NOT_ENABLED");
    print "Location: " . index_url($dbh, "webtools") . "\n\n";
    exit;
  }

  my $allhtml = readfile("choose_miame1.html", "/site/webtools/header.html", 
    "/site/webtools/footer.html");
  $allhtml =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
  my $loop_template = $1;

  my ($fclause, $wclause) = write_where_clause("miame", "miame_pk", $us_fk);
  my $sql = "select miame_pk, miame_name, miame_description, " . 
    " start_compile_date, publish_date " . 
    " from miame, $fclause where $wclause order by miame_pk desc";        
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $s_hr;
  while ($s_hr = $sth->fetchrow_hashref())
  {
    $ch{delete_info} = "";
    $ch{miame_name} = $s_hr->{miame_name};
    $ch{miame_pk} = $s_hr->{miame_pk};
    $ch{miame_description} = $s_hr->{miame_description};
    $ch{start_compile_date} = $s_hr->{start_compile_date};
    $ch{publish_date} = $s_hr->{publish_date};
    if (!defined $ch{publish_date})
    {
      $ch{delete_info} = qq!<input type="submit" name = "Delete_$ch{miame_pk}" value =! .
        qq!"Delete $ch{miame_name}"> \n <input type="image" ! .
        qq!border="0" name="imageField2" src="../graphics/trash.gif" ! .
        qq!width="25" height="25">!;
    }


    my $loop_instance = $loop_template;
    $loop_instance =~ s/{(.*?)}/$ch{$1}/g;
    $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
  }

  $allhtml =~ s/<loop_here>//;
  $ch{htmltitle} = "Choose MIAME Information to Edit";
  $ch{html} =
    set_help_url($dbh,"edit_or_delete_or_submit_publishing_information");
  $ch{htmldescription} = "You may alter or add to MIAME information for data you plan to publish.  Select the MIAME record that you wish to edit.";
  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

  $allhtml =~ s/{(.*?)}/$ch{$1}/g;

  print $q->header;
  print "$allhtml\n";
  print $q->end_html;
}
$dbh->disconnect();

exit();
