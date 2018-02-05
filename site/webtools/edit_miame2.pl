use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_miame_lib";

my $q = new CGI;
my %ch = $q->Vars();
$ch{miame_name} = format_miame_name($ch{miame_name});
my $dbh=new_connection();
my $us_fk = get_us_fk($dbh, "webtools/choose_miame1.cgi");

if (! get_config_entry($dbh, "data_publishing"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_DATA_PUBLISHING_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}


my $htmlfile;

my ($login, $fname, $lname, $credential, $oemail) = doq($dbh, "miame_owner_info", $ch{miame_pk});
$credential = ", " . $credential if (defined $credential);
$credential = "" if (!defined $credential);
my $invname = $fname . "_" . $lname;

my $htmltitle;
if ((defined $ch{save}) && ($ch{save} eq "Save form"))
{
  save_miame_data($dbh, $us_fk, $ch{miame_pk}, \%ch);
  $htmlfile="save_miame.html";
  $htmltitle = "Save MIAME";
}
elsif ((defined $ch{submit}) && ($ch{submit} eq "Submit information"))
{
  $htmlfile = "submit_miame.html";
  $htmltitle = "Submit MIAME";
  my $today = `date`; chomp($today);
  save_miame_data($dbh, $us_fk, $ch{miame_pk}, \%ch);
  my $args= "\"" . $ch{miame_pk} . "\" " .  $invname  . " " . 
    "\"" . $ch{miame_name} . "\" " .  "\"$credential\" $us_fk";
  my $cmd="$WEB_DIR/site/webtools/make_miame_files.cgi";
  warn "Submitting $cmd $args";
  my $retval = `$cmd $args`; 
  warn "Retval is $retval DONE RETVAL";
  my $email = $ch{addy} = get_config_entry($dbh, "pub_data_email");
  my ($ulogin, undef, $ufname, $ulname) = 
    doq($dbh, "user_info", $us_fk, $us_fk);

# if the person publishing the data is not the owner, alert the owner
  if ($login ne $ulogin)
  {
    warn "Sending email to owner $login ne $ulogin";
    open (MAIL, "| mail -s \"Publish data request\" $oemail") or
      warn "Can't send mail to $oemail: $!\n";
    print MAIL "Metadata for $ch{miame_name} ($ch{miame_pk}) has been published by $ufname $ulname.\n";
    print MAIL "Gene chip data for this study is owned by you.\n";
    print MAIL "If you do not want this data published, please contact the GEOSS administrator immediately at $email.\n";
    close(MAIL);
  }

  if (! $retval)
  {
# only alert the administrator if data files have not been put
# on the system
    my $allfile = "$WEB_DIR/site/public_files/${invname}/${invname}_$ch{miame_name}_all.zip";
    warn "All file is $allfile";
    if (! -e $allfile)
    {
      open (MAIL, "| mail -s \"Publish data request\" $email") or
        warn "Can't send mail to $email: $!\n";
      print MAIL "Metadata for $ch{miame_name} ($ch{miame_pk}) has been published.\n";
      print MAIL "Data was published by $ufname $ulname ($ulogin).\n";                print MAIL "Data is owned by $fname $lname ($login).\n";
      print MAIL "The following data files need to be uploaded:\n";
      print MAIL "\t ${invname}_$ch{miame_name}_all.zip\n";
      print MAIL "\t ${invname}_$ch{miame_name}_cel.zip\n";
      print MAIL "\t ${invname}_$ch{miame_name}_chp.zip\n";
      print MAIL "\t ${invname}_$ch{miame_name}_exp.zip\n";
      print MAIL "\t ${invname}_$ch{miame_name}_rpt.zip\n";
      print MAIL "They should be copied to $WEB_DIR/site/public_files/${invname}\n\n";
      print MAIL "Don't forget to update the publish_date field in the database when you upload the files.\n";
      print MAIL "update miame set publish_date = <date> where miame_pk = $ch{miame_pk};\n";

      print MAIL "*****************************************\n";

      warn "In !retval - sending request to upload files";
      close (MAIL);
    }
    $ch{publish_date} = date2sql($today);
    save_miame_data($dbh, $us_fk, $ch{miame_pk}, \%ch);
  }
  else
  {
    my $msg = get_message("ERROR_PUBLISH_DATA");
    set_session_val($dbh, $us_fk, "message", "errmessage", $msg);

    open (MAIL, "| mail -s \"Publish data request failure\" $email") or
      warn "Can't send mail to $email: $!\n";
    warn "Publish data failed - sending email to that effect";
    print MAIL "Metadata publishing FAILED.\n";
    print MAIL "Return value from make_miame_files: $retval\n";
    print MAIL "Check apache error log for details.\n";
    if (-e "/var/log/httpd/error_log")
    {
      print MAIL "Potentially related info from error_log: \n";
      print MAIL `tail /var/log/httpd/error_log`;
    } 
    $htmlfile = "submit_miame_fail.html";
  }
  close (MAIL);
}

$ch{message} = "";
$ch{htmltitle} = $htmltitle;
$ch{htmldescription} = "";
$ch{help} = set_help_url($dbh, "edit_or_delete_or_submit_publishing_information");
my $allhtml = get_allhtml($dbh, $us_fk, "$htmlfile", "/site/webtools/header.html",
    "/site/webtools/footer.html", \%ch);
print $q->header;
print "$allhtml\n";
print $q->end_html;
$dbh->disconnect();
exit();
