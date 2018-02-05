use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "curtools/insert_order_curator1.cgi");

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
    my %ch = $q->Vars();
    draw_insert_order_curator1($dbh, $us_fk, \%ch);
    $dbh->disconnect();
    exit();
}

