use strict;
use CGI;
use URI::Escape;
use File::Basename;
use IO::File;

require "$LIB_DIR/geoss_session_lib";

# Mapping of file extentions to the content types we report. We could,
# instead of using this list, look in the system mime.types file. This
# introduces extra dependencies, and such a file wouldn't understand
# our domain-specific extensions.
my %EXTENSIONS = (
    html => 'text/html',
    pdf => 'application/pdf',
    jpg => 'image/jpeg',
    jpeg => 'image/jpeg',
    txt => 'text/plain',
    rpt => 'text/plain',
    'exp' => 'text/plain',
    'log' => 'text/plain',
);

my $q = new CGI;
my $fn = $q->param("filename"); 

my $dbh = new_connection();
my $us_fk = get_us_fk($dbh, 
    "webtools/getfile.cgi?filename=" . uri_escape($fn));
if(!getq_can_read_filename($dbh, $us_fk, $fn)) {
  print $q->header('text/html', '403 Forbidden'),
        $q->start_html('Forbidden!'),
        $q->h1('Forbidden!'),
        "<p>You don't have permission to access the file $fn.\n",
        $q->end_html;
  exit 0;
}
$dbh->disconnect();

my $size = (stat $fn)[7];
defined($size) or die "unable to stat $fn: $!";

my $fh = IO::File->new($fn, 'r');
$fh or die "unable to open $fn: $!";

$fn =~ /\.([^\.]+)$/; 
my $ext = lc($1);
my $type = defined($ext) && exists($EXTENSIONS{$ext}) ?
             $EXTENSIONS{$ext} :
             'application/octet-stream';

print $q->header(-type => $type,
                 ($type =~ /^text/ ? () : (-attachment => basename($fn))),
                 -Content_Length => $size
                );
while(1) {
  my $buf;
  my $r = $fh->read($buf, 4096);
  defined($r) or die "read error on $fn: $!";
  $r or last;
  print $buf;
}
