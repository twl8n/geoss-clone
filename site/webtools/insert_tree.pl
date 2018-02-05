use strict;
use CGI;
use GEOSS::Database;
use GEOSS::Fileinfo;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
my $us_fk = get_us_fk($dbh, "webtools/insert_tree.cgi");
my %ch = $q->Vars();
$ch{source_form_type} = "radio";
my $login = doq($dbh, "get_login", $us_fk);
my $directory = "$USER_DATA_DIR/$login/Analysis_Trees/";
my ($al_fk, $am, $conds, $cond_labels, $hybs_str);
my $fork;
if (! -e "$directory")
{
  umask(0002);
  mkdir("$directory", 0770) || warn "Unable to create $login/Analysis_Trees$!";
}
$ch{html_page} = "insert_tree.html";
my $fi_pk;

## Check if request to edit an_set and redirect
check_redirect($dbh, $us_fk, \%ch);

# if the selection was 'Choose Source', then refresh the 
# source component and redraw
# if there was no selection, redraw
# if the selection was 'Next', then create the file and 
# insert the tree
my $error = 0; 
if ($ch{submit} eq "Next")
{
  my $badname = check_tree_name($dbh, $us_fk, "$ch{tree_name}");
  if ($badname)
  {
    $error = 1;
    set_session_val($dbh, $us_fk, "message", "errmessage", 
      get_message($badname));
  }
  else
  {
    # create the file
    my $tname = $ch{tree_name};
    $tname =~ s/ /_/g;
    my $treepath = $directory . "/$tname";
    if (! -e $treepath)
    {
      mkdir($treepath, 0770) || die "Unable to create $treepath:$!\n";
    }
    $ch{file_name} = $directory . "$tname/$tname" . ".txt";

    ## Check if file exists on system 
    if (-e $ch{file_name}) 
    {
      $error = 1;
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("ERROR_FILE_EXISTS"));
    }
 
    if (! $ch{source})
    {
      $error = 1;
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("DATA_SOURCE_MANDATORY"));
    }

    ## Functions for when source == an_file
    if ($ch{source} eq "an_file")
    {
      if ($ch{fi_pk} ne "")
      {
        # modify they file to read only as it is input for a tree
        $fi_pk = $ch{fi_pk};
        set_perms($dbh, $ch{fi_pk}, 288);
        my $file_name = doq($dbh, "get_file_name", $fi_pk);
        `ln $file_name $ch{file_name}`;      
        if ($?)
        {
          warn "Failed to link $file_name $ch{file_name}: $? $!\n";
          set_session_val($dbh, $us_fk, "message",
            "errmessage", get_message("ERROR_CREATE_LINK"));
          $error = 1;
        }
      }
      else
      {
         $error = 1;
         $ch{message} = get_message("DATA_SOURCE_MANDATORY");
      }
    }
    ## Functions for when source == public
    if ($ch{source} eq "public")
    {
      if ($ch{miame_pk} ne "")
      {
        #link the file from the public directory to this user's
        my ($ana_fk_fi, $file_name, $conds, $cond_labels, $al_fk) =
          getq_miame_ana_fi_info($dbh, $us_fk, $ch{miame_pk});

        `ln $file_name $ch{file_name}`;      
        if ($?)
        {
          warn "Failed to link $file_name $ch{file_name}: $? $!\n";
          set_session_val($dbh, $us_fk, "message",
            "errmessage", get_message("ERROR_CREATE_LINK"));
          $error = 1;
        }

        # TODO - check for return error code

        $fi_pk = fi_update($dbh, $us_fk, $us_fk,
                          $ch{file_name},
                          $ch{fi_comments},
                          $conds,
                          $cond_labels,
                          undef,
                          1,
                          undef,
                          432,
                          $al_fk);
     }
     else
     {
        $error = 1;
        $ch{message} = get_message("DATA_SOURCE_MANDATORY");
     }
   } # source = public

   ## Functions for when source == an_set
   if ($ch{source} eq "an_set")
   {
      ##create analysis_hash(key=an_cond_pk; element=array of ams), write file
      if ($ch{an_set_pk} ne "")
      {
        ($al_fk, $am, $conds, $cond_labels, $hybs_str) = 
          get_conf($dbh, $ch{an_set_pk}, "an_set"); 
        open (OUT, "> $ch{file_name}") 
          || die "Unable to open $ch{file_name}: $!";
        print OUT "probe_set_name\t$hybs_str\n"; 
        close(OUT);
        chmod(0660, $ch{filename});
        $fi_pk = fi_update($dbh, $us_fk, $us_fk, $ch{file_name},
          "Analysis Input File", $conds, $cond_labels, 
           undef, 0, undef, 288, $al_fk);
        $fork = 1; 
      } 
      else
      {
        $error = 1;
        $ch{message} = get_message("DATA_SOURCE_MANDATORY");
      }
    } # source = an_set

    ## Functions for when source == study
    if ($ch{source} eq "study")
    {
      if ($ch{sty_pk} ne "")
      {
        ($al_fk, $am, $conds, $cond_labels, $hybs_str) = 
          get_conf($dbh, $ch{sty_pk}, "study"); 
        open (OUT, "> $ch{file_name}") 
          || die "Unable to open $ch{file_name}: $!";
        print OUT "probe_set_name\t$hybs_str\n"; 
        close(OUT);
        chmod(0660, $ch{filename});
        $fi_pk = fi_update($dbh, $us_fk, $us_fk, $ch{file_name},
          "Analysis Input File", $conds, $cond_labels, 
           undef, 0, undef, 288, $al_fk);
        $fork = 1; 
      } 
      else
      {
        $error = 1;
        $ch{message} = get_message("DATA_SOURCE_MANDATORY");
      }
    } # source = study
  }

  if ($error==0)
  {
    my $tree_pk;
    my $node_pk;
    # we have successfully created the file -- let's create the tree
    if ($ch{structure} eq "one")
    {
      # currently qualityControl is the only acceptable first node
      my $sql = "select an_pk from analysis where an_name='Quality Control' 
        and version = (select max(version) from analysis where an_name =
        'Quality Control')";
      my $sth = $dbh->prepare($sql) || 
        die "get_default_nodes $sql\n$DBI::errstr\n";

      $sth->execute() || die "insert_tree execute $sql\n$DBI::errstr\n";
      ($ch{select_node}) = $sth->fetchrow_array();

      ($tree_pk, $node_pk) = insert_tree($dbh, $us_fk, $ch{tree_name}, 
         $fi_pk, $ch{select_node});
    }
    else
    {
      $tree_pk = create_default_an_tree($dbh, $us_fk, \%ch, $fi_pk);
    }
    $dbh->commit;
    $dbh->disconnect;
    if ($fork)
    {
      my $pid = fork();
      if ($pid == 0)
      {
        close(STDOUT);
        $dbh = GEOSS::Database::new_connection();
        create_analysis_file($dbh, $al_fk, $am, $ch{file_name});
        update_file_entry($dbh, $fi_pk);
        $dbh->commit();
        $dbh->disconnect();
        exit();
      }
    }
    my $url = index_url($dbh);
    $url .="/edit_atree1.cgi?tree_pk=$tree_pk";
    print "Location: $url\n\n";
    exit (0);
  }  # error == 0
} # submit = next
    
