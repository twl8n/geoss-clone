use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $co = new CGI;

    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "curtools/view_reports.cgi");

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }


    if (! is_curator($dbh, $us_fk))
    {
      GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }


    my %ch;
    $ch{htmltitle} = "View Reports";
    $ch{help} = set_help_url($dbh, "array_center_staff_view_reports");
    $ch{htmldescription} = ""; 
    my $allhtml = get_allhtml($dbh, $us_fk, "view_reports.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);

    print $co->header;
    print "$allhtml\n";
    print $co->end_html;

    $dbh->disconnect;
}
