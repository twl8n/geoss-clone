use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $debug;
  my $q = new CGI;
    
  my $dbh = new_connection(); # session_lib
  my $us_fk = get_us_fk($dbh, "webtools/express_extract1.cgi");
  my %ch = $q->Vars();

  if (is_public($dbh, $us_fk))
  {
    set_return_message($dbh, $us_fk, "message","errmessage", "INVALID_PERMS");
    my $url = index_url($dbh, "webtools");
    print "Location: $url\n\n";
  }
  else
  {
    my $error = 0;

    my @conditions = ();
    if ($ch{paste_experiment} eq "Create Data File")
    {
      if (! $ch{paste_std_fk1})
      {
        set_session_val($dbh, $us_fk, "message", "errmessage", 
            get_message("FIELD_MANDATORY", "Study"));
        $error = 1;
      } 
      if (! $ch{file_name})
      {
        set_session_val($dbh, $us_fk, "message", "errmessage", 
            get_message("INVALID_FILENAME"));
        $error = 1;
      }
    }
    $ch{anchor} = "";
    if (($ch{paste_experiment} eq "Create Data File") && ($error == 0))
    {
      $ch{file_name} .= ".txt" if ($ch{file_name} !~ /txt$/);  
      $ch{anchor}=pasteExperiment($dbh, $us_fk, \@conditions, 
          $ch{paste_std_fk1});
      # only allow extract if all chips have the same type
      my $match = 1;
      my $layoutcomp = "";
      foreach my $cond (@conditions)
      {
        foreach my $hyb (@{$cond->{hybrids}})
        {
          #get the extra info to display
          my %elem;
          my $sth = getq("get_hyb_info_extract", $dbh);
          $sth->execute($hyb) || 
            die "Query get_hyb_info_extract failed.\n$DBI::errstr\n";
          my ($layout, undef, undef, undef, undef) =
            $sth->fetchrow_array();

          $layoutcomp = $layout if ($layoutcomp eq "");
          $match = 0 if ($layout ne $layoutcomp);
        }  
      }
      if ($match)
      {
        my $login = doq($dbh, "get_login", $us_fk);

        my $path= $USER_DATA_DIR . "/" . $login  ;
        $ch{file_name} = $path . "/" . $ch{file_name};

        extractFile($dbh, $us_fk, \%ch, \@conditions, "human");
      }
      else
      {
        $ch{message} = "LAYOUT_MISMATCH";
        $ch{message} = get_message($ch{message});
        saveExtractInfo($dbh, $us_fk, \%ch, \@conditions);
        write_log("Conds after save: @conditions");
        $ch{htmltitle} = "MAS5 hybridization data export";
        $ch{help} = set_help_url($dbh, "create_a_data_file_containing_all_data_for_one_study");
        $ch{htmldescription} = "This page allows users to download chip data for one microarray study (provided the data for all chips has been loaded).  Data is formatted as a tab-delimited file.  This file is cannot be used as input for analysis trees.";
        drawExtractionInfo($dbh, "express_extract1.html", \%ch, \@conditions, $us_fk, $debug);
      }
    }
    else
    {
      $ch{htmltitle} = "MAS5 hybridization data export";
      $ch{help} = set_help_url($dbh, "create_a_data_file_containing_all_data_for_one_study");
      $ch{htmldescription} = "This page can be used to extract chip data associated with an experiment. Use the drop down box to select the study to extract."; 
      drawExtractionInfo($dbh, "express_extract1.html", \%ch, \@conditions, $us_fk, $debug);
    }
    }
    $dbh->disconnect;
    exit(0);
}
