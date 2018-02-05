use strict;
use CGI;
use GEOSS::Experiment::Study;
use GEOSS::Session;

require "$LIB_DIR/geoss_session_lib";

my $q = new CGI;
my $us_fk = get_us_fk($dbh, "webtools/choose_study.cgi");
my %ch = $q->Vars();
#
# Show the user a list of studies that are >>writable<< by the user.
#
my $study = GEOSS::Experiment::Study->new(pk => $ch{sty_pk});
$ch{status} = $study->status;
$ch{name} = $study->name;
$ch{short_name} = length($study->name > 31) ?
  substr($study->name,0,32) . "..." : $study->name;
$ch{study_date} = $study->date; #sql2date($s_hr->{study_date});
$ch{comments} = $study->comments;
my $allhtml;
if (($ch{status} eq "INCOMPLETE") || ($ch{status} eq "COMPLETE"))
{
  ($allhtml)=readtemplate("delete_study1.html", "/site/webtools/header.html",
      "/site/webtools/footer.html"); 
}
else
{
  ($allhtml)=readtemplate("cant_delete_study.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html");
}

%ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
$ch{htmltitle} = "Array Study Delete Confirmation";
$ch{help} = set_help_url($dbh, "delete_study1.pl");

$allhtml =~ s/{(.*?)}/$ch{$1}/g; 
print "Content-type: text/html\n\n$allhtml\n";

