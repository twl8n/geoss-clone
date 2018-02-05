use strict;
use CGI::Cookie;
require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $message = "";
    
    my $dbh = new_connection(); # session_lib
    my %ch = $q->Vars();
    
    my %cookies = fetch CGI::Cookie;
    foreach (keys %cookies) 
    {
      my $cookie_name = get_config_entry($dbh, "wwwhost") . $COOKIE_NAME;
      if ($cookies{$_}->name() eq $cookie_name)
      {
        #expire the cookie to force logout
        my $sid = $cookies{$_}->value();
        $cookies{$_}->expires('now');
        print "Set-Cookie: $cookies{$_}\n";

        #remove id from the session table
        my $sql = "delete from key_value where session_fk in (select session_pk from session where session_id = '$sid')";
        $dbh->do($sql) || die "Delete failed: $sql\n$DBI::errstr\n";
        $dbh->commit();
        $sql = "delete from session where session_id = '$sid'";
        $dbh->do($sql) || die "Delete failed: $sql\n$DBI::errstr\n";
        $dbh->commit();
      }
    }


    #remove cookie - present index
    my $url = index_url($dbh);
    $url =~ s/(.*)\/(.*)/\1/;
    print "Location: $url\n\n";
    $dbh->disconnect();
    exit();
}
