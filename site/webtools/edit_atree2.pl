use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $q = new CGI;
  my %ch = $q->Vars();
  my $msg;
  my $dbh = new_connection();
  my $us_fk = get_us_fk($dbh, "webtools/choose_tree.cgi");
  
  $ch{node_pk} = $ch{properties_node_pk} if (exists($ch{properties_node_pk}));
  my %tree = read_tree($q);
  write_db($dbh, $us_fk, \%tree, $q);
  
  my $url = index_url($dbh); # see session_lib

  if ($ch{run})
  {
    if (error_check_tree($dbh, $us_fk, \%ch, \%tree))
    {
      redraw_tree($dbh, $us_fk, \%ch, \%tree, $url);
    }
    else
    {
      # we need to do this before the disconnect
      $ch{htmltitle} = "Run Analysis Tree";
      $ch{help} = set_help_url($dbh, "edit_or_delete_or_run_an_existing_analysis_tree");
      $ch{submit_analysis} = 1;
      my $allhtml = get_allhtml($dbh, $us_fk, "edit_atree2.html", 
        "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
      %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
      $allhtml =~ s/{(.*?)}/$ch{$1}/g;
      $dbh->commit();
      $dbh->disconnect();
      my $pid = fork();
      if ($pid != 0) # we have the non-zero pid, we must be the parent
      {
        $ch{htmltitle} = "Analysis Run Status";
        $ch{htmldescription} = "";
        print "Content-type: text/html\n\n$allhtml";
        exit();
      }
      else
      {
        #
        # Child needs to have its own output streams.
        #
        open(STDOUT, '>', 
	       "$USER_DATA_DIR/$ENV{REMOTE_USER}/child_error.txt") ||
	       die "Can't redirect stdout $USER_DATA_DIR/" . 
	       "$ENV{REMOTE_USER}/child_error.txt";
        if (exists($ch{node_pk}))
        {
          my $temp = `./runtree.cgi --tree $ch{tree_pk} --node $ch{node_pk}`;
        } else
        {
          my $temp = `./runtree.cgi --tree $ch{tree_pk}`;
        }
        exit();
      }
    }
  }
  elsif ($ch{upgrade} eq "Upgrade Tree")
  {
    my $tree=GEOSS::Analysis::Tree->new(pk => $tree{tree_pk});
    my $up = $tree->upgrade;
    if ($up)
    {
      set_return_message($dbh, $us_fk, "message", "goodmessage", 
          "TREE_SUCCESS", "upgraded");
    }
    else
    {
      $dbh->rollback();
      set_return_message($dbh, $us_fk, "message", "errmessage", 
          "UNABLE_TO_UPGRADE_TREE");
    }
    redraw_tree($dbh, $us_fk, \%ch, \%tree, $url);
  }
  elsif ($ch{copy} eq "Copy Tree")
  {
    my $tree=GEOSS::Analysis::Tree->new(pk => $tree{tree_pk});
    if (GEOSS::Analysis::Tree->new(name => $tree->name . "_copy"))
    {
      set_return_message($dbh, $us_fk, "message", "errmessage", 
          "UNABLE_TO_COPY_TREE", $tree->name . 
          "_copy already exists");
      redraw_tree($dbh, $us_fk, \%ch, \%tree, $url);
      exit;
    }
    my $copy; my $up;
    eval {
      $copy = $tree->copy(name => $tree->name . "_copy", )
    };
    if ($@)
    {
      warn "copy failure $@ with $!";
      $dbh->rollback();
      set_return_message($dbh, $us_fk, "message", "errmessage", 
          "UNABLE_TO_COPY_TREE", 
          "Please contact the administrator for assistance.");
      redraw_tree($dbh, $us_fk, \%ch, \%tree, $url);
    }
    else
    {
      eval {
        $up = $copy->upgrade;
      };
      if ($@)
      {
        warn "upgrade failure $@ with $!";
        $dbh->rollback();
        set_return_message($dbh, $us_fk, "message", "errmessage", 
            "UNABLE_TO_UPGRADE_TREE");
      }
      else
      {
        set_return_message($dbh, $us_fk, "message", "goodmessage", 
            "TREE_SUCCESS", "copied");
        print "Location: edit_atree1.cgi?tree_pk=" . $up->pk . "\n\n";
      }
    }
  }
  else
  {
    redraw_tree($dbh, $us_fk, \%ch, \%tree, $url);
  }
  $dbh->commit();
  $dbh->disconnect();
}

