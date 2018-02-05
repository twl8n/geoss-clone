use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "curtools/index.cgi");
    if (! is_curator($dbh, $us_fk))
    {
        warn "Not curator";
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }    
    draw_index_curtools($dbh, $us_fk, $q);

    $dbh->disconnect;
}
