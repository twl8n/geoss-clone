use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/files.cgi");
    my $allhtml;
    my $htmlfile;
    $ch{file_name} = doq($dbh, "get_file_name", $ch{fi_pk});
    #
    # Remove repository path common stem. It has to be escaped.
    # Put it in a string for clarity. That darned / in the middle is a pain.
    #
    $ch{file_name} =~ s/\Q$USER_DATA_DIR\E/\./;
    if (is_writable($dbh, "file_info", "fi_pk", $ch{fi_pk}, $us_fk) == 1)
    {
      $htmlfile = "delete_file1.html";
    }
    else
    {
      $htmlfile = "cant_delete_file.html";
      my $msg = get_message("INVALID_PERMS");
      set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
    }
    if (is_in_use($dbh, $us_fk, "file_info", "fi_pk", $ch{fi_pk}) == 1)
    {
      $htmlfile = "cant_delete_file.html";
      my $msg = get_message("CANT_DELETE_FILE");
      set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
    }
    $ch{htmltitle} = "File Delete Confirmation";
    $ch{help} = set_help_url($dbh, "view_my_files");

    $allhtml = get_allhtml($dbh, $us_fk, $htmlfile, "/site/webtools/header.html", 
       "/site/webtools/footer.html", \%ch);

    print "Content-type: text/html\n\n";
    print "$allhtml\n";
    
    $dbh->disconnect;
    
    exit(0);
}

sub is_in_use
{
  my ($dbh, $us_fk, $table, $field, $value) = @_;
  my $in_use = 0;
  # I would like a generic solution that checks which constraints exist 
  # in the database, but I don't know how to do that.  Thus, if we add 
  # another constraint on fi_pk, then we will need to modify this code.

  # currently, the following tables may be using files
  # - organization (logo_fi_fk, icon_fi_fk)
  # - tree (fi_input_fk, fi_log_fk)
 
  my %constraints = (
   "icon_fi_fk" => "organization",
   "logo_fi_fk" => "organization",
   "fi_input_fk" => "tree",
   "fi_log_fk" => "tree",
  );

  while (my ($k, $v) = each(%constraints))
  {
    my $sql = "select count(*) from $v where $k = '$value'";
    my $sth = $dbh->prepare($sql) || die "prepare is_in_use: $sql\n$DBI::errstr\n";
    $sth->execute() || die "execute is_in_use  $sql\n$DBI::errstr\n";
    my ($count) = $sth->fetchrow_array(); 
    $in_use = 1 if ($count > 0);
  }
  return ($in_use);
}
