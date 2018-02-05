use strict;
use CGI;
# use HTTP::Request::Common qw(POST);
# use LWP::UserAgent;

require "$LIB_DIR/geoss_session_lib";

main:
{
    if (! -r "${WEB_DIR}/.geoss")
    {
      #we can't access the db
      my $allhtml = readfile("db_access_error.html");
      print "Content-type: text/html\n\n$allhtml\n";
    }
    else
    {
      my $dbh = new_connection();
      draw_index($dbh);
      $dbh->disconnect;
    }
}

sub draw_index
{
    my ($dbh) = @_;

    my %ch = ();
    $ch{supported_logos} = build_supported_logos_html($dbh);
    my $confref = get_all_config_entries($dbh);
    @ch{keys %$confref} = values %$confref;
    $ch{version} = $VERSION;
    if (get_config_entry($dbh, "data_publishing"))
    {
      $ch{data_publishing} = qq!
        <p>
        &nbsp;<a href="public_data/index.cgi">View Public Data</a><br>
        &nbsp;View and download publicly available experiment data.</p>
          !;
    }
    else
    {
      $ch{data_publishing} = "";
    }
    my $allhtml = readfile("index.html");
    $allhtml =~ s/{(.*)}/$ch{$1}/g;

    print "Content-type: text/html\n\n$allhtml\n";
}
sub build_supported_logos_html
{
  my ($dbh) = @_;
  my $html = "";
  
  # select all organizations that are displaying organizations
  my $sth = getq("get_org_logos", $dbh);
  $sth->execute() || die "getq get_org_loops\n$DBI::errstr\n";
  # construct the html
  while (my ($org_name, $logo_fi_fk, $org_url, $filename) = $sth->fetchrow_array())
  {
    $filename =~ /.*\/logo\/(.*)/;
    $filename = "./logos/$org_name/$1";
    $html .= qq!<div align="left"><a href="$org_url"><img src="$filename" alt="$org_name"></a></div><br>!;
  }
  if ($html ne "")
  {
    $html = "Geoss supports:<br>" . $html;
  }
  else
  {
    $html = "&nbsp;";
  }
}
