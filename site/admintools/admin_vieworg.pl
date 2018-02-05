use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my %ch = $q->Vars();

my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "admintools/admin_vieworg.cgi");

if (! is_administrator($dbh, $us_fk))
{
   set_session_val($dbh, $us_fk, "message", "errmessage",
     get_message("INVALID_PERMS"));
   my $url = index_url($dbh, "webtools"); # see session_lib
   warn "non-administrator $us_fk runs admin_vieworg.cgi";
   print "Location: $url\n\n";
   $dbh->disconnect;
   exit();
}

$ch{htmltitle} = "View Special Centers";
$ch{help} = set_help_url($dbh, "special_center_administration"); 
$ch{htmldescription} = "";
$ch{formaction} = "admin_vieworg.cgi";

my $allhtml = make_report($dbh, $us_fk, \%ch, \&define_org_report_columns, 
  \&get_org_report_data);

print $q->header;
print "$allhtml\n";
print $q->end_html;

$dbh->disconnect;


sub define_org_report_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = (
      {
        "display_name" => "Name",
        "column_type" => "string",
        "name" => "org_name",
      },
      {
        "display_name" => "Description",
        "column_type" => "string",
        "name" => "org_description",
      },
      {
        "display_name" => "Phone",
        "column_type" => "string",
        "name" => "org_phone",
      },
      {
        "display_name" => "Needs Approval",
        "column_type" => "boolean",
        "name" => "needs_approval",
      },
      {
        "display_name" => "Discount",
        "column_type" => "integer",
        "name" => "chip_discount",
      },
    );
  return(\@report_columns);
}

sub get_org_report_data
{
  my ($dbh, $us_fk, $columns_ref, $chref) = @_;
  my @data = ();

  my $sql = "select org_name, org_description, org_phone, needs_approval, chip_discount from organization";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref())
  {
       push @data, $ref;
  }
  return(@data);
};
