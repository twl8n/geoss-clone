#!/usr/bin/perl

use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

my $debug;
my $q = new CGI;
    
my $dbh = new_connection(); 
my $us_fk = get_us_fk($dbh, "webtools/upl_filetype.cgi");
my %ch = $q->Vars();
$ch{action} = "upl_filetype.cgi";
my $upl_file = "upl_filetype.html";
my $upl_help = "upload_a_file";

if ($ch{submit} eq "Next")
{
  if (! exists $ch{filetype})
  {
    set_session_val($dbh, $us_fk, "message", "errmessage", get_message(
        "FIELD_MANDATORY", "File type"));
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
  elsif ($ch{filetype} eq "mas5")
  {
    if (! $ch{hyb_name})
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("FIELD_MANDATORY", "Hybridization Name"));
      $error = 1;
    }
    else
    {
      # verify that the hyb name is not in use
      if (check_duplicate_hyb_name($dbh, $us_fk, $ch{hyb_name}))
      {
        set_return_message($dbh, $us_fk, "message", "errmessage",
          "FIELD_MUST_BE_UNIQUE", "Hybridization Name");
        $error = 1;
      }
    }
    if ((! $ch{al_fk}) || ($ch{al_fk} =~ /Not Listed/))
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
      get_message("FIELD_MANDATORY", "Affymetrix Chip"));
      $error = 1;
    }
  }  
  elsif ($ch{filetype} eq "analysis_input")
  {
    $upl_file = "upl_ana_in.html";
    $upl_help = "upload_analysis_input_file";
    $ch{al_fk} = 0 if (! $ch{al_fk});
    if (! $ch{conds})
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("FIELD_MANDATORY", "Condition Grouping"));
      $error =1;
    }
    elsif ($ch{conds} !~ /^(\d+,)+\d+$/)
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("ERROR_CONDITION_GROUPING_FORMAT", "Condition Grouping"));
      $error =1;
    }
    if (! $ch{cond_labels})
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("FIELD_MANDATORY", "Condition Grouping"));
      $error = 1;
    }
    elsif ($ch{cond_labels} !~ /^(\w+,)+\w+$/)
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("ERROR_CONDITION_LABELS_FORMAT"));
      $error =1;
    }
  } 
  if (! $error)
  {
    if (split(/,/,$ch{conds}) ne split(/,/,$ch{cond_labels}))
    {
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("ERROR_NE_CONDS_AND_CONDS_LABELS"));
      $error =1;
    }
  }
  if (! $error)
  {
    # add double quotes around the condition labels
    
    my $temp = "";
    map { $temp .= "\"$_\","} split(/,/,$ch{cond_labels});
    chop($temp); # remove trailing comma
    $ch{cond_labels} = $temp;  
    upload_file($dbh, $us_fk, \%ch, $q);
    $dbh->disconnect();
    exit();
  }
}
drawUploadInfo($dbh, $us_fk, \%ch);
$dbh->disconnect;
exit(0);

