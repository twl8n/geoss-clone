use strict;
use CGI;
use GEOSS::Analysis::Tree;

require "$LIB_DIR/geoss_session_lib";

main:
{
  my $q = new CGI;
  my $tree_pk = $q->param("tree_pk");
  my %ch = $q->Vars();
  my $dbh = new_connection();
  my $us_fk = get_us_fk($dbh, "webtools/choose_tree.cgi");

  foreach my $key(keys(%ch))
  {
    if ($key =~ m/edit_(\d+)\.x/)
    {
      $ch{node_pk} = $1;
    }
  }

  my %tree = read_db($dbh, $tree_pk, $us_fk);

  my $condition = "tree_pk = $tree_pk";
  if (! getq_can_write_x($dbh, $us_fk, "tree", "tree_pk", $condition))
  {
    warn "Can't write tree";
    if (getq_can_read_x($dbh, $us_fk, "tree", "tree_pk", $condition))
    {
      $ch{readonly} = 1; 
    }
    else
    {
      set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
      my $url = index_url($dbh, "webtools"); # see session_lib
        print "Location: $url\n\n";
      exit();
    }
  }

  if (! exists($ch{node_pk}))
  {
    $ch{node_pk} = $tree{root};
  }


#
# Most analysis tree subroutines are in lib/geoss_analysis_tree_lib.pl.
# - Render the tree (an html table?)
# - Create the drop down list with available analyses (supposedly correct
# contextually based on the currently selected node).
# - Create table with user params displayed nice.
# - Create the select drop down menu for appropriate input files.
#
  my $atree = render_at($ch{node_pk}, $ch{readonly});
  my $select_node = select_node($dbh, $us_fk, $ch{node_pk});
  $ch{add_node_html} = set_add_node_html($select_node) 
    if (($select_node =~ /option/) &&
        (! $ch{readonly}));

  my $properties = build_properties($ch{node_pk}, $ch{readonly}); 

  if ($ch{readonly})
  {
    $ch{htmltitle} = "View Analysis Tree";
    $ch{htmldescription} = "Use this page to view analysis tree settings."
      . "  To view parameters for a specific node, click on the pencil " .
      " graphic associated with the node";
  }
  else
  {
    $ch{htmltitle} = "Edit Analysis Tree";
    $ch{help} = set_help_url($dbh, "edit_or_delete_or_run_an_existing_analysis_tree");
    $ch{htmldescription} = "Click the pencil graphic of the node you wish to select.  You may then delete the selected node, modify the selected node's parameters, add a child node from the selected node, or run the tree from that node downward. Scroll down for detailed instructions.";
  }
  $ch{tree_pk} = $tree_pk;
  $ch{tree_name} = $tree{tree_name};
  $ch{root} = $tree{root};
  $ch{atree} = $atree;
  $ch{properties} = $properties;
  my $tree = GEOSS::Analysis::Tree->new(pk => $tree_pk);
  $ch{status} = $tree->status;
  if ($ch{status} eq "OBSOLETE")
  {
    $ch{action} = '<td>
      <input type="submit" name="upgrade" value="Upgrade Tree">
      </td>
      <td>
      <input type="submit" name="copy" value="Copy Tree">
      </td>';
    set_return_message($dbh, $us_fk, "message", "warnmessage",
        "TREE_OBSOLETE");
  }
  else
  {
    $ch{action} = '<td>&nbsp;</td>
      <td><input type="submit" name="run" value="Run Analysis"></td>';
  }
  my ($owner, undef) = getq_owner_group_by_pk($dbh, $ch{tree_pk});
  my $login = doq($dbh, "get_login", $owner);
  my $dir = "$USER_DATA_DIR/$login/Analysis_Trees/$ch{tree_name}";

  # if possible, link to the input file
  my $filename = $tree->input->name;
  if (-e $filename)
  {
    $ch{view_input} = qq#<a href="getfile.cgi?filename=$filename">
      View input file (# . basename($filename) . qq#)</a>#;
  }
  if (-d $dir)
  {
    $ch{view_results} = qq#<a
      href="files2.cgi?analysis=$ch{tree_pk}&submit_analysis=1">
      View tree results</a>#;
  }
  else
  {
    $ch{view_results} = "&nbsp";
  }
  my $infile = "edit_atree1.html";
  $infile = "view_atree1.html" if ($ch{readonly});
  my $all_html = get_allhtml($dbh,
      $us_fk,
      $infile,
      "/site/webtools/header.html",
      "/site/webtools/footer.html",
      \%ch);
  $all_html = fixradiocheck("node_pk",
      $ch{node_pk},
      "radio",
      $all_html);
  print "Content-type: text/html\n\n$all_html";

  $dbh->disconnect();
}

sub set_add_node_html
{
  my ($select_html) = @_;
  return <<EOF;
  <table width="100%">
    <tr>
    <td bgcolor="#00CC99"><div align="center">Add a node </div></td>
    </tr>
    </table>
    <table border="0" cellpadding="5" cellspacing="0">
    <tr>
    <td colspan=2>(1) Select parent node by clicking on the pencil</td>
    </tr>
    <tr>
    <td>(2) Choose:</td>
    <td>$select_html</td>
    </tr>
    <tr>
    <td>(3) Add:</td>
    <td><input type=submit name="add" value="Add Node"></td>
    </tr>
    </table>
EOF
}

#
# Create a table with all the user parameters correctly
# labeled and filled with with current values.
#
sub build_properties
{
  my $node_pk = shift;
  my $readonly = shift;
  my $results;

  use GEOSS::Analysis::Node;
  my $node = GEOSS::Analysis::Node->new(pk => $node_pk);
  my $analysis = $node->analysis;

  my @upn= $analysis->user_parameter_names();
  $results =
    qq(<input type="hidden" name="properties_node_pk" value="$node_pk">\n);
  $results .= qq(<table border="0" cellpadding="0" cellspacing="0">\n);
  $results .= qq{<td>(@{[$analysis->name]} - Node # $node_pk)</td>\n};
  $results .= qq(<td>\n);
  if (($readonly) || (! @upn))
  {
    $results .= "&nbsp";
  }
  else
  {
    $results .= 
      qq( <input type="reset" name="reset" value="Reset Values">\n);
  }
  $results .= qq(<br><br>\n)
    . qq(</td>\n);

  if (@upn)
  {
    foreach my $upn (@upn) {
      my $upv = GEOSS::Analysis::UserParameterValue->new(
          name => $upn->pk, node => $node->pk);
      $results .= build_property($upn, $upv, $node);
    }
  }
  else
  {
    $results .= '<tr><td colspan=2>
                   <b>This analysis has no user parameters.</b>
                 </td></tr>';
  }
  $results .= qq(</table>\n);
}

sub property_header_short {
  my $upn = shift;
  return qq(<tr>\n)
    . qq(<td valign="top">\n)
    . CGI::escapeHTML($upn->display_name) . ($upn->optional ? '' : ' *') . "\n"
    . qq(</td>\n)
    . qq(<td valign="top">\n);
}

sub property_footer_short {
  return "</td>\n</tr>\n";
}

sub property_header_long {
  my $upn = shift;
  return row_spacer()
    . qq(<tr>\n)
    . qq(<td valign="top" colspan="2">\n)
    . qq(<b>) . CGI::escapeHTML($upn->display_name) . qq(</b>) 
    . ($upn->optional ? '' : ' *') . "\n"
    . qq(</td>\n)
    . qq(</tr>\n);
}

sub property_element {
  my $label = CGI::escapeHTML(shift);
  my $value = shift;
  return qq(<tr>\n)
    . qq(  <td valign="top">$label</td>\n)
    . qq(  <td valign="top">$value</td>\n)
    . qq(</tr>\n);
}

sub property_element_long {
  my $value = shift;
  return qq(<tr>\n)
    . qq(  <td valign="top" colspan=2>$value</td>\n)
    . qq(</tr>\n);
}

sub property_footer_long {
  return row_spacer();
}

sub row_spacer {
  return qq(<tr><td valign="top" colspan=2>&nbsp;</td></tr>\n);
}

sub remove_extension {
  my $s = shift;
  return $s =~ /(.*)\.(.*)/ ? $1 : $s;
}

sub build_property {
  my $upn = shift;
  my $upv = shift;
  my $node = shift;
  my $results;

  if ($upn->type eq "textarea") {
    $results = property_header_short($upn);
    $results .= CGI::textarea(-name => 'upv_pk_' . $upv->pk,
        -default => $upv->value,
        -rows => 1,
        -cols => 30);
    $results .= property_footer_short($upn);
  }

  elsif ($upn->type =~ /text(Long)?/) {
    my $long = $1;
    my $field = CGI::textfield(-name => 'upv_pk_' . $upv->pk,
        -value => $upv->value);
    if($long) {
      $results = property_header_long($upn)
        . property_element_long($field)
        . property_footer_long($upn);
    }
    else {
      $results = property_header_short($upn)
        . $field . "\n"
        . property_footer_short($upn);
    }
  }

  elsif ($upn->type eq 'file') {
    $results = property_header_short($upn);
    $results .= CGI::textfield(-name => 'upv_pk_' . $upv->pk,
        -value => remove_extension($upv->value));
    $results .= property_footer_short($upn);
  }

  elsif ($upn->type =~ /^radio(Short)? *\*(.*)/) {
    my $short = $1;
    my @options = map {
      /^"(.*)"(.*)/ ? { label => $1, value => $2} :
        !/^"/         ? { label => $_, value => $_} :
        die "Bad data format in edit_atree1: $_"
    } split(/\*/, $2);

    my @buttons = CGI::radio_group(
        -name => 'upv_pk_' . $upv->pk,
        -values => [map { $_->{value} } @options],
        -labels => {$short ?
        map { $_->{value} => $_->{label} } @options :
        map { $_->{value} => '' } @options
        }, 
        -default => $upv->value);

    if($short) {
      $results = property_header_short($upn)
        . join('<br>', @buttons)
        . property_footer_short($upn);
    }
    else {
      $results = property_header_long($upn);
      foreach my $i (0 .. $#options) {
        $results .= property_element($options[$i]->{label}, $buttons[$i]);
      }
      $results .= property_footer_long($upn);
    }
  }

  elsif ($upn->type eq 'checkbox') {
    $results = property_header_short($upn);
    $results .= CGI::checkbox(-name => 'upv_pk_' . $upv->pk,
        -value => 1,
        -checked => $upv->value,
        -label => '');
    $results .= property_footer_short($upn);
  }

  elsif ($upn->type eq 'heading') {
    $results = row_spacer()
      . "<tr>\n"
      . '<td valign="top" colspan=2><b>' . $upn->display_name . "</b></td>\n"
      . "</tr>\n";
  }

  elsif ($upn->type eq 'fileUpload') {
    use GEOSS::Fileinfo;

    $results .= property_header_long($upn);
    $results .= "<tr>\n"
      . '  <td colspan=2 valign="top">' 
      . ($upv->value ?
          ('File (taken from ' 
                  . GEOSS::Fileinfo->new(pk => $upv->value)->comments
                  . ') uploaded'
          ) :
          'No file currently uploaded'
        )
      . "</td>\n"
      . "</tr>\n";
    $results .= "<tr>\n"
      . '  <td colspan=2 valign="top">'
      . ($upv->value ?
          CGI::checkbox(-name=> 'upv_pk_' . $upv->pk,
            -label => 'Delete uploaded file') :
          CGI::filefield(-name => 'upv_pk_' . $upv->pk, -size => 12)
        )
      . "</td>\n"
      . "</tr>\n";
    $results .= property_footer_long($upn);
  }

  elsif ($upn->type eq 'condsText') {
# condsText is a special kind of text selection 
# it needs to allows the user to enter text for each condition in 
# the input file
#
# data looks like "a,,1,,b,,2,,c,,3,,"
    my %values = split /,,/, $upv->value;

    $results = property_header_long($upn);
    foreach my $cond ($node->tree->input->cond_labels_list) {
      $results .= property_element(
          $cond, 
          CGI::textfield(-name => 'upv_pk_' . $upv->pk . '_' . $cond,
            -value => $values{$cond})
          );
    }
    $results .= property_footer_long($upn);
  }

  elsif ($upn->type eq 'condsSelect') {
# condsSelect is a special kind of multiple select box
# it needs to allow the user to select from the conditions assoc.
# with the input file

    $results = property_header_short($upn);
    $results .= CGI::scrolling_list(
        -name => 'upv_pk_' . $upv->pk,
        -values => [$node->tree->input->cond_labels_list],
        -default => [map { tr/"//d; $_ } split /,/, $upv->value],
        -multiple => 'true');
    $results .= property_footer_short($upn);
  }

  elsif ($upn->type =~ /^condsRadio *\*(.*)/) {
    my @options = map {
      /^"(.*)"(.*)/ ? { label => $1, value => $2} :
        !/^"/         ? { label => $_, value => $_} :
        die "Bad data format in edit_atree1: $_"
    } split(/\*/, $1);
    my %values = split /,,/, $upv->value;

    $results = property_header_long($upn);
    foreach my $cond ($node->tree->input->cond_labels_list) {
      $results .= property_element(
          $cond, 
          join('&nbsp;',
            CGI::radio_group(
              -name => 'upv_pk_' . $upv->pk . '_' . $cond,
              -values => [map { $_->{value} } @options],
              -labels => {map { $_->{value} => $_->{label} } @options}, 
              -default => ($values{$cond} ? $values{$cond} : $upn->default)
              )
            )
          );
    }
    $results .= property_footer_long($upn);
  }

  else {
    die 'unrecognized type ' . $upn->type . ' for ' . $upn->name;
  }

  return $results;
}
