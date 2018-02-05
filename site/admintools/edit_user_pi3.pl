use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $mod_user_pi = 1;
my $add_user_pi = 2;


 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $error = 0;
    
    my $us_fk = get_us_fk($dbh, "admintools/edit_user_pi.cgi");
   if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }

    
    my $valsref = get_session_val($dbh, $us_fk, "pi_user", "");
    $ch{user_login} = $$valsref[1];
    if ($ch{AddPI} ne "")
    {

      if (! defined ($ch{user_login})) 
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      }
      elsif (! defined ($ch{pi_not_list}))
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      } else
      {
        my $user_us_pk = doq($dbh, "get_us_pk", $ch{user_login});
        my $pi_us_pk = doq($dbh, "get_us_pk", $ch{pi_not_list});

        doq($dbh, "insert_pi_key", $user_us_pk, $pi_us_pk);
      }
    }
    elsif ($ch{RemovePI} ne "")
    {
      if (! defined ($ch{user_login})) 
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      }
      elsif (! defined ($ch{pi_list}))
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      } else
      {
        my $user_us_pk = doq($dbh, "get_us_pk", $ch{user_login});
        my $pi_us_pk = doq($dbh, "get_us_pk", $ch{pi_list});
        if (doq($dbh, "count_pis_for_user", $user_us_pk, $pi_us_pk) <= 1 )
        {
         my $msg = get_message("CANT_REMOVE_LAST_PI");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
        }
        doq($dbh, "remove_pi_key", $user_us_pk, $pi_us_pk) if ($error ==0);
      }
    }
    elsif ($ch{AddUser} ne "")
    {
      if (! defined ($ch{user_login})) 
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      }
      elsif (! defined ($ch{user_not_list}))
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      } else
      {
        my $pi_us_pk = doq($dbh, "get_us_pk", $ch{user_login});
        my $user_us_pk = doq($dbh, "get_us_pk", $ch{user_not_list});

        doq($dbh, "insert_pi_key", $user_us_pk, $pi_us_pk) if ($error ==0);
      }

    }
    elsif ($ch{RemoveUser} ne "")
    {
      if (! defined ($ch{user_login})) 
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      }
      elsif (! defined ($ch{user_list}))
      {
         my $msg = get_message("FIELD_MANDATORY", "User");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
      } else
      {
        my $pi_us_pk = doq($dbh, "get_us_pk", $ch{user_login});
        my $user_us_pk = doq($dbh, "get_us_pk", $ch{user_list});
        if (doq($dbh, "count_pis_for_user", $user_us_pk, $pi_us_pk) <= 1 )
        {
         my $msg = get_message("CANT_REMOVE_LAST_PI");
         set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
         $error = 1;
        }

        doq($dbh, "remove_pi_key", $user_us_pk, $pi_us_pk) if ($error ==0);
      }
    }
    else
    {
	die "Unrecognized action for edit_user_pi3.cgi";
    }
    
    if (!$error)
    {
      my $msg = get_message("SUCCESS_UPDATE_FIELDS");
      set_session_val($dbh, $us_fk, "message", "goodmessage", $msg);
    }
    my $url = index_url($dbh); # see session_lib
    $url .="/edit_user_pi.cgi";
    print "Location: $url\n\n";

    $dbh->commit();
    $dbh->disconnect();
    exit();
}


