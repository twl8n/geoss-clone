use strict;

use CGI;

use File::Find;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/files2.cgi");
    my %ch = $q->Vars();
    

    if (exists $ch{submit_view_type})
    {
      if ($ch{submit_view_type} =~ /Tree/)
      {
        $ch{view_tree} = "tree"; 
      }
      else
      {
        $ch{view_tree} = "current"; 
      }
    }

    my $new_pwd = modify_pwd($dbh, $us_fk, \%ch);
    if ($new_pwd ne "")
    {
       $ch{pwd} = $new_pwd;
    }

    if ((exists $ch{submit_view_type}) &&
        (exists $ch{submit_filter}) &&
        (exists $ch{submit_owner}) &&
        (exists $ch{submit_order}) &&
        (exists $ch{submit_sample}) &&
        (exists $ch{submit_analysis}))
    {
      # redirect with new value
      my $url= index_url() . "/files2.cgi?" . url_append(\%ch);
      print "Location:$url\n\n";
      $dbh->disconnect();
      exit(0); 
    }

    # set default value for viewing preference
    # normally set to tree as per Jae's requirement
    # however, to improve processing time for curators, we set to 
    # current if the user is a curator
    if (! exists $ch{view_tree})
    {
      if (is_curator($dbh, $us_fk))
      {
        $ch{view_tree} = "current";
      }
      else
      {
        $ch{view_tree} = "tree";
      }
    }

    $ch{directory_navigator} = get_directory_navigator($dbh, $us_fk, \%ch);
    my ($file_ref) = get_files($dbh, $us_fk, \%ch);

    draw_file_view($dbh, $us_fk, \%ch, $file_ref);
    $dbh->disconnect();
    exit(0);
}

sub modify_pwd
{
  my ($dbh, $us_fk, $chref) = @_;
  my $new_pwd = "";
  my ($login, $fname, $lname, undef) = doq($dbh, "user_info2", $us_fk);

  # we either: 
  #  - wish to go to a quick pick input 
  #  - wish to go to directory input 
  #  - wish to stay in the same place and apply a filter/view_type
  #  - have no input (came from menu) and wish to go to our home dir

  #  - we need to return - the directory we are in

  if (! exists $chref->{pwd})
  {
     # we have no information, so let's go to our home directory
     $chref->{pwd} = "$USER_DATA_DIR/$login";
  }

  if (exists $chref->{submit_owner})
  {
    if ($chref->{file_owner} eq "All")
    {
      $new_pwd = "$USER_DATA_DIR";
    }
    else
    {
      $new_pwd = "$USER_DATA_DIR/$chref->{file_owner}";
    }
  } elsif (exists $chref->{submit_order})
  {
    my $dir = "$USER_DATA_DIR/$chref->{order}";
    if (-d "$dir")
    {
      $new_pwd = "$dir";
    }
    else
    {
      warn "Directory $dir doesn't exist";
    }
  } elsif (exists $chref->{submit_sample})
  {
    $chref->{sample} =~ /(^.*)\s+\((\d\d-.+) (.+)\)/;
    my $smp_name = $1;
    my $ord_num = $2;
    my $login = $3;
    warn "cref: $chref->{sample} sn: $smp_name on: $ord_num l: $login";
    my ($fclause, $wclause)=read_where_clause("exp_condition","ec_pk", $us_fk);
    my $sql = "select abbrev_name from exp_condition, sample, order_info, $fclause where $wclause and oi_fk=oi_pk and ec_fk = ec_pk and smp_name='$smp_name' and order_number='$ord_num'"; 
  my $sth=$dbh->prepare($sql) || warn "prepare $sql failed $DBI::errstr";
  $sth->execute() || warn "execute $sql failed $DBI::errstr";

    my ($abbrev_name) = $sth->fetchrow_array();
    $new_pwd = "$USER_DATA_DIR/$login/Data_Files/$ord_num";
    $chref->{file_pattern} = "${ord_num}_$abbrev_name";
  } elsif (exists $chref->{submit_analysis})
  {
    my $tree_name;
    my $tree_pk;
    warn "analysis is $chref->{analysis}";
    if ($chref->{analysis} =~ /^\d+$/)
    {
      $tree_name =getq_tree_name_by_tree_pk($dbh, $us_fk, $chref->{analysis});
      $tree_pk = $chref->{analysis};
    }
    else
    {
      $tree_name = $chref->{analysis};
      $tree_pk = getq_tree_pk_by_tree_name($dbh, $us_fk, $tree_name);
    }
    if ($tree_pk)
    {
      my ($owner, undef) = getq_owner_group_by_pk($dbh, $tree_pk);
      my $login = doq($dbh, "get_login", $owner);
      my $dir = "$USER_DATA_DIR/$login/Analysis_Trees/$tree_name";
      if (-d "$dir")
      {
        $new_pwd = $dir;
      }
      else
      {
        GEOSS::Session->set_return_message("errmessage", 
            "ERROR_TREE_NO_OUTPUT", $chref->{analysis});
      }
    }
    else
    {
      GEOSS::Session->set_return_message("errmessage", 
          "ERROR_OBJECT_UNKNOWN", "tree", $chref->{analysis});
    }
  } elsif (exists $chref->{cd_dir_abs})
  {
    $new_pwd = "$chref->{cd_dir_abs}";
  } elsif (exists $chref->{cd_dir})
  {
    if ($chref->{cd_dir} eq "..")
    {
      $chref->{pwd} =~ /(.*)\/(.*)/;
      $new_pwd = $1;
    }
    else
    {
      $new_pwd = "$chref->{pwd}/$chref->{cd_dir}";
    }
  }
  return ($new_pwd);
}

