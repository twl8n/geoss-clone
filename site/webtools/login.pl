use strict;
use CGI::Cookie;
use MIME::Base64;
use IO::File;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $message = "";
    
    my $dbh = new_connection(); # session_lib
    my %ch = $q->Vars();
    if (exists $ch{'login'})
    {
        if (my $user = checkValidUser($dbh, $ch{login}, $ch{password}))
        {
          my $unique = 0;
          my $val;
          while ($unique != -1)
          {
            $val = s3Kur3_raNd0m(8);
            my $sql = "select * from session where session_id = '$val'";
            my @result = $dbh->selectrow_array($sql);

            $unique = $#result;
          }
          
          my $sth = getq("get_user_type_by_login", $dbh, "$ch{login}");
          $sth->execute();
          my ($type) = $sth->fetchrow_array();
          $sth->finish();

          if ($type eq "disabled")
          {
           $message = "CANT_LOGIN_DISABLED";
          }
          else
          {
            my $cookie_name = get_config_entry($dbh, "wwwhost") .
              $COOKIE_NAME;
            my $expire = get_expire($dbh, $val, $cookie_name, $type);
            my $sql;

            my %cookies = fetch CGI::Cookie;
            my @keys = keys(%cookies);


            # check if the user currently has a session.  If they do,
            # remove it
            my $exists = doq_get_sessionid($dbh, $user);
            my $exists_sess_fk = doq_get_session_pk($dbh, $exists);
            if (defined $exists)
            {
              $sql = "delete from key_value where session_fk='$exists_sess_fk'";
              $dbh->do($sql) or die "sql: $sql\n$DBI::errstr\n";
              $dbh->commit();
              $sql = "delete from session where session_id = '$exists'";
              $dbh->do($sql) or die "sql: $sql\n$DBI::errstr\n";
              $dbh->commit();
            }
           

            #insert value and login id into the session table
	    $sql = "insert into session (session_id, us_fk, expiration) " .
              "values ('$val', $user, '$expire')";
            $dbh->do($sql) || die "Insert failed: $sql\n $DBI::errstr\n";
            $dbh->commit();

            my $last_login = doq_get_last_login($dbh, $user);
            #update the last_login field in usersec
            my $now = localtime;
            $sql = "update usersec set last_login = ? where us_pk = $user";
            my $sth = $dbh->prepare($sql) || die "Prepare failed: $sql\n $DBI::errstr\n";
            $sth->execute($now) || die "Update failed: $sql\n $DBI::errstr\n";
            $dbh->commit();
             
            my $url; 
            # go to appropriate page

            if ($last_login eq "")
            {
              # set a message informing user that they are required to change
              # their password
              my $msg = get_message("WARN_CHANGE_PASSWORD");
              set_session_val($dbh, $user, "message", "errmessage", $msg);

              $url = index_url($dbh, "webtools") . "/user_password.cgi";
            }
            elsif ((defined $ch{'page'}) && ($ch{'page'} !~ /index.cgi/))
            {
              $url = index_url($dbh);
              $url =~ s/(.*)\/.*/$1\/$ch{'page'}/
            }
            elsif ($type =~ /administrator/)
            {
              $url = index_url($dbh);
              $url =~ s/webtools/admintools/;
            } 
            elsif ($type =~ /curator/)
            {
              $url = index_url($dbh);
              $url =~ s/webtools/curtools/;
            } 
            elsif (is_org_curator($dbh, $user))
            {
              $url = index_url($dbh);
              $url =~ s/webtools/orgtools/;
            } 
            else
            {
              $url = index_url($dbh);
            }   

            print "Location: $url\n\n";
            $dbh->disconnect();
            exit();
          }
	}
        else
        {
           $message = "ERROR_INVALID_LOGIN";
        }
    }
    my $allhtml = readfile("login.html");
    $ch{message} = get_message($message) if ($message);
    $ch{htmltitle} = "GEOSS Login";
    $ch{help} = set_help_url($dbh, "user_gui");

    $allhtml =~ s/{(.*?)}/$ch{$1}/g; 
    print "Content-type: text/html\n\n$allhtml\n";

    $dbh->disconnect();
}

sub checkValidUser
{
  my ($dbh, $user, $password) = @_;

  my $epasswd = &pw_encrypt($user, $password);
  my $sql = "select us_pk, password from usersec where login = '$user'";
  (my ($us_pk, $actualPass)= $dbh->selectrow_array($sql));
  if ((defined $actualPass) && ($actualPass eq $epasswd))
  {
    return $us_pk;
  }
  return 0;
}
