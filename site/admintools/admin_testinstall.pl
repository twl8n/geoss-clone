use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $co = new CGI;
    my $dbh = new_connection();
    my $headerfile = "/site/webtools/header.html";
    my $footerfile = "/site/webtools/footer.html";
    my $us_fk = get_us_fk($dbh, "admintools/admin_testinstall.cgi");
    if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }


    my %ch = (
      "geoss_dir"  => $GEOSS_DIR,
      "html_dir" => $HTML_DIR,
      "web_dir" => $WEB_DIR,
      "user_data_dir" => $USER_DATA_DIR,
      "bin_dir" => $BIN_DIR,
      "lib_dir" => $LIB_DIR,
      "geoss_dbms" => $GEOSS_DBMS,
      "db_name" => $DB_NAME,
      "geoss_host" => $GEOSS_HOST,
      "geoss_port" => $GEOSS_PORT,
      "geoss_su_user" => $GEOSS_SU_USER,
      "perl_location" => $PERL_LOCATION,
      "cookie_name" => get_config_entry($dbh, "wwwhost") . $COOKIE_NAME,
      "version" => $VERSION,
    ); 

    # get version information
    my $version;
    $version = `/usr/sbin/httpd -v`;
    if ($? != 0)
    {
      $ch{web_server} = "<font color=\"red\">Web Server not installed</font>";
    }
    else
    {
      $version =~ /Server version: (.*)/;
      $ch{web_server} = $1;
    }
 
    $version = `postmaster --version`;
    if ($? != 0)
    {
      $ch{database} = "<font color=\"red\">Database not installed</font>";
    }
    else
    {
      $version =~ /postmaster (.*)/;
      $ch{database} = $1;
    }  

    $version = `R --version`;
    if ($? != 0)
    {
      $ch{rlang} = "<font color=\"red\">R 1.9 not installed</font>";
    }
    else
    {
      $version =~ /(R [0-9.]+ )/;
      $ch{rlang} = $1;
    }

    $version = `R2.1 --version`;
    if ($? != 0)
    {
      $ch{rlang} =
       "<font color=\"red\"> " . 
       "R 2.1 not installed or R2.1 link not created.</font>";
    }
    else
    {
      $version =~ /(R [0-9.]+ )/;
      $ch{'rlang2.1'} = $1;
    }

    # get directory permission info
    $ch{USER_DATA_DIR} = $USER_DATA_DIR;
    if (-w $USER_DATA_DIR)
    {
      $ch{w_user_data_dir} = "<font color=\"green\">Pass</font>";
    }
    else
    {
      $ch{w_user_data_dir} = "<font color=\"red\">Failed</font>";
    }

    if (-r $USER_DATA_DIR)
    {
      $ch{r_user_data_dir} = "<font color=\"green\">Pass</font>";
    }
    else
    {
      $ch{r_user_data_dir} = "<font color=\"red\">Failed</font>";
    }

    $ch{CHIP_DATA_PATH} = get_config_entry($dbh, "chip_data_path");
    if (-r $ch{CHIP_DATA_PATH})
    {
      $ch{r_chip_data_dir} = "<font color=\"green\">Pass</font>";
    }
    else
    {
      $ch{r_chip_data_dir} = "<font color=\"red\">Failed</font>";
    }
    $ch{CHIP_DATA_PATH} = "Path not set.  Use 'Configure GEOSS' to set \
      value." if (! $ch{CHIP_DATA_PATH});
    #if (-r get_config_entry($dbh, "layout_data_path")
    #{
    #  $ch{r_layout_dir} = "<font color=\"green\">Pass</font>";
    #}
    #else
    #{
    #  $ch{r_layout_dir} = "<font color=\"red\">Failed</font>";
    #}

    $ch{db_config_file} = "$WEB_DIR/.geoss";
    my $mode = (stat $ch{db_config_file})[2];
    my $val =  sprintf "%04o", $mode & 07777;
    $val =~ /..(..)/;
    if ($1 eq "00")
    {
      $ch{db_config_pass} = "<font color=\"green\">Pass</font>";
    } 
    else
    {
      $ch{db_config_pass} = "<font color=\"red\">Failed</font>";
    }

    # get layout names
    my $sth = getq("select_layout", $dbh);
    $sth->execute() || die "Query select_layout execute fails.\n $DBI::errstr\n";
    $ch{installed_layouts} = "<ul>";
    while ((my($layout_name)) = $sth->fetchrow_array())
    {
      $ch{installed_layouts} .= "<li>$layout_name</li>"; 
    }
    $ch{installed_layouts} .= "</ul>";

    # get analysis names
    my $sth = getq("select_analysis", $dbh);
    $sth->execute() || die "Query select_analysis execute fails.\n $DBI::errstr\n";
    $ch{installed_analyses} = "<ul>";
    while (my $hr = $sth->fetchrow_hashref())
    {
      $ch{installed_analyses} .= "<li>$hr->{an_name} Version: $hr->{version}</li>"; 
    }
    $ch{installed_analyses} .= "</ul>";

    $ch{htmltitle} = "GEOSS Installation Information";
    $ch{help}=set_help_url($dbh, "GEOSS_installation_information");
    $ch{htmldescription} = "This page contains information about how GEOSS was installed.";
    my $allhtml = get_allhtml($dbh, $us_fk, "admin_testinstall.html", 
      "$headerfile",
      "$footerfile",\%ch);

    print $co->header;
    print "$allhtml\n";
    print $co->end_html;
    $dbh->disconnect();
    exit();
}

