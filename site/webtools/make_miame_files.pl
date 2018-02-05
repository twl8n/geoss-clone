use strict;
use CGI;
use PDF::API2;


require "$LIB_DIR/geoss_sql_lib";
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_miame_lib";

my ($miame_pk, $invname, $basename, $credential, $us_fk)= @ARGV;
my $dbh=new_connection();
if (! get_config_entry($dbh, "data_publishing"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_DATA_PUBLISHING_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}

my %ch;
my @toprint;
my @conditions = ();

my $outdir = "$WEB_DIR/site/public_files/$invname";
my $rc = mkdir ($outdir, 0775) if (! -d $outdir);
warn ("$ENV{USER} is Unable to make $outdir: $!") if ((defined $rc) && ($rc == 0));
warn "Outdir is $outdir";
# create analysis file
my $sty_fk = getq_miame_sty_fk($dbh, $us_fk, $miame_pk);
if ($sty_fk)
{
  pasteExperiment($dbh, $us_fk, \@conditions, $sty_fk);
  my %ana = build_ana_hash($dbh, @conditions);
  my ($study_name, $sty_comments) = get_study($dbh, $sty_fk);
  $study_name =~ tr/ .-/_/;
  my $file_name = "${outdir}/${invname}_${study_name}.txt"; 
  $ch{comments} = "This file was automatically created when the " .
    "array experiment data was published.  It is intended for use as " .
    "input to analysis trees.";
  my (undef, $fi_pk) = write_data_file($dbh, $us_fk, \%ch, \%ana, 
      $file_name, "");
  # update the miame table
  doq_set_miame_ana_fi_fk($dbh, $us_fk, $miame_pk, $fi_pk);
  $dbh->commit();
}

load_miame_data($dbh, $us_fk, $miame_pk, \%ch);
my $description = $ch{ed_type};
prepare_data(\%ch, \@toprint);


my $outfile = $invname . "_" . $basename; 
my $htmlout = $outdir . "/" . $outfile . ".html";
my $txtout = $outdir . "/" . $outfile . ".txt";
my $pdfout = $outdir . "/" . $outfile . ".pdf";
my $indexout = $outdir . "/" . "indexrec_" . $outfile . ".html";
warn "Index rec is $indexout";

open (HTMLOUT, "> $htmlout") || die "Unable to open $htmlout: $!"; 
open (TXTOUT, "> $txtout") || die "Unable to open $txtout: $!"; 
open (INDEXOUT, "> $indexout") || die "Unable to open $indexout: $!"; 
my $investigator = $invname;
$investigator =~ s/_/ /; 
my $title = "$investigator - $basename";

my $pdf = PDF::API2->new;
my $page=$pdf->page(0);
$pdf->info(
    'Author' => "GEOSS",
    'Title' => "$title",
    );

my $font = $pdf->corefont('Helvetica',1);
my $txt = $page->text();

#write the title info

# create the html page
my $url = index_url($dbh);
my $wwwhost  = get_config_entry($dbh, "wwwhost");
$url =~ /(http.*$wwwhost\/)/;
my $rootpath = $1 . "$GEOSS_DIR/site";
my $graphic = "../../site//graphics/geoss_logo.jpg";

print HTMLOUT "<html><head><title>" . $title .  "</title></head><body>\n";

# create the text page
print TXTOUT "$title" . "\n\n";

#create the pdf page

$txt->font($font, 16);
$txt->translate(25,700);
$txt->text("PDF file unavailable at this time");

foreach my $dataref (@toprint)
{
  print TXTOUT format_item_txt($dataref);
  print HTMLOUT format_item_html($dataref);

  if ($dataref->{type} eq "data")
  {
#  $txt->font($font, 12);
#    $txt->text("$dataref->{value} : " . "$dataref->{value}");
  }
  elsif ($dataref->{type} eq "h1")
  {
#$txt->font($font, 16);
#    $txt->text("$dataref->{value}");
  }
  elsif ($dataref->{type} eq "h2")
  {
#  $txt->font($font, 14);
#    $txt->text("$dataref->{value}");
  }
} 


print HTMLOUT "</body></html>\n";


#create the summary html record
print INDEXOUT "general_description\n$description\n";
print INDEXOUT "investigator\n$investigator\n";
print INDEXOUT "credential\n$credential\n";
print INDEXOUT "filename\n$invname/$outfile\n";


# make zip files (for now empty until Jodi replaces)
foreach my $ziptype ("cel", "chp", "rpt", "exp", "all")
{
  my $zipout = $outdir . "/" . $outfile . "_$ziptype" . "zip.html";
  open (ZIPOUT, "> $zipout") || die "Unable to open $zipout: $!"; 
  print ZIPOUT "<html><head><title>ZIP coming soon</title></head><body>\n";
  print ZIPOUT "Zip file currently unavailable.  Check back in a few days.<br>";
  print ZIPOUT "</body></html>\n";
  close (ZIPOUT);
}


$dbh->disconnect();
close(HTMLOUT);
close(TXTOUT);
close(INDEXOUT);
$pdf->saveas($pdfout);
exit 0;

sub prepare_data
{
  my ($chref, $toprintref) = @_;
  my %ch = %$chref;

  push @$toprintref,
       {
         "type" => "h1", 
         "value" => "Experiment",  
       } ;
  push @$toprintref,
       {
         "type" => "h2", 
         "value" => "Experiment Design",  
       } if (((exists $ch{ed_type}) && (defined $ch{ed_type})) ||
           ((exists $ch{ed_design}) && (defined $ch{ed_design})) ||
           ((exists $ch{ed_factors}) && (defined $ch{ed_factors})) ||
           ((exists $ch{ed_num_hybrids}) && (defined $ch{ed_num_hybrids})) ||
           ((exists $ch{ed_qc_steps}) && (defined $ch{ed_qc_steps})) ||
           ((exists $ch{ed_urls}) && (defined $ch{ed_urls})));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Type of Experiment:",
         "value" => $ch{ed_type}
       } if ((exists $ch{ed_type}) && (defined $ch{ed_type}));

  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Hybridization Design:",
         "value" => "$ch{ed_design}"
       } if ((exists $ch{ed_design}) && (defined $ch{ed_design}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Experimental Factors:",
         "value" => "$ch{ed_factors}"
       }  if ((exists $ch{ed_factors}) && (defined $ch{ed_factors}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Number of hybridizations performed:",
         "value" => "$ch{ed_num_hybrids}"
       } if ((exists $ch{ed_num_hybrids}) && (defined $ch{ed_num_hybrids}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Type of reference used for the hybridization:",
         "value" => "$ch{ed_reference}"
       } if ((exists $ch{ed_reference}) && (defined $ch{ed_reference}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Quality control steps taken:",
         "value" => "$ch{ed_qc_steps}"
       } if ((exists $ch{ed_qc_steps}) && (defined $ch{ed_qc_steps}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "ED_URLS of supplemental websites:",
         "value" => "$ch{ed_urls}"
       } if ((exists $ch{ed_urls}) && (defined $ch{ed_urls}));
  push @$toprintref,
       {
         "type" => "h2", 
         "value" => "Samples Used, Extraction Preparation, and Labeling",  
       } if (((exists $ch{smp_origin}) && (defined $ch{smp_origin})) ||
           ((exists $ch{smp_manipulation}) && 
            (defined $ch{smp_manipulation})) ||
           ((exists $ch{smp_labeling}) && (defined $ch{smp_labeling})) ||
           ((exists $ch{smp_spikes}) && (defined $ch{smp_spikes})) );
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Origin of the biological sample and its characteristics:",
         "value" => "$ch{smp_origin}"
       } if ((exists $ch{smp_origin}) && (defined $ch{smp_origin}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Manipulation of the samples and the protocols used:", 
         "value" => "$ch{smp_manipulation}"
       } if ((exists $ch{smp_manipulation}) && (defined $ch{smp_manipulation}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Protocols for preparing the hybridizations and labeling extracts:", 
         "value" => "$ch{smp_labeling}"
       } if ((exists $ch{smp_labeling}) && (defined $ch{smp_labeling}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "External controls (spikes) added:",
         "value" => "$ch{smp_spikes}"
       } if ((exists $ch{smp_spikes}) && (defined $ch{smp_spikes}));
  push @$toprintref,
       {
         "type" => "h2", 
         "value" => "Hybridization Procedures and Parameters",  
       } if ((exists $ch{hybrid_procedures}) && 
           (defined $ch{hybrid_procedures}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Protocols and conditions used during hybridization, blocking, and washing:",
         "value" => "$ch{hybrid_procedures}"
       } if ((exists $ch{hybrid_procedures}) && 
           (defined $ch{hybrid_procedures}));
  push @$toprintref,
       {
         "type" => "h2", 
         "value" => "Measurement Data and Specifications",  
       } if (((exists $ch{hw_sw_info}) && (defined $ch{hw_sw_info})) ||
           ((exists $ch{sw_type}) && (defined $ch{sw_type})) ||
           ((exists $ch{measurements_image_ana}) && 
            (defined $ch{measurements_image_ana})) ||
           ((exists $ch{sw_measurements_used_ana}) && 
            (defined $ch{sw_measurements_used_ana})) ||
           ((exists $ch{hw_sw_params}) && (defined $ch{hw_sw_params})) ||
           ((exists $ch{sw_data_manipulation}) && 
            (defined $ch{sw_data_manipulation})));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Names and versions of scanning hardware and software used:",
         "value" => "$ch{hw_sw_info_val}"
       } if ((exists $ch{hw_sw_info_val}) && 
           (defined $ch{hw_sw_info_val}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Types of image analysis software used:",
         "value" => "$ch{sw_type}"
       } if ((exists $ch{sw_type}) && (defined $ch{sw_type}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Description of the measurements produced by the image analysis software:",
         "value" => "$ch{measurements_image_ana}"
       } if ((exists $ch{measurements_image_ana}) && 
           (defined $ch{measurements_image_ana}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Description of which measurements were used in the analysis:",
         "value" => "$ch{sw_measurements_used_ana}"
       } if ((exists $ch{sw_measurements_used_ana}) && 
           (defined $ch{sw_measurements_used_ana}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Parameters used in both hardware and software:",
         "value" => "$ch{hw_sw_params}"
       } if ((exists $ch{hw_sw_params}) && (defined $ch{hw_sw_params}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "How the data is analyzed and transformed:",
         "value" => "$ch{sw_data_manipulation}"
       } if ((exists $ch{sw_data_manipulation}) && 
           (defined $ch{sw_data_manipulation}));
  push @$toprintref,
       {
         "type" => "h2", 
         "value" => "Array Design",  
       } if (((exists $ch{ad_design}) && (defined $ch{ad_design})) ||
           ((exists $ch{ad_spot}) && (defined $ch{ad_spot})) ||
           ((exists $ch{ad_specs}) && (defined $ch{ad_specs})) ||
           ((exists $ch{ad_location_id_val}) && 
            (defined $ch{ad_location_id_val})) ||
           ((exists $ch{ad_reporter_type_popup}) && 
            (defined $ch{ad_reporter_type_popup})) ||
           ((exists $ch{ad_manufacturer}) && (defined $ch{ad_manufacturer})) ||
           ((exists $ch{ad_reporter_source}) && 
            (defined $ch{ad_reporter_source})) ||
           ((exists $ch{ad_reporter_prep}) && 
            (defined $ch{ad_reporter_prep}))||
           ((exists $ch{ad_spotting_protocols}) && 
            (defined $ch{ad_spotting_protocols})) ||
           ((exists $ch{ad_prehybrid_treatment}) && 
            (defined $ch{ad_prehybrid_treatment})));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "General array design:",
         "value" => "$ch{ad_design}"
       } if ((exists $ch{ad_design}) && (defined $ch{ad_design}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "What occupies each feature (spot) on the microarray:",
         "value" => "$ch{ad_spot}"
       } if ((exists $ch{ad_spot}) && (defined $ch{ad_spot}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Specifications of the array manufacturer:",
         "value" => "$ch{ad_specs}"
       } if ((exists $ch{ad_specs}) && (defined $ch{ad_specs}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Location of array and ID of its respective reporter for each feature:",
         "value" => "$ch{ad_location_id}"
       } if ((exists $ch{ad_location_id}) && 
           (defined $ch{ad_location_id}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Type of each reporter:",
         "value" => "$ch{ad_reporter_type}"
       } if ((exists $ch{ad_reporter_type}) && 
           (defined $ch{ad_reporter_type}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Reference to manufacturer:",
         "value" => "$ch{ad_manufacturer}"
       } if ((exists $ch{ad_manufacturer}) &&
           (defined $ch{ad_manufacturer}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Source of reporter molecules:",
         "value" => "$ch{ad_reporter_source}"
       } if ((exists $ch{ad_reporter_source}) && 
           (defined $ch{ad_reporter_source}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Spotting protocols used:",
         "value" => "$ch{ad_spotting_protocols}"
       } if ((exists $ch{ad_spotting_protocols}) && 
           (defined $ch{ad_spotting_protocols}));
  push @$toprintref,
       {
         "type" => "data", 
         "label" => "Additional treatments performed prior to hybridization:",
         "value" => "$ch{ad_prehybrid_treatment}"
       } if ((exists $ch{ad_prehybrid_treatment}) &&
           (defined $ch{ad_prehybrid_treatment}));
} #prepare_data

sub format_item_txt
{
  my $dataref = shift;

  if ($dataref->{type} eq "data")
  {
    return ( $dataref->{label} . "\n" . $dataref->{value} . "\n\n");
  }
  else
  {
# h1 and h2 types
    return ( $dataref->{value} . "\n\n"); 
  }    
}

sub format_item_html
{
  my $dataref = shift;

  if ($dataref->{type} eq "data")
  {
#preserve the newlines in html format
    $dataref->{value} =~ s/\cM/<br>/mg;
    return ( "<b>" . $dataref->{label} . "</b><br>\n" . $dataref->{value} 
        . "<br><br>\n");
  }
  elsif ($dataref->{type} eq "h1")
  {
    return ( "<h1>" . $dataref->{value} . "</h1>");
  }
  elsif ($dataref->{type} eq "h2")
  {
    return ( "<h2>" . $dataref->{value} . "</h2>");
  }
}

