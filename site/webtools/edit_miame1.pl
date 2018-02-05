use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_miame_lib";

my $q = new CGI;
my %ch = $q->Vars();
my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, "webtools/choose_miame1.cgi");

if (! get_config_entry($dbh, "data_publishing"))
{
  GEOSS::Session->set_return_message("errmessage",
      "ERROR_DATA_PUBLISHING_NOT_ENABLED");
  print "Location: " . index_url($dbh, "webtools") . "\n\n";
  exit;
}

my $allhtml = "";
my $error = 0;

# we got here from "Publish Study Data"
if (!exists ($ch{miame_pk}))
{
# check for a bad name
  if ($ch{miame_name} eq "")
  {
    $error = 1;
    set_session_val($dbh, $us_fk, "message","errmessage", 
        get_message("FIELD_MANDATORY", "MIAME Name"));
  }

  my ($count) = $dbh->selectrow_array("select count(*) from miame where miame_name = '$ch{miame_name}'");
# check for a duplicate name
  if ($count > 0)
  {
    $error = 1;
    set_session_val($dbh, $us_fk, "message","errmessage", 
        get_message("NAME_MUST_BE_UNIQUE"));
  }

  if ($error > 0)
  {
    draw_insert_miame($dbh, $us_fk, \%ch); 
  } 
  else
  {
    my $today = `date`; chomp($today);
    $ch{start_compile_date} =  date2sql($today);
    if ((exists ($ch{sty_fk})) && ($ch{sty_fk} ne ""))
    {
# There is an associated study - get data
      $ch{ed_type} = get_ed_type($dbh, $ch{sty_fk});
# set ed_factors, ed_num, smp_origin, & smp_manipulation
      get_ed_factors($dbh, \%ch, $us_fk);
    }
    save_miame_data($dbh, $us_fk, undef, \%ch);
  }
} 
if (! $error)
{
  my $miame_pk;
  my $key;
  my $htmltitle = "";
  my $htmldescription = "";
  foreach $key (keys(%ch))
  {
    if ($key =~ /Edit_(.*)/)
    {
      $miame_pk = $1;
      load_miame_data($dbh, $us_fk, $miame_pk, \%ch);
    } elsif ($key =~ /Delete_(.*)/)
    {
      $miame_pk = $1;
      load_miame_data($dbh, $us_fk, $miame_pk, \%ch);
      $allhtml = readfile("delete_miame1.html", "/site/webtools/header.html", "/site/webtools/footer.html");
      $htmltitle = "MIAME delete confirmation";
    }
  }

  if ($allhtml eq "")
  {
    if ($ch{miame_type_fk} == 2)
    {
      $allhtml = readfile("edit_miame_cDNA.html", "/site/webtools/header.html", "/site/webtools/footer.html");
      $htmltitle = "Edit MIAME cDNA";
      $htmldescription = "Please fill out the following fields to assist in publishing experiment results";
    }
    elsif ($ch{miame_type_fk} == 1)
    {
      $allhtml = readfile("edit_miame_affy.html", "/site/webtools/header.html", "/site/webtools/footer.html");
      $htmltitle = "Edit MIAME Affymetrix";
      $htmldescription = "Please fill out the following fields to assist in publishing experiment results";
    }

  }

  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

  $ch{htmltitle} = $htmltitle;
  $ch{help} = set_help_url($dbh, "edit_or_delete_or_submit_publishing_information");
  $ch{htmldescription} = $htmldescription;

  $allhtml =~ s/{(.*?)(_val)?}/$ch{$1}/g;

  $allhtml = addHelp($allhtml);

  print $q->header;
  print "$allhtml\n";
  print $q->end_html;
}
$dbh->disconnect();
exit();


sub get_ed_type
{
#this determines ed_type which is based on study name & comments
  my ($dbh, $sty_fk) = @_;
  my $sth= getq("get_study_info", $dbh);
  $sth->execute($sty_fk) || die "Query get_study_info failed.\n$DBI::errstr";
  my ($name, $comments) = $sth->fetchrow_array();
  $sth->finish;

  return ($name . "\n" .  $comments);
}

sub get_ed_factors
{
#this determines ed_factors which is based on exp_conds and filenames 
  my ($dbh, $chref, $us_fk) = @_;
  my $sth = getq("all_study_ec_pk", $dbh);
  $sth->execute($chref->{sty_fk}) || 
    die "Query all_study_ec_pk failed.\n$DBI::errstr";
  my $factorstr;
  my $originstr;
  my $manipulationstr;
  my $ed_num = 0;
  while ((my $ec_pk) = $sth->fetchrow_array())
  {
    my $e_hr; my $notes; my $cond_name; my $hyb_names = "Hybridization names:\n";
    my $smp_origin; my $smp_name; my $smp_manipulation;
    my $sth2 = getq("hybs_readable_for_condition", $dbh, $us_fk);
    $sth2->execute($ec_pk) ||
      die "Query hybs_readable execute failed.\n$DBI::errstr\n";
    my $s_hr;
    while ($s_hr = $sth2->fetchrow_hashref())
    {
      $notes = "Condition Notes: $s_hr->{notes}";
      $cond_name = "Condition Name: $s_hr->{name}";
      $hyb_names .= "    " .  $s_hr->{hybridization_name} . "/" .
        $s_hr->{smp_name}  . ": \n";
      $smp_origin = "$s_hr->{name}: $s_hr->{smp_origin}\n";
      $smp_manipulation = "$s_hr->{name}: $s_hr->{smp_manipulation}\n";
      $ed_num++;
    }
    $factorstr .= "$cond_name \n $notes \n $hyb_names \n";
    $originstr .= "$smp_origin";
    $manipulationstr .= "$smp_manipulation";
  }
  $chref->{smp_origin} = $originstr;
  $chref->{smp_manipulation} = $manipulationstr;
  $chref->{ed_num_hybrids} = $ed_num;
  $chref->{ed_factors} = $factorstr;
}
