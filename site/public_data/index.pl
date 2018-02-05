use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection();
    my $path="$WEB_DIR/site/public_files";

    if (! get_config_entry($dbh, "data_publishing"))
    {
      GEOSS::Session->set_return_message("errmessage",
        "ERROR_DATA_PUBLISHING_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }
    # go into each directory, get index records
    my @recs = `find $path -name 'indexrec*'`;
    @recs = sort @recs;
    my $allhtml; my $loop_template;
    if ($#recs < 0)
    {
      $allhtml = readfile("indexnone.html", "/site/webtools/header.html");
    }
    else
    {
      ($allhtml, $loop_template) = readtemplate("index.html", "/site/webtools/header.html", "/site/webtools/footer.html");

      foreach my $rec (@recs)
      {
          my $vars = readrec($dbh, $rec);
          my $loop_instance = $loop_template;
          $loop_instance =~ s/{(.*?)}/$vars->{$1}/g;
          $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
      }

      $allhtml =~ s/<loop_here>//s;
    }
    my %ch;
    $ch{htmltitle} = "Public Data";
    $ch{htmldescription} = "This page contains experiment data available to the public.  View the MIAME information file for a detailed description of the experiment.";

    my $confref = get_all_config_entries($dbh);
    @ch{keys %$confref} = values %$confref;
    $ch{geoss_dir} = $GEOSS_DIR; $ch{version} = $VERSION;
    $ch{message} = "";

    my $web_index = index_url($dbh, "webtools");
    $ch{member_home} = $web_index;
    $ch{logout_url} = "$web_index/logout.cgi";


    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print $q->header;
    print "$allhtml\n";
    $dbh->disconnect();
    exit();
}

sub readrec
{
    my ($dbh, $file) = @_;
    open (INFILE, $file) || die "Unable to open $file: $!";

    $file =~ /(.*)\/indexrec.*$/;
    my $path = $1;

    my %rec;
    $rec{public_data_path} = "$GEOSS_DIR/site/public_files";
    my $url = index_url($dbh);
    $url =~ /(.*)\/.*\/site/;

    $rec{base} = $1;
    my $line = <INFILE>;
    die "Unexpected input format: $file" if ($line !~ /general_description/);
    $line = <INFILE>;
    while ($line ne "investigator\n")
    {
      $rec{general_description} .= $line;
      $line = <INFILE>;
    }
    $line = <INFILE>;
    $rec{investigator} = $line; 
    $line = <INFILE>;
    die "Unexpected input format: $file" if ($line !~ /credential/);
    $line = "";
    my $data = <INFILE>; my $last = $data ;
    while ($data !~ "filename")
    {
      $data = <INFILE>;
      $line .= $last;
      $last = "<br>" .$data;
    }
    $rec{credential} = $line; 
    $line = $data; 
    die "Unexpected input format: $file" if ($line !~ /filename/);
    $line = <INFILE>;
    $rec{filename} = $line; 

    my $filename = $rec{filename};
    chomp($filename);
    $filename =~ /.*\/(.*)/;
    my $basefile = $1;
    my $zip;
    foreach my $type qw(all cab dtt cel chp rpt exp supplemental)
    {
      $zip = `find $path -name "${basefile}_${type}.zip"`;
      my $key = "${type}_link";
      $rec{$key}= ($zip eq "")?  "" :
        qq#<a href="../public_files/# . trim($zip) . qq#">$type</a>#;
    }
    $rec{miame_name} = $basefile;

    if ((! $rec{all_link}) && (! $rec{cab_link}) && 
        (! $rec{dtt_link}) && (! $rec{cel_link}) &&
        (! $rec{chp_link}) && (! $rec{rpt_link}) &&
        (! $rec{exp_link}) && (! $rec{supplemental}))
    {
      $rec{all_link} = "Data files currently unavailable";
    }
    close(INFILE);
    if (length($rec{general_description}) > 121)
    {
      $rec{general_description} = substr($rec{general_description}, 0, 121);
      $rec{general_description} .= "..."; 
    }; 

    return(\%rec);
}

  sub trim
  {
    my $zip = shift;
    if ($zip ne "")
    {
      $zip =~ /(.*)\/(.*\/.*)/;
      $zip = $2;  
    }
    return ($zip);
  }