sub get_directory_navigator
{
  my ($dbh, $us_fk, $chref) = @_;
  my $html_string = "";
  my ($login, $fname, $lname, undef) = doq($dbh, "user_info2", $us_fk);

# we need to set:
#  - pwd_display - short name for the directory we are in
#  - pwd_note - extra information on the directory
#      - extra info on login is full user name


# set the display name to be everything after USER_DATA_DIR
  $chref->{pwd} =~ /$USER_DATA_DIR\/(.+)/;
  $chref->{pwd_display} = $1;

# set the note to display the user
  if ($chref->{pwd_display} =~ /([^\/]+)/)
  {
    my $cur_login = $1;
    ($cur_login, $fname, $lname, undef) = doq($dbh, "user_info3", $cur_login);
    $chref->{pwd_note} = "&nbsp;&nbsp(Owner: $fname $lname)";
  }
  if ($chref->{submit_sample})
  {
    $chref->{sample} =~ /(\S*)\s+\((.+) (.+)\)/;
    $chref->{pwd_note} .= " &nbsp;&nbsp; Sample Name: $1)"; 
    $chref->{pwd_note} =~ s/\)//;
  }
  if ($chref->{pwd} =~ /Analysis_Trees\/(.+)/)
  {
    my $tree_name = $1;
# warn "pwd: $chref->{pwd} name : $tree_name";
    my ($tree_pk) = $dbh->selectrow_array("select tree_pk from tree where
        tree_name='$tree_name'"); 
      my $can_view = getq_can_read_x($dbh, $us_fk, "tree", "tree_pk", 
          "tree_pk = $tree_pk");
    $chref->{sample} =~ /(\S*)\s+\((.+) (.+)\)/;
    $chref->{pwd_note} .= qq#&nbsp;&nbsp;Tree: #;
    if ($can_view)
    {
      $chref->{pwd_note} .= qq#<a href="./edit_atree1.cgi?tree_pk=$tree_pk">$tree_name<input type="image" border="0" name="imageField" src="../graphics/pencil.gif" width="25" height="25"></a>#; 
    }
    else
    {
      $chref->{pwd_note} .= "$tree_name";
    }
    $chref->{pwd_note} .= " )";
    $chref->{pwd_note} =~ s/\)//;
  }
  if (($chref->{pwd} ne "$USER_DATA_DIR") &&
      ($chref->{view_tree} ne "tree"))
  {
    my $pwd = CGI::escape($USER_DATA_DIR);
    $chref->{pwd_note2} .= "&nbsp;&nbsp<a href=\"files2.cgi?cd_dir_abs=$pwd&view_tree=$chref->{view_tree}\">Top</a>";
  }

  if ($chref->{view_tree} eq "tree")
  {
    $html_string = get_tree_html($dbh, $us_fk, $chref);
  }
  else
  {
    $html_string = get_treeless_html($dbh, $us_fk, $chref);
  }
  return($html_string);
} # get_directory_navigator

