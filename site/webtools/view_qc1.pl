use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/view_qc1.cgi");
    
    if (is_public($dbh, $us_fk))
    {
      set_return_message($dbh, $us_fk, "message","errmessage", "INVALID_PERMS");
      my $url = index_url($dbh, "webtools");
      print "Location: $url\n\n";

    }
    else
    {

    $ch{qc_list} = qc_list($dbh, $us_fk);
    if ($ch{qc_list} =~ /option/)
    {   
      $ch{htmltitle} = "Choose Quality Control";
      $ch{help} = set_help_url($dbh, "view_quality_control_records");
      my $allhtml = get_allhtml($dbh, $us_fk, "view_qc1.html", "/site/webtools/header.html", 
      "/site/webtools/footer.html", \%ch);
      print "Content-type: text/html\n\n$allhtml\n";
    }
    else
    {
      set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_VIEW_QC_NO_DATA");
      my $url = index_url($dbh, "webtools");
      print "Location: $url\n\n";
    }   

    }
    $dbh->disconnect();
    exit(0);

}

sub qc_list
{
    my $dbh = $_[0];
    my $us_fk = $_[1];
    my $results = "<select name=\"qc_fk\">\n";
    my $sth = getq("qc_list", $dbh, $us_fk);
    $sth->execute() || die "execute qc_list\n$DBI::errstr\n";
    while((my $qc_fk, my $hybridization_name) = $sth->fetchrow_array())
    {
	$results .= "<option value=\"$qc_fk\">$hybridization_name</option>\n";
    }
    $results .= "</select>\n";
    return $results;
}

