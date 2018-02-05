package main;
use strict;

my %tree;      # the analysis tree as read in from the db
my %parent;    # key is node, value is node's parent
my %children;  # key is node, value is a list of children nodes
my %node2g;    # key is node, value is a generation
my @generation;# key is generation, value is a list of nodes in this generation
my %loc;       # key is node, value is a list of row,col
my @table;     # 2D array, indices are [row][col], values are nodes
my @colors;    # 2D array, indices are [row][col], values are HTML colors
my @m_width;   # 1D array, index is node, value is max width of all subsequent generations

sub insert_tree
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $tree_name = $_[2];
  my $fi_input_fk = $_[3];
  my $an_pk = $_[4];

  my $t_suffix = 0;
  my $sth = getq("insert_tree", $dbh);
  $sth->execute($tree_name, $fi_input_fk);

  my $tree_pk = insert_security($dbh, $us_fk, $us_fk, 0);

  $sth = getq("insert_tree_node", $dbh);
  $sth->execute($tree_pk,-1,$an_pk); # the tree pk, no parent, default analysis
  my $node_pk = insert_security($dbh, $us_fk, $us_fk, 0);

  init_node($dbh, $node_pk, $an_pk);

  $dbh->commit;
  return ($tree_pk, $node_pk);
}

#
# Build an HTML select tag based on a query from the tree table.
#
sub select_tree
{
  my ($dbh, $us_fk) = @_;

  my $sth = getq("select_tree", $dbh, $us_fk);
  $sth->execute();
  my $do_select = 0; # do the radion button version instead
  if ($do_select == 1)
  {
     my $st_html = "<select name=\"tree_pk\">\n";
     while((my $name, my $tree_pk) = $sth->fetchrow_array())
     {
       $st_html .= "<option value=\"$tree_pk\">$name</option>\n";
     }
     $st_html .= "</select>\n";
     $sth->finish();
     return $st_html;
  }
  else
  {
    my $st_html = "";
    my $checked = "checked";
    while((my $name, my $tree_pk) = $sth->fetchrow_array())
    {
      $st_html .= "<input type=\"radio\" name=\"tree_pk\" " .
        "value=\"$tree_pk\" $checked> $name<br>\n";
      $checked = ""; # only set checked on the first one
    }
    $sth->finish();
    return $st_html;
  }
}

sub select_node
{
  my ($dbh, $us_fk, $activenode) = @_;

  my $an_pk_active;
  if ($activenode)
  {
    my $sth = getq("get_an_fk_for_node", $dbh);
    $sth->execute($activenode);
    $an_pk_active = $sth->fetchrow_array();
  }

  my $sth = getq("select_analysis", $dbh);
  $sth->execute();

  # we need to figure out what are the current versions of the 
  # analyses so we can put them in the select box first.
  # We'll store all elements in the current hash, until we find
  # a more current version.  Then we'll move that element into
  # the old hash.

  my %anacurr;
  my %anaold;
  my $hr;
  while($hr = $sth->fetchrow_hashref())
  {
    my $anaelem = { "name" => "$hr->{an_name}",
    	"type" => "$hr->{an_type}",
    	"version" => "$hr->{version}", 
    	"an_pk" => "$hr->{an_pk}",
    };
    if ($hr->{current} == 0)
    {
       #obsolete analyses must be in old hash
       my $key = $anaelem->{type} . "_" . $anaelem->{version};
        $anaold{$key} = $anaelem;
    }
    elsif (exists($anacurr{$hr->{an_type}}))
    {
      my $currelem = $anacurr{$hr->{an_type}};
      if ($currelem->{"version"} > $anaelem->{"version"})
      {
        # if the ana we have just retrieve has a lower version 
        # than current, put the value in old
        my $key = $anaelem->{type} . "_" . $anaelem->{version};
        $anaold{$key} = $anaelem;
      }  
      else
      {
        # if the ana we have just retrieved has a higher
        # version than current, put the value in current in old
        # put the node in current
        my $key = $currelem->{type} . "_" . $currelem->{version};
        $anaold{$key} = $currelem;
        $anacurr{$hr->{an_type}} = $anaelem;
      }
    }
    else
    {
      $anacurr{$hr->{an_type}} = $anaelem;
    }
  }
  $sth->finish();

  # we want to present all current elements in alphabetical order,
  # followed by all old elements in alphabetical order
  my @sorted_cur = sort anasort values(%anacurr);

  my $elem;

  # additionally we only want to present nodes that are valid children
  # nodes for this analysis - we only do this if we have an active node

  my @final = @sorted_cur;
  if ($an_pk_active > 0)
  {
    @final = ();
    my $anaref = get_valid_child_nodes($dbh, $an_pk_active);
    foreach $elem (@sorted_cur)
    {
      my $an_pk = $elem->{"an_pk"};
      foreach my $temp (@$anaref)
      {
        if ($temp->[0] eq "$an_pk")
        {
          push @final, $elem;
        }
      }
    }
  }

  # construct select box
  my $select_str = "<select name=\"select_node\">\n";
  foreach $elem (@final)
  {
    $select_str .= "<option value=\"$elem->{an_pk}\">$elem->{name}" .
     " #$elem->{version}</option>\n";
  }
  $select_str .= "</select>\n";
  return $select_str;
}

