use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $es_pk = $q->param("es_pk");
    
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "orgtools/index.cgi");

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }

    if ((!is_administrator($dbh, $us_fk)) && (! is_org_curator($dbh, $us_fk)))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        write_log("$us_fk runs orgtools/index.cgi");
        my $url = index_url($dbh, "webtools"); # see session_lib
        print "Location: $url\n\n";
        $dbh->disconnect;
        exit();
    };

    
    draw_index($dbh, $us_fk, $q);

    $dbh->disconnect;
}

sub draw_index
{
    (my $dbh, my $us_fk, my $q) = @_;

    my $headerfile = "/site/webtools/header.html";
    my $footerfile = "/site/webtools/footer.html";

    my %ch = $q->Vars();

    $ch{htmltitle} = "GEOSS Organization Administration Interface";
    $ch{help} = set_help_url($dbh, "special_center_administrator_guide");
    $ch{htmldescription} = "These links can be used by a GEOSS organization administrator to manage organization data.\n";  

    my $allhtml = get_allhtml($dbh, $us_fk, "index.html",
	 "$headerfile", "$footerfile", \%ch);

    print "Content-type: text/html\n\n$allhtml\n";
}
