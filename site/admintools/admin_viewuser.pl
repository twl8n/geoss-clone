use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_reports_lib";

my $q = new CGI;
my %ch = $q->Vars();

my $dbh = new_connection(); # session_lib
my $us_fk = get_us_fk($dbh, "admintools/admin_viewuser.cgi");

if (! is_administrator($dbh, $us_fk))
{
  set_session_val($dbh, $us_fk, "message", "errmessage",
    get_message("INVALID_PERMS"));
  my $url = index_url($dbh, "webtools"); # see session_lib
  warn "non-administrator $us_fk runs admin_viewuser.cgi";
  print "Location: $url\n\n";
  $dbh->disconnect;
  exit();
}

$ch{htmltitle} = "View Users";
$ch{help} = set_help_url($dbh, "user_administration");
$ch{htmldescription} = "";
$ch{formaction} = "admin_viewuser.cgi";

my $allhtml = make_report($dbh, $us_fk, \%ch, \&define_user_report_columns,
    \&get_user_report_data);

print $q->header;
print "$allhtml\n";
print $q->end_html;

$dbh->disconnect;

sub define_user_report_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = (
      {
        "display_name" => "Last Name",
        "column_type" => "string",
        "name" => "contact_lname",
      },
      {
        "display_name" => "First Name",
        "column_type" => "string",
        "name" => "contact_fname",
      },
      {
        "display_name" => "Login",
        "column_type" => "string",
        "name" => "login",
      },
      {
        "display_name" => "Phone",
        "column_type" => "string",
        "name" => "contact_phone",
      },
      {
        "display_name" => "User Type",
        "column_type" => "string",
        "name" => "type",
      },
      {
        "display_name" => "Last Login",
        "column_type" => "date",
        "name" => "last_login",
      },
    );
    return(\@report_columns);
}

sub get_user_report_data
{ 
   my ($dbh, $us_fk, $columns_ref, $chref) = @_;

   my @data = ();

   my $sql = "select contact_lname, contact_fname, login, contact_phone, type, last_login from contact, usersec where con_fk = con_pk";
   my $sth = $dbh->prepare($sql);
   $sth->execute();
   while (my $ref = $sth->fetchrow_hashref())
   {
     $ref->{type} = display_user_type($ref->{type});
     $ref->{last_login} = transform_date($ref->{last_login});
     push @data, $ref;
   }
   return(@data);
};