sub get_tree_html
{
  my ($dbh, $us_fk, $chref) = @_;

# determine depth and draw crossbars
  $chref->{pwd} =~ /$USER_DATA_DIR(.*)/;
  my $rel_path = $1;
  my $depth = split(/\//, $rel_path);

  my $html_string = qq!<table width="100%" border="0" cellpadding="0" cellspacing="0">\n!;
  $html_string .= qq!<tr>\n!;
  $html_string .= qq!<td>\n!;
  $html_string .= qq!<table border=0 cellspacing=3 cellpadding=2>\n!;
  $html_string .= qq!<tr>\n!;
  my $ctr;
  for ($ctr = 0; $ctr < $depth; $ctr++)
  {
    $html_string .= qq!<td height=5 valign=top align=center bgcolor=#c9dfae></td>\n!;
  }
  $html_string .= qq!</tr>\n!;

# do a get_dirs on USER_DATA_DIR
  my $urlappend = url_append($chref);
  $html_string .= draw_dirs($dbh, $us_fk, $USER_DATA_DIR, $chref->{pwd}, 0, $depth, $urlappend);

  $html_string .= qq!</table>\n</td>\n</tr>\n</table>!;
} #get_tree_html

sub url_append
{
  my ($chref) = @_;

  my $urlappend = "";
  $urlappend .= "&pwd=" . CGI::escape($chref->{pwd});
  $urlappend .= "&view_tree=" . CGI::escape($chref->{view_tree});
  if ($chref->{file_pattern} ne "")
  {
    $urlappend .= "&file_pattern=" . CGI::escape($chref->{file_pattern});
  }
  
  return $urlappend;
} # url_append

sub draw_dirs
{
  my ($dbh, $us_fk, $cur_path, $pwd, $curdepth, $maxdepth, $urlappend) = @_;
  
  my @dirs = get_dirs($dbh, $us_fk, $cur_path);
  my $html_string;
  my $dir;
  my $ctr = 0;
  foreach $dir (@dirs)
  {
    $ctr++;
    $dir =~ /.*\/(.*)/;
    $html_string .= "<tr>";
    my $x;
    for ($x = 0; $x < $curdepth; $x++)
    {
      $html_string .= "<td>&nbsp;</td>"; 
    }
    if ($pwd eq $dir)
    {
      $html_string .=  qq!<td valign="top" bgcolor="#FFD700">!;
    }
    else
    {
      $html_string .=  qq#<td valign="top">#;
    }
    my $u_a .="cd_dir_abs=" . CGI::escape("$dir") . "$urlappend";
    $html_string .= qq#<img src="../graphics/folder_white.jpg" border="0">&nbsp;<a href="files2.cgi?$u_a">$1</a></td>\n#;
    for ($x = $curdepth+1; $x < $maxdepth; $x++)
    {
      $html_string .= "<td>&nbsp;</td>"; 
    }
    $html_string .= "</tr>\n";
    if ($pwd =~ /^$dir/)
    {
      $html_string .= draw_dirs($dbh, $us_fk, $dir, $pwd, $curdepth+1, $maxdepth,$urlappend);
    }
  }
  return($html_string);  
} #draw_dirs


sub get_treeless_html
{
  my ($dbh, $us_fk, $chref) = @_;
  
  my $urlappend = url_append($chref);
  my @dirs = get_dirs($dbh, $us_fk, $chref->{pwd});
  # add parent directory to list of directories if we 
  # are not in USER_DATA_DIR
  if ($chref->{pwd} ne $USER_DATA_DIR)
  {
    unshift @dirs, "./..";
  }

  # determine how many viewable directories are in the current 
  # directory
  my $num_cols = $#dirs < 4 ? $#dirs : 4;
  
  my $html_string = qq!<table width="100%" border="0" cellpadding="0" cellspacing="0">\n!;
  $html_string .= qq!<tr>\n!;
  $html_string .= qq!<td>\n!;
  $html_string .= qq!<table border=0 cellspacing=3 cellpadding=2>\n!;
  $html_string .= qq!<tr>\n!;
  my $ctr;
  $html_string .= qq!<td height=5 valign=top align=center bgcolor=#c9dfae></td>\n!;
  for ($ctr = 0; $ctr < $num_cols; $ctr++)
  {
    $html_string .= qq!<td valign=top align=center bgcolor=#c9dfae></td>\n!;
  }
  $html_string .= qq!</tr>\n!;

  my $color = "gray";
  my $bg_color = "#efefef";
  $ctr = 0;
  while ($ctr < @dirs)
  {
    $html_string .= qq!<tr bgcolor="$bg_color">\n!;
    my $x;
    for ($x = 0; $x <= $num_cols; $x++)
    {
      $dirs[$ctr] =~ /.*\/(.*)/;
      my $entry_name = $1;
      #warn "dir is $dirs[$ctr] and entry_name is $entry_name";
      if (($dirs[$ctr]) && ($entry_name))
      {
        my $u_a .="cd_dir=" . CGI::escape("$entry_name") . "$urlappend";
        $html_string .=  qq#<td valign="top"><img src="../graphics/folder_${color}.jpg" border="0">&nbsp#;
        $html_string .= qq#<a href="files2.cgi?$u_a">$entry_name</a></td>\n#;
      }
      else
      {
         $html_string .= qq#<td>&nbsp;</td>\n#;
      }
      $ctr++;
    }
    $html_string .= qq!</tr>\n!;
    if ($color eq "gray")
    {
       $color = "white";
    }
    else
    {
       $color = "gray";
    }  
    if ($bg_color eq "#efefef")
    {
       $bg_color = "#ffffff";
    }
    else
    {
       $bg_color = "#efefef";  
    }
  }
  $html_string .= qq!</table>\n</td>\n</tr>\n</table>\n!;
  return ($html_string);
} #get_treeless_html


sub draw_file_view
{
    my ($dbh, $us_fk, $chref, $file_ref) = @_;
    my %ch = %$chref;

    if ($ch{view_tree} eq "tree")
    {
      $ch{view_type} = qq!<input type="submit" name="submit_view_type" value="View Current Directory Only">!;
    }
    else
    {
      $ch{view_type} = qq!<input type="submit" name="submit_view_type" value="View Entire Directory Tree">!;
    }
    $ch{select_file_owner} = select_readable_file_owners($dbh, $us_fk);
    $ch{select_study} = select_study($dbh, $us_fk);
    $ch{select_order} = select_order($dbh, $us_fk);
    $ch{select_sample} = select_sample($dbh, $us_fk);
    $ch{select_analysis} = select_analysis($dbh, $us_fk);
    $ch{htmltitle} = "View my files";
    $ch{help} = set_help_url($dbh, "file_management", "view_my_files");
    $ch{htmldescription} = "Use this page to view and retrieve your GEOSS files.  You can navigate through your directories using the directory buttons or by using the navigation short cuts at the bottom of the page.";
    my ($allhtml,  $loop_template, $tween, $loop_template2, $loop_template3) = 
      readtemplate( "files2.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html");

    my $loop_instance;
    $allhtml =~ s/<loop_here>//;

    # format files
    @$file_ref = sort {$a->{file_name} cmp $b->{file_name} } @$file_ref;
    my $fr;
    foreach $fr (@$file_ref)
    {
      my $loop_instance3 = $loop_template3;
      $fr->{file_name} =~ /.*\/(.*)/;
      $fr->{file_name} = $1;
      $loop_instance3 =~ s/{(.*?)}/$fr->{$1}/g;
      $allhtml =~ s/<loop_here3>/$loop_instance3<loop_here3>/s;
    }
    $ch{none} = "No files available in this directory" if (! scalar(@$file_ref));
    $allhtml =~ s/<loop_here3>//;

    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;

 
    $allhtml = fixselect("select_file_owner", $ch{file_owner}, $allhtml);
    $allhtml = fixselect("select_study", $ch{study}, $allhtml);
    $allhtml = fixselect("select_order", $ch{order}, $allhtml);
    $allhtml = fixselect("select_sample", $ch{sample}, $allhtml);
    $allhtml = fixselect("select_analysis", $ch{analysis}, $allhtml);
    print "Content-type: text/html\n\n$allhtml\n";
}

sub have_file_in_dir
{
  my ($dbh, $us_fk, $dir) = @_;
  my $have_file; 

  my ($fclause, $wclause) = read_where_clause("file_info","fi_pk", $us_fk);
  my $sql = "select count(*) from file_info, $fclause where $wclause and file_name like '$dir%'";
  my $sth=$dbh->prepare($sql) || warn "prepare $sql failed $DBI::errstr";
  $sth->execute() || warn "execute $sql failed $DBI::errstr";

  ($have_file) = $sth->fetchrow_array();
  $sth->finish(); 

  return ($have_file);
}

sub get_dirs
{
  my ($dbh, $us_fk, $pwd) = @_;
  opendir(my $dh, $pwd) or die "unable to open $pwd: $!";
  return 
    sort { $a cmp $b }
    grep { -d $_ && have_file_in_dir($dbh, $us_fk, $_) }
    map { "$pwd/$_" }
    grep { !/^\./ }
    readdir($dh);
}

sub get_files
{
  my ($dbh, $us_fk, $chref) = @_;

  my @all_files = ();

  my @dir_contents = glob($chref->{pwd} . 
                          '/' . 
                          ($chref->{file_pattern} ?
                            "*$chref->{file_pattern}*" :
                            '*'
                          )
                     );
  my $dir_entry;
  foreach $dir_entry (@dir_contents)
  {
    my ($fclause, $wclause) = read_where_clause("file_info","fi_pk", $us_fk);
     my $sql2 = "select fi_pk, file_name, fi_comments, fi_checksum, last_modified, login, gs_owner from file_info, usersec, groupsec, $fclause where $wclause and us_pk = groupref.us_fk and gs_pk = groupref.gs_fk and file_name = '$dir_entry'";
     my $sth2=$dbh->prepare($sql2) || warn "prepare $sql2 failed $DBI::errstr";
     $sth2->execute() || warn "execute $sql2 failed $DBI::errstr";
     my $entryref;
     while ($entryref = $sth2->fetchrow_hashref())
     {
       my @stats = stat($entryref->{file_name});
       $entryref->{size} = $stats[7];
       $entryref->{last_modified} = localtime($stats[9]);
       (undef, $entryref->{gs_owner}) = get_group($dbh, $entryref->{fi_pk});
       $entryref->{href} = index_url($dbh);
       $entryref->{href} .= "/getfile.cgi?filename=" .
                            CGI::escape($entryref->{file_name});
       if (is_writable($dbh, "file_info", "fi_pk", $entryref->{fi_pk}, $us_fk)
         ==1)
       {
         my $urlappend = url_append($chref);
         $entryref->{delete_link} = qq#<a href="delete_file1.cgi?fi_pk=$entryref->{fi_pk}$urlappend"><img src="../graphics/trash.gif" border="0">#;
       }
       else
       {
         $entryref->{delete_link} = qq#<img src="../graphics/no_trash.gif" border="0">#;
        } 
       push @all_files, $entryref; 
     }
  }
  return(\@all_files);
}

sub select_readable_file_owners
{
  my ($dbh, $us_fk) = @_;

  #get the owner information for any group I am in
  my $select_html_front = qq#<select name="file_owner">#;
  my $select_html_end = qq#</select>#;
  my ($login, $fname, $lname, undef) = doq($dbh, "user_info2", $us_fk);
  my $select_me .= qq#<option value="$login" selected>$lname, $fname ($login)</option>#;
  my $select_middle = qq#<option value="All">All</option>#;
  my $sth = getq_readable_file_owners($dbh, $us_fk);
  while (($login, $fname, $lname) = $sth->fetchrow_array())
  {
    $select_middle .= qq#<option value="$login">$lname, $fname ($login)</option>#;
  }
  return ($select_html_front . $select_me . $select_middle . $select_html_end);
}

sub select_sample
{
  my ($dbh, $us_fk) = @_;

  my $select_html_front = qq#<select name="sample">#;
  my $select_html_end = qq#</select>#;
  my $select_me;
  my $select_middle; 

  # lets order these as
  #   - my samples (alphabetical)
  #   - not my samples, but I can read (alphabetical)
  (my $fclause, my $wclause) = read_where_clause("sample", "smp_pk", $us_fk);
  my $sql= "select smp_pk, smp_name, login, order_number from sample, order_info, usersec, $fclause where $wclause and oi_fk = oi_pk and groupref.us_fk = us_pk order by login, order_number, smp_name";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($self_login, $fname, $lname, undef) = doq($dbh, "user_info2", $us_fk);
  while (my ($smp_pk, $smp_name, $login, $ord_num) = $sth->fetchrow_array())
  {
    if (is_some_data_loaded($dbh, $us_fk, "sample", $smp_pk))
    {
      $smp_name = "n/a" if ($smp_name eq "");
      my $smp_str = "$smp_name ($ord_num $login)";
      if ($login eq "$self_login")
      {
        $select_me .= qq#<option value="$smp_str">$smp_str</option>#;
      }
      else
      {
        $select_middle .= qq#<option value="$smp_str">$smp_str</option>#;
      }
    }
  }
  return ($select_html_front . $select_me . $select_middle . $select_html_end);
}

sub select_study
{
  my ($dbh, $us_fk) = @_;

  my $select_html_front = qq#<select name="study">#;
  my $select_html_end = qq#</select>#;
  my $select_me;
  my $select_middle; 

  # lets order these as
  #   - my studies (alphabetical)
  #   - not my studies, but I can read (alphabetical)
  (my $fclause, my $wclause) = read_where_clause("study", "sty_pk", $us_fk);
  my $sql= "select sty_pk, study_name, login from study, usersec, $fclause where $wclause and groupref.us_fk = us_pk order by study_name";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($self_login, $fname, $lname, undef) = doq($dbh, "user_info2", $us_fk);
  while (my ($sty_pk, $study_name, $login) = $sth->fetchrow_array())
  {
    if (is_some_data_loaded($dbh, $us_fk, "study", $sty_pk))
    {
      if ($login eq "$self_login")
      {
        $select_me .= qq#<option value="">$study_name ($login)</option>#;
      }
      else
      {
        $select_middle .= qq#<option value="">$study_name ($login)</option>#;
      }
    }
  }
  return ($select_html_front . $select_me . $select_middle . $select_html_end);
}

sub is_some_data_loaded
{
  my ($dbh, $us_fk, $type, $pk) = @_;
  my $some_loaded = 0;
  my $sql;

  if ($type eq "study")
  {
    $sql = "select is_loaded from arraymeasurement where smp_fk in (select smp_pk from sample where ec_fk in (select ec_pk from exp_condition where sty_fk = $pk))"; 
  }
  else
  {
    $sql = "select is_loaded from arraymeasurement where smp_fk = $pk"; 
  }
  my $sth = $dbh->prepare($sql) || warn "prepare $sql $DBI::errstr";
  $sth->execute() || warn "execute $sql $DBI::errstr";
  
  while (my ($is_loaded) = $sth->fetchrow_array())
  {

    if ($is_loaded == 1)
    {
      $some_loaded = 1;
      last;
    }
  }
  $sth->finish();
  return ($some_loaded);
}

sub select_order
{
  my ($dbh, $us_fk) = @_;

  # get all orders that I can read 
  my ($fclause,$wclause) = read_where_clause("order_info", "oi_pk", $us_fk );
   my $sql = "select order_number,oi_pk, login from order_info, usersec,$fclause where $wclause and groupref.us_fk=us_pk order by order_number desc";
   my $sth = $dbh->prepare($sql);
   $sth->execute();

  my $select_html_front = qq#<select name="order">#;
  my $select_html_end = qq#</select>#;
  my $select_middle;
  while ( my ($order_number, $oi_pk, $login) = $sth->fetchrow_array())
  {
    if (-d "$USER_DATA_DIR/$login/Data_Files/$order_number")
    {
      $select_middle .= qq#<option value="$login/Data_Files/$order_number">$order_number (Owner: $login)</option>#;
    }
  }
  return ($select_html_front . $select_middle . $select_html_end);
}

sub select_analysis
{
  my ($dbh, $us_fk) = @_;

  my $select_html_front = qq#<select name="analysis">#;
  my $select_html_end = qq#</select>#;
  my $select_middle; 
  my $sth = getq("select_tree", $dbh, $us_fk);
  $sth->execute() || die "Query select_tree_nc execute fails.\n$DBI::errstr\n";

  my $login = doq($dbh, "get_login", $us_fk);
  while (my ($tree_name, $tree_pk) = $sth->fetchrow_array())
  {
    # don't include if there are no output files
    if (-d "$USER_DATA_DIR/$login/Analysis_Trees/$tree_name")
    {
      $select_middle .= qq#<option value="$tree_pk">$tree_name</option>#;
    }
  }
  return ($select_html_front . $select_middle . $select_html_end);
}

