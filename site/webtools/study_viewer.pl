use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my %ch = $q->Vars(); 

my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "webtools/study_viewer.cgi");

$ch{htmltitle} = "View all array studies";
$ch{help} = set_help_url($dbh, "view_all_array_studies");
$ch{htmldescription} = "To sort data based on a column of data, click on the
column header.  To search data, click on the checkbox for the column(s) you
wish to search and specify search parameters.";
$ch{formaction} = "study_viewer.cgi";
my $allhtml = make_report($dbh, $us_fk, \%ch, \&define_study_report_columns,
    \&get_study_report_data);

print $q->header . "$allhtml\n" . $q->end_html;
$dbh->disconnect;

    
sub define_study_report_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = (
     {
       "name" => "search",
       "button" => qq!<input type="submit" name="search" value="Search">!,
     }, 
     {
       "display_name" => "Study Name",
       "column_type" => "linked_string",
       "name" => "study_name",
       "searchable" => 1, 
       "search_input" => qq!<input type="text" size=12 name="val_study_name" value="{val_study_name}">!,
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Organism",
       "column_type" => "string",
       "name" => "organism",
       "searchable" => 1,
       "search_input" => select_species($dbh, "val_organism"),
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Chip Type",
       "column_type" => "string",
       "name" => "chip_type",
       "searchable" => 1,
       "search_input" => build_al_select($dbh, "val_chip_type"), 
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "Disease Classification",
       "column_type" => "string",
       "name" => "disease_classification",
       "searchable" => 1,
       "search_input" => select_disease($dbh, "val_disease_classification"),
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
           ],
     },
     {
       "display_name" => "# of Chips",
       "column_type" => "integer",
       "name" => "number_of_chips",
       "searchable" => 1,
       "search_operator" => qq!>=!,
       "search_input" => qq!<input type="text" name="val_number_of_chips"!  . 
         qq! size=4 value="{val_number_of_chips}">!,
       "fixvalues" => 
           [ 
             {
               "name" => "val_", 
               "type" => "select",
             },
             {
               "name" => "op_", 
               "type" => "select",
             },
           ],
     },
  );
  return (\@report_columns);
}

sub get_study_report_data
{ 
  my ($dbh, $us_fk, $columns_ref, $chref)= @_;

  my @data;
  my ($from_clause, $where_clause) =
    read_where_clause("study","sty_pk",$us_fk);
  
  my $sql = "select sty_pk, study_name,sty_comments, study_url, " 
     . " study_abstract from study, $from_clause where $where_clause "
     . " order by study_name"; 


  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref())
  {
    my %temp = ();

    if ($chref->{'use_study_name'})
    {
      next if ($ref->{study_name} !~ /$chref->{'val_study_name'}/i);
    }
       
    # Search 
    if ($ref->{'study_url'})
    {
      $temp{'search'}= "<a href=\"$ref->{'study_url'}\">" .
        "Source</a>";
    }
    elsif (getq_can_write_x($dbh, $us_fk, "study", "sty_pk", 
          "sty_pk = $ref->{sty_pk}"))
    {
      $temp{'search'}= "<a href=\"edit_study.cgi?pk=" .
        "$ref->{sty_pk}\">Edit</a>";
    }
    else
    {
      $temp{'search'}= "&nbsp";
    }
    
    # Study Name
    $temp{'study_name'} =  "<a href=" .
      "\"study_viewer_full.cgi?sty_pk=$ref->{sty_pk}\">" .
      "$ref->{'study_name'}</a>";

    my %chip_count;
    my $total_num_chips = 0;
       
    my $sql2 = "select arraylayout.name, ec_pk from arraylayout, sample, exp_condition, study, arraymeasurement where al_fk = al_pk and smp_fk = smp_pk and ec_fk = ec_pk and sty_fk = sty_pk and sty_pk = $ref->{sty_pk}";
    
    if ($chref->{'use_chip_type'})
    {
      $sql2 .= " and al_pk = $chref->{val_chip_type}";
    }

    my $sth2 = $dbh->prepare($sql2) || die "prepare $sql2\n$DBI::errstr\n";
    $sth2->execute() || die "execute $sql2\n$DBI::errstr\n";
    my $arraylayout = "";
    my $organism = "";
    if (($chref->{'use_chip_type'}) && ($sth2->rows() < 1))
    {
      $sth2->finish();
      next;
    }
    
    while (my ($name, $ec_pk) =  $sth2->fetchrow_array())
    {
      $arraylayout .= " $name <br> " if ($arraylayout !~ / $name /);
      $total_num_chips++;
      my $sql3 = "select primary_scientific_name from species, exp_condition where spc_pk = spc_fk and ec_pk = $ec_pk";
      if ($chref->{'use_organism'})
      {
        $sql3 .= " and spc_fk = $chref->{'val_organism'}";
      }
      my $sth3 =$dbh->prepare($sql3) || die "prepare $sql3\n$DBI::errstr\n";
      $sth3->execute() || die "execute $sql3\n$DBI::errstr\n";
    
      while (my ($psn) = $sth3->fetchrow_array())
      {
        $organism .= " $psn " if ($organism !~ / $psn /);
      }
    }
 
    # Organism 
    next if (($chref->{'use_organism'}) && (!$organism));
    $temp{'organism'} = $organism;


    # Chip Type
    $temp{'chip_type'} = $arraylayout;

    # Chips
    $temp{'number_of_chips'} = $total_num_chips;

    # Disease Classification
    if ($chref->{'use_disease_classification'})
    {
      my $disease = getq_disease_by_sty_pk_and_opt_dis_pk($dbh, $us_fk, 
          $ref->{'sty_pk'}, $chref->{'val_disease_classification'});
      next if (!$disease);
      $temp{'disease_classification'} = $disease;
    }
    else
    {
      $temp{'disease_classification'}= 
        getq_disease_by_sty_pk_and_opt_dis_pk($dbh, $us_fk, 
        $ref->{sty_pk});
    }
    if ($chref->{'use_number_of_chips'})
    {
      if ($total_num_chips >=  $chref->{'val_number_of_chips'})
      {
        push @data, \%temp;
      }
    }
    else
    {
      push @data, \%temp;
    }
  }
  return(@data);
} 
