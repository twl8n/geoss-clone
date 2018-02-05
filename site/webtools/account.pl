use strict;
use CGI;
use GEOSS::Util;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %ch;
    my $co = new CGI;
    my $dbh = new_connection();
    
    %ch = $co->Vars();
    $ch{htmltitle} = "Update my Personal Information";
    $ch{help} = set_help_url($dbh, "account_management");
    $ch{htmldescription} = "";
    my $us_fk = get_us_fk($dbh, "webtools/account.cgi");
    my $sql = "select con_fk from usersec where us_pk=$us_fk";
    (my $con_fk) = $dbh->selectrow_array($sql);

    if ((! exists($ch{step}) || $ch{step} == 2 || (! $ch{step})))
    {
        my $sql = "select * from contact where con_pk=$con_fk";
        my $chref = $dbh->selectrow_hashref($sql); 
        $chref->{htmltitle} = "Update my Personal Information";
        $chref->{help} = set_help_url($dbh, "account_management");
        my $allhtml = get_allhtml($dbh, $us_fk, "account.html", 
            "/site/webtools/header.html", "/site/webtools/footer.html", $chref);
        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
        $dbh->disconnect();
        exit();
    }
    elsif ($ch{step} == 3) 
    {
        # step 3: update contact information
        my $now = localtime;
        my $chref = \%ch;
        my $success = 1; # used to have a check if email addy was valid
                       # should re-add
        if ($success == 1)
        {
          my $sql = "update contact set organization=trim(?), 
            org_phone=trim(?), org_toll_free_phone=trim(?), 
            org_fax=trim(?), contact_fname=trim(?), contact_lname=trim(?), 
            credentials=trim(?), contact_phone=trim(?), contact_email=trim(?),
            org_email=trim(?), org_mail_address=trim(?), url=trim(?), 
            last_updated=? where con_pk=?";
          my $cih = $dbh->prepare($sql);
        
          eval {
            $cih->execute($ch{organization},
                      $ch{org_phone},
                      $ch{org_toll_free_phone},
                      $ch{org_fax},
                      $ch{contact_fname},
                      $ch{contact_lname},
		                  $ch{credentials},
                      $ch{contact_phone},
                      $ch{contact_email},
                      $ch{org_email},
                      $ch{org_mail_address},
                      $ch{url},
                      $now,
                      $con_fk); 
          };
          if ($@)
          {
            $success = GEOSS::Util->report_postgres_err($@);
            $dbh->rollback;
          }
          else
          { 
            my $msg = get_message("SUCCESS_UPDATE_FIELDS");
            set_session_val($dbh, $us_fk, "message","goodmessage",$msg);
            $dbh->commit;
          }
        }

        my $allhtml = get_allhtml($dbh, $us_fk, "account.html", 
            "/site/webtools/header.html", "/site/webtools/footer.html", 
            $chref);

        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
    }
    $dbh->disconnect;
    exit();
}

