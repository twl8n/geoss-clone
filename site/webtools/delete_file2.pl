use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "webtools/files.cgi");
    my %ch = $q->Vars();

    if (is_writable($dbh, "file_info", "fi_pk", $ch{fi_pk}, $us_fk) == 1)
    {
	{
	    delete_file($dbh, $ch{fi_pk});
	}
    }
    $dbh->commit;
    
    my $url = index_url($dbh, "webtools"); # see session_lib
    $ch{pwd} = CGI::escape($ch{pwd});
    $ch{view_tree} = CGI::escape($ch{view_tree});
    $ch{file_pattern} = CGI::escape($ch{file_pattern});
    $url .= "/files2.cgi?pwd=$ch{pwd}&view_tree=$ch{view_tree}&file_pattern=$ch{file_pattern}";
    print "Location: $url\n\n";
    $dbh->disconnect;
    exit();
}