## Check user selected radio source in GUI
%ch = radio_source(\%ch);

if ($ch{source} eq "study")
{
  $ch{source_html} = get_study_html(\%ch, $dbh, $us_fk);
} elsif ($ch{source} eq "an_set")
{
  $ch{source_html} = get_an_set_html($dbh, $us_fk, \%ch);
} elsif ($ch{source} eq "public")
{
  $ch{source_html} = get_public_html($dbh, $us_fk, \%ch);
} elsif ($ch{source} eq "an_file")
{
  $ch{source_html} = get_an_file_html($dbh, $us_fk, \%ch);
}

# default action - take on first access to page, if there is an error
# trying to create the file, or after Choose Source has been processed
draw_insert_tree($dbh,$us_fk, \%ch);

$dbh->disconnect();
exit();



sub get_conf
{
  my ($dbh, $pk, $type) = @_;
  my $sql; 
  $sql = "select an_cond_name as name, al_fk, hybridization_name, " . 
    " am_pk from" .
    " an_cond, an_cond_am_link, an_set_cond_link, arraymeasurement " .
    " where am_fk=am_pk and an_cond_am_link.an_cond_fk=an_cond_pk and " .
    " an_set_cond_link.an_cond_fk = an_cond_pk and " .
    " an_set_fk = $pk order by name" if ($type eq "an_set");
  $sql = "select name, al_fk, hybridization_name, am_pk from" .
    " exp_condition, sample, arraymeasurement where ec_fk=ec_pk " .
    " and smp_fk=smp_pk and sty_fk = $pk order by name" if ($type eq "study");
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my $hr = $sth->fetchrow_hashref();
  $hr->{name} =~ s/(^\s+)|(\s+$)//g;
  my $al_fk = $hr->{al_fk};
  my @cond_labels =  ($hr->{name});
  my $cur_cond = $hr->{name};
  my @am_pks;
  push @am_pks, $hr->{am_pk};
  my $hybs_str = "$hr->{hybridization_name}\t";
  my $conds = "";
  my $cond_ctr = 1; 

  while ($hr = $sth->fetchrow_hashref())
  {
    $hr->{name} =~ s/(^\s+)|(\s+$)//g;
    if ($al_fk ne $hr->{al_fk})
    {
      GEOSS::Session->set_return_message("errmessage",
         "ERROR_LAYOUT_MISMATCH");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }
    if ($cur_cond ne $hr->{name})
    {
      $cur_cond = $hr->{name};
      push @cond_labels, $cur_cond;
      $conds .= "$cond_ctr" . ",";
      $cond_ctr = 0;
    }
    $cond_ctr++;
    push @am_pks, $hr->{am_pk};
    $hybs_str .= "$hr->{hybridization_name}\t";
  }
  $conds .= "$cond_ctr";
  chop($hybs_str); 
  my $cond_labels = join ",", map { qq!"$_"! } @cond_labels;
  return($al_fk, \@am_pks, $conds, $cond_labels, $hybs_str);
}

sub create_analysis_file
{
  my ($dbh, $al_fk, $am_pks, $filename) = @_;
  
  open (OUT, ">> $filename") || die "Unable to open $filename: $!";
  my %all_data;
  my $sth = getq("get_spot_identifier", $dbh);
  $sth->execute($am_pks->[0]);
  while((my $als_pk, my $spot_identifier, my $usf_name) =
         $sth->fetchrow_array())
  {
      $all_data{$als_pk} = "$spot_identifier | $usf_name";
  }
  $sth = getq("get_signal", $dbh);
  foreach my $am_pk (@$am_pks)
  {
     next if (!$am_pk);
     $sth->execute($am_pk);      
     while((my $als_fk, my $signal) =
     $sth->fetchrow_array())
     {
       $all_data{$als_fk} .= "\t$signal";
     }
  }
  foreach my $spot_identifier (keys(%all_data))
  {
    print OUT "$all_data{$spot_identifier}\n";
  }

  close(OUT);
}

sub update_file_entry
{
  my ($dbh, $fi_pk) = @_;
  $dbh->do("update file_info set use_as_input='1'::bool where fi_pk=$fi_pk");
}

