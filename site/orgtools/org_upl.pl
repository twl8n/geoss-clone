use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $debug;
my $q = new CGI;
my $dbh = new_connection(); 
my $us_fk = get_us_fk($dbh, "orgtools/org_upl.cgi");

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
    write_log("$us_fk runs org_upl.cgi");
    my $url = index_url($dbh, "webtools"); # see session_lib
    print "Location: $url\n\n";
    $dbh->disconnect;
    exit();
};

my %ch = $q->Vars();
$ch{action} = "org_upl.cgi";
$ch{helplink} = "upload_logo_or_icon_file";
if ($ch{submit} eq "Next")
{
  if (! exists $ch{filetype})
  {
    set_session_val($dbh, $us_fk, "message", "errmessage",
     get_message( "FIELD_MANDATORY", "File type"));
  }
}
elsif ($ch{submit} eq "Upload") 
{
  my $error = 0;
  if (! exists $ch{filetype})
  {
    set_session_val($dbh, $us_fk, "message", "errmessage",
      get_message("FIELD_MANDATORY", "File Type"));
    $error = 1;
  }
  elsif ($ch{filedata} eq "")
  {
    set_session_val($dbh, $us_fk, "message", "errmessage",
     get_message("FIELD_MANDATORY", "File to Upload"));
    $error = 1;
  }
  my $source_file = $q->param('filedata');
  if ($ch{file_name})
  {
    $source_file =~ /(.*)\.(.*)/;
    my $source_ext = $2;
    if ($ch{file_name} =~ /(.*)\.(.*)/)
    {
      my $dest_base = $1;
      my $dest_ext = $2;
      if ($dest_ext ne $source_ext)
      {
        set_session_val($dbh, $us_fk, "message", "warnmessage",
          get_message("EXTENSION_MISMATCH", $source_ext, $dest_ext));
        $error = 1;
      }
    }
    else
    {
      $ch{file_name} .= ".$source_ext";
    }
  }
  else
  {
    $ch{file_name} = $source_file;
  }
  if (!$error)
  {
    upload_file($dbh, $us_fk, \%ch, $q);
    $dbh->disconnect;
    exit(0);
  }
}
drawUploadInfo($dbh, $us_fk, \%ch);
$dbh->disconnect;
exit(0);