sub error_check_tree
{
  my ($dbh, $us_fk, $chref, $treeref) = @_;
  my $error_found = 0;
  
  my $tree = GEOSS::Analysis::Tree->new(pk => $treeref->{tree_pk});
  if ($tree->status eq "OBSOLETE")
  {
    $error_found = 1;
    set_return_message($dbh, $us_fk, "message", "errormessage",
     "CANT_RUN_OBSOLETE_TREE");
  }
  my $sth = getq("select_upv_files", $dbh);
  $sth->execute($chref->{tree_pk});
  my $hr;
  my %filename;
  my $errstr;
  while ($hr = $sth->fetchrow_hashref())
  {
    if (exists $filename{$hr->{up_value}})
    {
      $error_found = 1;
      $errstr = "Duplicate file names configured - " . 
       "$filename{$hr->{up_value}} conflicts with ". 
       " $hr->{an_name} ($hr->{node_pk}) $hr->{up_display_name}";
      set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("ERROR_TREE_CONFIG", $errstr));
    }
    else
    {
      $filename{$hr->{up_value}} = "$hr->{an_name} ($hr->{node_pk}) $hr->{up_display_name}";
    }
  }
  return $error_found;
}

sub redraw_tree
{
  my ($dbh, $us_fk, $chref, $treeref, $url) = @_;
  
  $url .="/edit_atree1.cgi";
  #
  # A deleted node will also be the active node. It can't be active
  # after it has been deleted, so drop through to the else.
  #
  if ($treeref->{active_node} && ! exists($treeref->{delete_node_pk}))
  {
    print "Location: $url?tree_pk=$chref->{tree_pk}&node_pk=$treeref->{active_node}\n\n";
  }
  else
  {
    print "Location: $url?tree_pk=$chref->{tree_pk}\n\n";
  }
}

sub read_tree
{
  my $q = $_[0];
  my %ch = $q->Vars();
  my %tree;

  foreach my $key (keys(%ch))
  {
    
    #
    # Capture name_nnn fields where nnn is an integer starting with zero
    # These are not sparse: zero through nnn max should exist.
    #
    if ($key =~ m/name_(\d+)$/) # force full match!
    {
      #write_log("$key: $1\n");
      $tree{$1}[0] = $ch{$key};
      $tree{$1}[1] = $ch{"parent_$1"};
    }
    #
    # Capture upv_pk's and values for fields we will update
    # see properties_node_pk below.
    # These are sparse. There will only be a few fields, and the 
    # pk's could be any integer.
    # 
    if ($key =~ m/upv_pk_\d+/) # force full match!
    {
      $tree{$key} = $ch{$key};
      #write_log("k: $key t:$tree{$key} c:$ch{$key}");
    }
  }
  my $active_node;
  if (exists($ch{node_pk}))
  {
    $active_node = $ch{node_pk};
  }
  foreach my $key (keys(%ch))
  {
    # input type=image sends .x and .y because (apparently) I didn't ask for an image map.
    # Just use the .x
    
    if ($key =~ m/properties_node_pk/)
    {
      $active_node = $ch{$key};
    }
    if ($key =~ m/edit_(\d+)\.x/)
    {
      $active_node = $1;
      last;
    }
    if ($key =~ m/delete_(\d+)\.x/)
    {
      $active_node = $1;
      last;
    }
  }
  if (exists($ch{add}))
  {
    $tree{add_an_fk} = $ch{select_node};
    $tree{add_parent} = $active_node; 
  }
  if (exists($ch{change}))
  {
    $tree{update_node_pk} = $active_node;
    $tree{update_an_fk} = $ch{select_node};
  }
  elsif(exists($ch{"delete_$active_node\.x"}))
  {
    # input type=image sends .x and .y because (apparently) I didn't ask for an image map.
    # Just use the .x
    # The node_pk radio button has to be clicked to set $active_node
    $tree{delete_node_pk} = $active_node;
  }
  $tree{active_node} = $active_node;
  $tree{fi_input_fk} = $ch{fi_input_fk};
  $tree{properties_node_pk} = $ch{properties_node_pk};
  $tree{tree_pk} = $ch{tree_pk};
  $tree{root} = $ch{root};
  $tree{tree_name} = $ch{tree_name};
  # 
  # 2003-03-28 Tom
  # Tree names must be no whitespace and only alnum chars
  #
  $tree{tree_name} =~ s/[^A-Za-z0-9_-]/_/g;
  return %tree;
}