# used by select_node to sort analysis elements by name
# $a and $b are hashes with a name element
sub anasort
{
  if ($a->{'name'} gt $b->{'name'})
    { return 1; }
  elsif ($a->{'name'} lt $b->{'name'})
    {return -1; } else { return 0 }
}

#
# find max width for each family.
# $m_width[$xx] = max; where $node is the index into @tree.
#
sub pass1
{
  my $row;
  my $col;
  my %zero_children;

  $row = 0;
  $col = 0;
  for(my $xx=$#generation; $xx>=0; $xx--)
  {
    my $yy;
    for ($yy = 0; $yy<=$#{$generation[$xx]}; $yy++)
    {
      my $node = $generation[$xx][$yy];
      $m_width[$node] = 0;
      my $cc;
      for($cc=0; $cc<=$#{$children{$node}}; $cc++)
      {
        my $chw = ($m_width[$children{$node}[$cc]]);
        $m_width[$node] += $chw;
      }
      if ($m_width[$node] < 1)
      {
        $m_width[$node] = 1; 
      }
    }
  }
}


# Place parent at 1/2 of the child's generation width
# Need a pass to group children of a generation by family.
# If a node has no children, then it doesn't count in the spacing of 
# the next generation, and its col is just col+1.
# If a node has children, then place the node in the middle of the subsequent generation,
# 
sub pass2
{
  my $row;
  my $col;

  $row = 0;
  $col = 0;
  my $node;
  my $parent;
  # Layout children of generation $xx, and special case the root.
  # Need to layout children of parent nodes so siblings are together.
  $col += int(($m_width[$tree{root}]/2));
  $table[$row][$col] = $tree{root};
  # Also put node's location into the %loc hash
  @{$loc{$tree{root}}} = ($row, $col); 
  $row+=2;
  my $offset;
  my $cumu_pos;
  my $siblings;
  for(my $xx=0; $xx<=$#generation; $xx++)
  {
    $col = 0;
    for(my $yy=0; $yy<=$#{$table[$row-2]}; $yy++)
    {
      #
      # Layout children in the order of the parents generation is layed out.
      # We always want to build a generation from the left, 
      # and just using @generation
      # won't meet that requirement.
      #
      if (defined($table[$row-2][$yy])) 
      {
        $parent = $table[$row-2][$yy];
      }
      else
      {
        next;
      }
      #
      # There might be a space saving optimization here
      # by checking row-2,col-1, and if nothing is there
      # then decrement $col.
      # 
      for(my $cc=0; $cc<=$#{$children{$parent}}; $cc++)
      {
        $node = $children{$parent}[$cc];
        $offset = int(($loc{$parent}[1] - ($m_width[$parent]/2)) 
            + ($m_width[$node]/2));
        $cumu_pos = $col + int((($m_width[$node])/2));
        if ($cumu_pos < $offset)
        {
          $col = $offset;
        }
        else
        {
          $col = $cumu_pos
        }
        $table[$row][$col] = $node;
        # Also put node's location into the %loc hash
        @{$loc{$node}} = ($row, $col);          
        # Better to add the fraction on the right. 
        $col += int((($m_width[$node])/2)+0.5); 
      }
    }
    $row+=2;
  }
}

sub render_at
{
  my $selected_node_pk = shift;
  my $ro = shift;
    
  pass1();    # creates @table, @loc
  pass2();    # modifies @table, @loc fixing mis-aligned zeroth row nodes
  tile_color();             # reads @table, creates @colors
  tile_connect();           # modifies @table adding img tags, reads @loc
  my $html = render_html($selected_node_pk, $ro); # reads @table, @colors
  return $html;
}

#
# Call this anytime you insert a new node, or
# when you update a node and change the nodes's an_fk.
# 
sub init_node
{
  my $dbh = $_[0];
  my $node_pk = $_[1];
  my $add_an_fk = $_[2];

  my $sth_insert = getq("insert_upv", $dbh);

  use GEOSS::Analysis;
  my $analysis = GEOSS::Analysis->new(pk => $add_an_fk);
  use GEOSS::Analysis::Node;
  my $node = GEOSS::Analysis::Node->new(pk => $node_pk);
  my @conds = $node->tree->input->cond_labels_list;

  foreach my $upn ($analysis->user_parameter_names) {
    my $v = $upn->default;
    if($upn->type eq 'file') {
      $v =~ /(.*)\.(.{3})/
        and $v = "$1_${node_pk}_$2";
    }
    elsif($upn->type eq 'condsSelect') {
      $v = qq("$conds[0]","$conds[1]");
    }
    elsif($upn->type =~ /^condsRadio/ || $upn->type eq 'condsText') {
      $v = join('', map { "$_,," . $v . ",," } @conds);
    }

    $sth_insert->execute($node_pk, $v, $upn->pk);
  }
}

sub delete_tree
{
  my ($dbh, $tree_pk, $us_fk) = @_;

  # tree can't be delete if it is referenced by a study, so remove that
  # reference first
  $dbh->do("update study set tree_fk = NULL where tree_fk = $tree_pk");

  my %tree = read_db($dbh, $tree_pk, $us_fk);

  my $sth = getq("get_tree_root_node", $dbh, $us_fk);
  $sth->execute($tree{tree_pk});
  my $gtrn_rows = $sth->rows();
  if ($gtrn_rows != 1)
  {
    write_log("get_tree_root_node returns $gtrn_rows rows instead of " .
        "one row for $tree{tree_pk}");
    die "Query get_tree_root_node returns wrong number of records: ". 
     " $gtrn_rows for $tree{tree_pk}\n";
  }
  (my $root_node_pk, my $tree_name) = $sth->fetchrow_array();
  $sth->finish();
  if ($root_node_pk != $tree{root})
  {
    write_log("root nodes don't match: $root_node_pk $tree{root}");
    die "root nodes don't match: $root_node_pk $tree{root}\n";
  }
  $tree{delete_node_pk} = $root_node_pk; # delete all nodes!
  # delete input file
  my  $fi_pk =  doq($dbh, "get_tree_fi_input_fk", $tree_pk);

  delete_node($dbh, \%tree);
  $sth = getq("delete_tree", $dbh);
  $sth->execute($tree{tree_pk});

  # delete tree files from file_info
  my $login = doq($dbh, "get_login", $us_fk);
  my $treepath = $USER_DATA_DIR . "/" . $login . "/Analysis_Trees/" . 
    $tree_name . "/";
  $dbh->do("delete from file_info where file_name like '$treepath%'"); 

  # delete tree files from directory structure
  my $rc = `rm -rf $treepath`;
  print "Return: $? - $!" if ($?);
}

sub delete_node
{
  my $dbh = $_[0];
  my %tree = %{$_[1]};

  my @nstack;
  push(@nstack, $tree{delete_node_pk});
  #
  # delete the extra hash element created as a delete carrier
  #
  delete($tree{delete_node_pk}); 
    
  # Pop the next node to delete off the stack.
  # Delete the record, delete the upv and spv records.
  # Then go through the entire tree looking for nodes that have the current
  # stack node ($s_node) as their parent, and push them onto the stack.
  # $tree{$node}[1] is the parent of $node.
  # Eventually, all nodes in @nstack will be deleted.
  #
  my $sth = getq("delete_tree_node", $dbh);
  my $ds_sth = getq("delete_spv", $dbh);
  my $du_sth = getq("delete_upv", $dbh);
  while($#nstack >= 0)
  {
    my $s_node = pop(@nstack);
    $ds_sth->execute($s_node);
    $du_sth->execute($s_node);
    $sth->execute($s_node);
    delete_security($dbh, $s_node);
    delete($tree{$s_node}); # delete the element
    foreach my $node (keys(%tree))
    {
      if ($node !~ m/^\d+$/)
      {
        next; # only do numeric nodes. $tree{"root"}, $tree{delete}, etc.
      }
      if ($tree{$node}[1] == $s_node)
      {
        push(@nstack, $node);
      }
    }
  }
  return %tree;
}

sub update_tree_name {
  my $dbh = shift;
  my $us_fk = shift;
  my $tree_pk = shift;
  my $from = shift;
  my $to = shift;

  my $login = doq_get_login($dbh, $us_fk);
  my $old_dir = "$USER_DATA_DIR/$login/Analysis_Trees/$from";
  my $new_dir = "$USER_DATA_DIR/$login/Analysis_Trees/$to";

  my $sth = getq_files_like($dbh, $us_fk);
  $sth->execute("$old_dir/%");
  while(my ($fi_pk, $file_name) = $sth->fetchrow_array) {
    substr($file_name, 0, length($old_dir), $new_dir);
    $dbh->do('update file_info set file_name=' . $dbh->quote($file_name)
             . " where fi_pk=$fi_pk");
  }

  getq("update_tree_name", $dbh)->execute($to, $tree_pk);
  if (-e $old_dir)
  {
    rename($old_dir, $new_dir)
      or die "unable to rename $old_dir to $new_dir: $!";
  };
  eval { $dbh->commit };
  if($@) {
    rename($new_dir, $old_dir)
      or die "rollback of directory rename failed; tree is now in "
             . " inconsistent state; ($old_dir -> $new_dir)";
    die $@;
  }
}

#
# local copy of %tree since this one comes from the web page?
#
sub write_db
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my %tree = %{$_[2]};
  my $q = $_[3];
  my $sth;
  my $msg;

  my %dbtree = read_db($dbh, $tree{tree_pk}, $us_fk);
  if($dbtree{tree_name} ne $tree{tree_name}) {
    my $err = check_tree_name($dbh, $us_fk, $tree{tree_name});
    if($err) {
      set_session_val($dbh, $us_fk, 'message', 'errmessage',
          get_message($err));
    }
    else {
      # we use a new db connection, since update_tree_name has to commit
      # in an attempt to make the move as atomic as possible (it also
      # moves the files in the filesystem)
      update_tree_name(new_connection(), $us_fk, $tree{tree_pk}, 
                       $dbtree{tree_name}, $tree{tree_name});
    }
  }

  # $tree{properties_node_pk} better exist!
  if (exists($tree{properties_node_pk}))
  {
    $sth = getq("update_upv", $dbh);

    # checkboxes
    # We need to handle checkboxes.  The browser only sets them if they
    # are checked.  Therefore, changes to unchecked aren't written.
    # To handle this, we set all checkboxes to 0.  If they are 1, they 
    # will be updated.

    # get all checkboxes for this node
    my $sth2 = getq("get_checkboxes", $dbh);
    $sth2->execute($tree{properties_node_pk});
 
    # set to zero
    my $check_upv_pk;
    while (($check_upv_pk) = $sth2->fetchrow_array()) 
    {
      $sth->execute(0, $check_upv_pk);
    }

    #
    # It is crude but simple to crawl through all the keys
    # looking for upv_pk_nnn
    # 
    my %conds_values;
    foreach my $key (keys(%tree))
    {
      if ($key =~ m/upv_pk_(\d+)_?(.+)?/)
      {
        # if this is a filename, we want to write an extension
        my $val = $tree{$key};
        my $upv_pk = $1;
        my $upv_cond = $2;
 
        my ($up_name, $type, $an_fk, $node_fk) = $dbh->selectrow_array(
            "select up_name, up_type, an_fk, node_fk from " . 
            "user_parameter_names, user_parameter_values where " .
            "upv_pk = $upv_pk and upn_fk=upn_pk");
        
        # if we update a field that triggers and extension on a file name,
        # we need to update the name of that file.  For instance, if we
        # update graphFormat, we need to change the filename of 
        # --settings outgph
    
        my ($arg_name) = $dbh->selectrow_array(
            "select arg_name from extension, filetypes, " .
            "analysis_filetypes_link, analysis, node where " . 
            "node.an_fk = an_pk and extension.ft_fk = ft_pk and " . 
            "analysis_filetypes_link.ft_fk = ft_pk and " .
            "analysis_filetypes_link.an_fk = an_pk and " .
            "extension = '$up_name' and node_pk = $node_fk");
        if (defined $arg_name)
        {
          my ($alt_upn_pk, $old_file_name) = $dbh->selectrow_array(
              "select upv_pk, up_value from user_parameter_values," .
              " user_parameter_names where upn_fk = upn_pk and " .
              " up_name='$arg_name' and node_fk = $node_fk");
          $old_file_name =~ /(.*)\./;
          my $new_file_name = $1 . "." . $val;
          
          # update the parameter that is triggered by change
          $sth->execute($new_file_name, $alt_upn_pk);
        }

        if ($type eq "file")
        {
          # we need to handle the extension
          if ($val !~ /\./)
          {
            # there is no extension so lets add our own
    	      # we get the extension from the extension table
    	      # we get the extension value associated with
    	      # filetype.  If the extension values starts
    	      # with --, then the extension should be the
    	      # value of the parameter specified in extension
    	      # for this node (yuck!) Intended to handle outgph.
    	
            my ($ext) = $dbh->selectrow_array("select extension from " .
                "analysis_filetypes_link, filetypes, extension where " .
                "extension.ft_fk = ft_pk and analysis_filetypes_link.ft_fk " .
                "= ft_pk and an_fk = '$an_fk' and arg_name = '$up_name'");
            
            if ($ext =~ /^--/)
            {
              ($ext) = $dbh->selectrow_array(
                        "select up_value from " .
                        "user_parameter_values, user_parameter_names where upn_fk = " .
                        "upn_pk and node_fk = '$node_fk' and up_name = '$ext'");
            }
            $val .= "."  . $ext;
          }
        }
        
        elsif ($type eq "condsText" || $type =~  /^condsRadio/)
        {
          # we should get several of these values
          # we need to keep them all in an ordered string to commit to
          # the db
          $val = $conds_values{$upv_pk} .= "$upv_cond,,$val,,";
        }
        
        elsif ($type eq "fileUpload")
        {
          next unless $val;
          # if this node currently has an assigned file,
          # delete the file and remove it from file_info
          my ($up_value, $file_name) = $dbh->selectrow_array(
              "select up_value, file_name" 
              . " from user_parameter_values, file_info"
              . " where up_value = fi_pk and upv_pk = $upv_pk");
          if ($up_value)
          {
            if($val eq 'on') {
              unlink $file_name || warn "Unable to rm $file_name: $!"; 
              $dbh->do("delete from file_info where fi_pk = $up_value");
            }
            $val = '';
          }
          else {
            my $login = doq($dbh, "get_login", $us_fk);
            my $new_file_name = $dbh->selectrow_array(
                "select up_display_name"
                . " from user_parameter_values, user_parameter_names"
                . " where upn_pk = upn_fk and upv_pk = $upv_pk");
            $new_file_name = canonicalFilename($new_file_name) . '.txt';
            my $full_file_name = "$USER_DATA_DIR/$login/Analysis_Trees/" .
              "$tree{tree_name}/$new_file_name"; 
            my $tree_pk = getq_tree_pk_by_tree_name($dbh, $us_fk, $tree{tree_name}); 
            my ($owner_pk, $group_pk) = getq_owner_group_by_pk($dbh, $tree_pk); 
            # this upload the file, inserts it into file_info, and sets
            # the val to the fi_pk
            my $upfh = $q->param("upv_pk_$upv_pk");
          
            #preserve the upload filename to display to the user
            my $comments = $q->param("upv_pk_$upv_pk");
            $val = write_upload_file($dbh, $us_fk, $upfh, $owner_pk, $group_pk,
                $full_file_name, "$comments", '', '', undef, 0, undef, 
                288, undef);
          }
        }

        elsif ($type eq "condsSelect")
        {
          # we have a set of values.  We need to 
          # put them in a comma separated list.
          # i.e. abc becomes "a","b","c"
            
          my (@vals) = split(/\0/, $val);
          $val = join(',', map { qq("$_") } @vals);
        }
        
        $sth->execute($val, $upv_pk);
      }
    }
  }

  if (exists($tree{add_an_fk}))
  {
    # insert node
    $sth = getq("insert_tree_node", $dbh);
    # my tree's tree_pk, my parent's node_pk, analysis an_pk
    $sth->execute($tree{tree_pk},  $tree{add_parent}, $tree{add_an_fk}); 
    my $node_pk = insert_security($dbh, $us_fk, $us_fk, 0);
    init_node($dbh, $node_pk, $tree{add_an_fk},);
  }
  elsif (exists($tree{delete_node_pk}))
  {
    # delete node
    if ($tree{delete}[1] == $tree{root})
    {
      $msg = get_message("CANT_DELETE_ROOT_NODE");
      set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
      return $msg ; # don't allow deletion of the root of the tree;
    }
    delete_node($dbh,\%tree);
  }
  return $msg;
}

sub read_db
{
  my ($dbh, $tree_pk, $us_fk)  = @_;

  my $sth = getq("read_tree", $dbh, $us_fk);
  $sth->execute($tree_pk);
  while(( my $tree_name, my $node_pk, my $an_name, my $parent_key, my $an_fk,
          my $version, my $an_type) = $sth->fetchrow_array())
  {
    push(@{$tree{$node_pk}}, "${an_name}<br><br>Version: $version");   # [0]
    push(@{$tree{$node_pk}}, $parent_key);# [1]
    push(@{$tree{$node_pk}}, $an_fk);     # [2]
    push(@{$tree{$node_pk}}, $tree_pk);   # [3]
    push(@{$tree{$node_pk}}, "${an_type}_$version");   # [4]
       
    if ($parent_key == -1)
    {
      $tree{root} = $node_pk;
      $tree{tree_name} = $tree_name;
      $parent{$node_pk} = -1; # we can only have one parent
      $node2g{$node_pk} = 0;  # my generation zero
      # add self to my generation's list
      push(@{$generation[$node2g{$node_pk}]}, $node_pk); 
    }
    else
    {
      $parent{$node_pk} = $parent_key;
      push(@{$children{$parent_key}}, $node_pk);
      # nodes must be processed in order
      $node2g{$node_pk} = $node2g{$parent{$node_pk}} + 1; 
      push(@{$generation[$node2g{$node_pk}]}, $node_pk);  # ditto
    }
  }

  #  $tree{properties_node_pk} = $ch{properties_node_pk};
  $tree{tree_pk} = $tree_pk;

  # I know... %tree is a package global, and we're returning it.
  return %tree;
}

sub tile_color
{
  my @choices = ("#FFCCFF", "#FFCCCC", "#CCFFFF", "#CCFFCC", "#CCCCFF");
  my $gc = 0;          # generation counter;
  my $prev_parent = -1; # parent of the previous table entry
  for(my $xx = 0; $xx<=$#table; $xx++)
  {
    for(my $yy = 0; $yy<=$#{$table[$xx]}; $yy++)
    {
      if (defined($table[$xx][$yy]))
      {
        # special case for the root
        if (($parent{$table[$xx][$yy]} != $prev_parent) || 
            ($table[$xx][$yy] == 0))
        {
        # print "p: $parent{$table[$xx][$yy]} pp: $prev_parent\n";
          $gc++;
          $prev_parent = $parent{$table[$xx][$yy]};
        }
        $colors[$xx][$yy] = $choices[$gc%5];
        # print "$xx, $yy: " . $gc%5 . " $colors[$xx][$yy]\n";
      }
    }
    # $gc++ # increment every time we change a row, 
    # since the generation changes as well.
  }
}

sub render_html
{
  my $selected_node_pk = shift;
  my $ro = shift;
  my $node_select;
  # @table is a global
    
  my $html;
  my $tmax = 0;
  for(my $xx=0; $xx<=$#table; $xx++)
  {
    if ($#{$table[$xx]} > $tmax)
    {
      $tmax = $#{$table[$xx]};
    }
  }
  my $at_width = 75 * $tmax;
  my $outer_width = $at_width+300;
  $html .= "<table width=\"$at_width\" border=\"0\" cellpadding=\"0\" " .
    " cellspacing=\"4\">";
  for(my $xx=0; $xx<=$#table; $xx++)
  {
    # make sure the row is 75 pixels tall.
    $html .= "\n<tr><td><img src=\"../graphics/white.gif\" width=\"5\" " .
       " height=\"75\"></td>\n";
    for(my $yy=0; $yy<=$tmax; $yy++)
    {
      # write_log("$xx,$yy:$table[$xx][$yy]");
      if (defined($table[$xx][$yy]))
      {
        my $node = $table[$xx][$yy];
        if ($node =~ m/img/)
        {
          $html .= "<td width=\"75\">$node</td>\n";
        }
        else
        {
          my $color;
          my $pre_cell = "";
          my $post_cell = "";
          $node_select = "";
          if ($node == $selected_node_pk)
          {
            $color = "#FFD700";
            $pre_cell .= "<table width=\"100%\" border=\"3\" " .
              "bgcolor=\"$color\"><tr><td> ";
            $post_cell="</td></tr></table>"; 
          }
          else
          {
            $color =  "#CCFFCC";
          }
          #
          # If any of these hidden fields change, then corresponding 
          # changes have to be made
          # to edit_atree1.cgi and edit_atree2.cgi
          #
          $html .= "<td width=\"75\" border=\"0\" bgcolor=\"$color\"> " .
            "$pre_cell";
          $html .= "<input type=\"hidden\" name=\"name_$node\" " .
            "value=\"$tree{$node}[0]\"> <input type=\"hidden\" " .
            "name=\"parent_$node\" value=\"$parent{$node}\">";
          my $del_string = "";
          if ($node != $tree{root} && !$ro) 
          {
    	      $del_string ="<input type=\"image\" border=\"0\" ".
              " name=\"delete_$node\" src=\"../graphics/trash.gif\" " .
              "width=\"25\" height=\"25\">\n";
          }
          $tree{$node}[4] =~ /(.*)_\d+$/;
          my $kindroot = $1;
          $html .= "<table border=\"0\" width=\"100%\"><tr><td " .
            "width=\"50%\"><div align=\"left\">$del_string</div></td><td " .
            " width\"50%\"><div align=\"right\"><input type=\"image\" " .
            "border=\"0\" name=\"edit_$node\" src=\"../graphics/pencil.gif\"".
            " width=\"25\" height=\"25\"></div></td></tr></table>\n";
          $html .= "<div align=\"center\"><font size=\"-1\"><a " .
            "href=\"../doc.cgi?file=$WEB_DIR/site/webtools/analysis/" .
            "$kindroot/$tree{$node}[4].html&tree_pk=$tree{tree_pk}\">" .
            "$tree{$node}[0]</a>\n";
          $html .= "</font></div>$post_cell</td>\n";
        }
      }
      else
      {
        $html .= "<td width=\"75\">&nbsp;</td>\n";
      }
    }
    $html .= "</tr>\n";
  }
  $html .= "</table>\n";
  return $html;
}

sub tile_connect
{
  # @table is a global
  my $tmax = 0;
  my $px;
  my $py;
  for(my $xx=0; $xx<=$#table; $xx++)
  {
    if ($#{$table[$xx]} > $tmax)
    {
      $tmax = $#{$table[$xx]};
    }
  }
  for(my $xx=0; $xx<=$#table; $xx++)
  {
    for(my $yy=0; $yy<=$tmax; $yy++)
    {
      if ($table[$xx][$yy] > $tree{root})
      {
        my $parent = $parent{$table[$xx][$yy]};
        $px = $loc{$parent}[0];
        $py = $loc{$parent}[1];
        # print "$xx, $yy $table[$xx][$yy] parent: $px $py\n";
        if ($py == $yy)
        {
          $table[$xx-1][$yy] = "<img src=\"../graphics/15a.gif\">";
        }
        elsif ($py <= ($yy-1))
        {
          if ($py < ($yy-1))
          {
    	      $table[$xx-2][$yy-1] = "<img src=\"../graphics/74.gif\">";
    	      for(my $pp=2; $py < $yy-$pp; $pp++)
    	      {
    	    # if it already contains an img 74.gif then replace with 7374.gif
    	        if ($table[$xx-2][$yy-$pp] =~ m/74\.gif/)
    	        {
    		        $table[$xx-2][$yy-$pp] = "<img src=\"../graphics/7374.gif\">";
    	        }
    	        else
    	        {
    		        $table[$xx-2][$yy-$pp] = "<img src=\"../graphics/73.gif\">";
    	        }
    	      }
          }
          $table[$xx-1][$yy] = "<img src=\"../graphics/05a.gif\">";
        }
        elsif ($py >= ($yy+1))
        {
          if ($py > ($yy+1))
          {
    	      if ($table[$xx-2][$yy+1] =~ m/img/)
    	      {
    	        $table[$xx-2][$yy+1] = "<img src=\"../graphics/7336.gif\">";
    	      }
    	      else
    	      {
    	        $table[$xx-2][$yy+1] = "<img src=\"../graphics/36.gif\">";
    	      }
    	      for(my $pp=2; $py > $yy+$pp; $pp++)
    	      {
    	        # if we already have image 36.gif then replace with 7336.gif
    	        if ($table[$xx-2][$yy+$pp] =~ m/36\.gif/)
    	        {
    		        $table[$xx-2][$yy+$pp] = "<img src=\"../graphics/7336.gif\">";
    	        }
    	        else
    	        {
    		        $table[$xx-2][$yy+$pp] = "<img src=\"../graphics/73.gif\">";
    	        }
    	      }
          }
          $table[$xx-1][$yy] = "<img src=\"../graphics/25a.gif\">";
        }
      }
    }
  }
}

# This function will determine which analysis nodes are valid 
# nodes to connect with the input node.  It does this by getting
# the filetype name for the --outfile parameter of the analysis.
# It then finds all analyses with that type of parameter as 
# acceptable input.  
#
# Input: The an_pk of the analysis we want to find valid next nodes for.
# Output: A reference to an array of valid next node an_pks.

sub get_valid_child_nodes
{
  my ($dbh, $an_pk) = @_;
  my $sth = getq("get_ft_name_for_specified_an_pk", $dbh);
  $sth->execute($an_pk);
  my ($ft_name) = $sth->fetchrow_array();

  $sth = getq("get_an_fks_for_specfied_ft_name", $dbh);
  $sth->execute($ft_name);
     
  return ($sth->fetchall_arrayref); 
}

sub print_tree_info
{
  foreach my $node (keys(%parent))
  {
    if ($node == $tree{root})
    {
      print "\"$tree{$node}[0]\" is the root. ";
    }
    else
    {
      print "\"$tree{$node}[0]\"'s parent is \"$tree{$parent{$node}}[0]\". ";
    }
    my $num_children = $#{$children{$node}}+1;
    if ($num_children > 0)
    {
      if ($num_children == 1)
      {
        print "$num_children child. ";
      }
      else
      {
        print "$num_children children. ";
      }
      foreach my $child (@{$children{$node}})
      {
        print "\"$tree{$child}[0]\" ";
      }
    }
    else
    {
      print "No children. ";
    }
    print "\n";
  }
  print "\n";
}

sub print_children_info
{
  # for(my $xx=0; $xx<=$#children; $xx++)
  foreach my $node (keys(%children))
  {
    if ($#{$children{$node}} >= 0)
    {
      print "Children $node: ";
      for(my $yy=0; $yy<=$#{$children{$node}}; $yy++)
      {
        print "($node,$yy) $children{$node}[$yy] ";
      }
      print "\n";
    }
  }
  print "\n";
}

sub print_generation_info
{
  for(my $xx=0; $xx<=$#generation; $xx++)
  {
    print "Generation $xx: ";
    for(my $yy=0; $yy<=$#{$generation[$xx]}; $yy++)
    {
      print "($xx,$yy) $generation[$xx][$yy] ";
    }
    print "\n";
  }
  print "\n";
}

sub print_ascii_tree
{
  print "pre a:$table[0][0]\n";
  print "   0 1 2 3 4 5 6 7 8 91011121314151617181920\n";
  for(my $xx=$#table; $xx>=0; $xx--)
  {
    if ($xx > 9) { print "$xx";}
    else { print "$xx "; }
    for(my $yy=0; $yy<=$#{$table[$xx]}; $yy++)
    {
      if ($table[$xx][$yy] < 10) { print " ";}
      # print "$xx,$yy:$table[$xx][$yy]\n";
      if (defined($table[$xx][$yy]))
      {
        if ($table[$xx][$yy] =~ m/img/)
        {
          print "i";
        }
        else
        {
          print "$table[$xx][$yy]";
        }
      }
      else
      {
        print " ";
      }
    }
    print "\n";
  }
}

sub input_select
{
  my ($dbh, $us_fk, $tree_pk) = @_;
  my $prefix = "$USER_DATA_DIR/"; # yes, it has the trailing /

  my $results = "<select name=\"fi_input_fk\">\n";
  my $sth = getq("get_input_files", $dbh, $us_fk);
  $sth->execute() || die "execute get_input_files\n$DBI::errstr\n";
  my $current_fi_input_fk = doq($dbh, "current_fi_input_fk", $tree_pk) 
    if (defined $tree_pk);
  my %fhash;
  #
  # Add a \t after final / so that file names sort by
  # directory and then file.
  #
  while((my $fi_pk, my $file_name) = $sth->fetchrow_array())
  {
    $file_name =~ s/$prefix(.*)/$1/;
    $file_name =~ s/(.*)\//$1\/\t/;
    $fhash{"$file_name"} = $fi_pk;
  }
  foreach my $key (sort( {uc($a)  cmp  uc($b)} keys(%fhash)))
  {
    my $file_name = $key;
    $file_name =~ s/\t//; # remove the \t we put in above.
    my $fi_pk = $fhash{$key};
    (my $temp1,
     my $temp2,
     my $contact_name,
     my $temp3) = doq($dbh, "who_owns", $fi_pk);
    my $selected = "";
    if ((defined $current_fi_input_fk) && ($fi_pk == $current_fi_input_fk))
    {
      $selected = " selected ";
    }
    $results .= "<option value=\"$fi_pk\" $selected>$contact_name: $file_name</option>\n";
  }
  $results .= "</select>\n";
  return $results;
}

1;
