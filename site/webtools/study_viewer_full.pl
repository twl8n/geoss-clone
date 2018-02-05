use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "webtools/study_viewer.cgi");
my %ch = $q->Vars();    

if ($ch{create_tree})
{
  if ($ch{an_set_name})
  {
    $ch{an_set_pk} = create_an_set($dbh, $ch{an_set_name}, 
        "",$us_fk, $us_fk);
    insert_studies_into_an_set($ch{an_set_pk}, [ $ch{sty_pk} ], $dbh);
    post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk",
      $ch{an_set_pk}, "edit_an_set.cgi");
  }
  else
  {
    set_session_val($dbh, $us_fk, "message", "errmessage",
        get_message("FIELD_MANDATORY", "Data Set Name"));
  }
}

if (getq_can_read_x($dbh, $us_fk, "study", "sty_pk", "sty_pk = $ch{sty_pk}"))
{

  my $sql = "select sty_pk, study_name,sty_comments, study_url, tree_fk, " 
   . "study_abstract from study where sty_pk = $ch{sty_pk}";

  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my $hr = $sth->fetchrow_hashref();
  $sth->finish();

  # Study Name
  if ($hr->{study_url})
  {
    $hr->{study_name}= "<a href=\"$hr->{study_url}\">$hr->{study_name}</a>";
  }

  # Description
  if ($hr->{study_abstract})
  {
    $hr->{description} = $hr->{study_abstract};
  }
  else
  {
    $hr->{description} = $hr->{sty_comments};
  }

  # Default tree results
  if ($hr->{tree_fk})
  {
    $hr->{tree_link} = "<a href=\"edit_atree1.cgi?tree_pk=$hr->{tree_fk}" 
      . "\">View Analysis Tree</a>";
    $hr->{tree_results_link} = "<a href=\"files2.cgi?analysis=" .
      "$hr->{tree_fk}&submit_analysis=GO\">View Analysis Result Files</a>";
  }

  # Disease Classification
  $hr->{dis_name} =  getq_disease_by_sty_pk_and_opt_dis_pk($dbh, $us_fk, $hr->{sty_pk});
  
  # analysis
  if (is_study_loaded($dbh, $us_fk, $ch{sty_pk}))
  {
    $hr->{analysis_html} = get_analysis_html($hr->{tree_link},
        $hr->{tree_results_link});
  }

sub get_analysis_html
{
  my ($tree_link, $tree_results_link) = @_;
  return <<EOF;
<tr>
  <td colspan=2>
    <b>Analysis:</b>
  </td>
  <td colspan = 2>
     $tree_link
  </td>
</tr>
<tr>
  <td colspan=2>&nbsp;</td>
  <td colspan=2>
    $tree_results_link
  </td>
</tr>
<tr>
  <td>
    Customized Data Set Name:
  </td>
  <td>
    <input type="text" name="an_set_name" value="">
  </td>
  <td colspan=2>
    <input type="submit" name="create_tree"
     value="Create Customized Data Set for Analysis">
  </td>
</tr>
EOF
}

  my ($allhtml, $loop_template, $tween, $loop_template2) =
  readtemplate("study_viewer_full.html", "/site/webtools/header.html",
        "/site/webtools/footer.html");

  my %ch = %{get_all_subs_vals($dbh, $us_fk, $hr)};
  
  my %chip_count;
  my $total_num_chips = 0;
       
  my $sql2 = "select ec_pk, spc_fk, name, description from exp_condition"
    . " where sty_fk = $hr->{sty_pk}";
  my $sth2 = $dbh->prepare($sql2) || die "prepare $sql2\n$DBI::errstr\n";;
  $sth2->execute() || die "execute $sql2\n$DBI::errstr\n";;
  
  my $ec_ref;
  while ($ec_ref =  $sth2->fetchrow_hashref())
  {
    if ($ec_ref->{spc_fk})
    {
      my $sql3 = "select primary_scientific_name from species where spc_pk ="
        . "$ec_ref->{spc_fk}";
      my $sth3 =$dbh->prepare($sql3) || die "prepare $sql3\n$DBI::errstr\n";;
      $sth3->execute() || die "execute $sql3\n$DBI::errstr\n";;
      my ($psn) = $sth3->fetchrow_array();
      $ch{"organism"} .= " $psn " if ($ch{"organism"} !~ / $psn /);
    }

    my $loop_instance = $loop_template;

    my $sql4 = "select hybridization_name, description as
      hybridization_description, name as chip  from arraymeasurement,
      arraylayout, sample where smp_fk=smp_pk and al_fk=al_pk 
        and ec_fk = $ec_ref->{ec_pk}";
    my $sth4 =$dbh->prepare($sql4) || die "prepare $sql4\n$DBI::errstr\n";;
    $sth4->execute() || die "execute $sql4\n$DBI::errstr\n";;
    my $am_ref;
    while ($am_ref = $sth4->fetchrow_hashref())
    {
      my $loop_instance2 = $loop_template2;
      $loop_instance2 =~ s/{(.*?)}/$am_ref->{$1}/g;
      $loop_instance =~ s/<loop_here2>/$loop_instance2<loop_here2>/s;
    }
    $loop_instance =~ s/<loop_here2>//;
    $loop_instance =~ s/{(.*?)}/$ec_ref->{$1}/g;
    $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
  }
  $allhtml =~ s/<loop_here>//;

  $ch{htmltitle} = "View Array Study";
  $ch{help} = set_help_url($dbh, "view_array_study");
  $ch{htmldescription} = "";

  $allhtml =~ s/{(.*?)}/$ch{$1}/g;

  print $q->header;
  print "$allhtml\n";
  print $q->end_html;

  $dbh->disconnect;
}
