use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    
    %ch = $co->Vars();
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "orgtools/org_edit_mem.cgi");
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
        write_log("$us_fk runs org_edit_mem.cgi");
        my $url = index_url($dbh, "webtools"); # see session_lib
        print "Location: $url\n\n";
        $dbh->disconnect;
        exit();
    };

    if ((! exists($ch{step}) || $ch{step} == 2 || (! $ch{step}))) 
    {
      draw_edit_mem($dbh, $us_fk, $ch{org_pk})
    }
    elsif ($ch{step} == 3) {
        # step 3: edit the memberlist
        my $success  = edit_org_mem_generic($dbh, $us_fk, \%ch);

        if ($success eq "true")
        {
          set_session_val($dbh, $us_fk, "message", "goodmessage",
            get_message("SUCCESS_MODIFY_MEMBERS", "modified"));
          draw_edit_mem($dbh, $us_fk, $ch{org_pk});
        }
        else
        {
          $ch{step} = "";
          # currently doesn't redraw other configuration on error
          # I figure that is too much work.  Someone who is dumb
          # enough to try and remove themselves (only error currently
          # available) can take the time to re-check all their other
          # choices
          draw_edit_mem($dbh, $us_fk, $ch{org_pk});
        }
    }
    $dbh->disconnect;
    exit();
}

