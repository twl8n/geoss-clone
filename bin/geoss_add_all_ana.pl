
use strict;

my @cfg_files = `find $WEB_DIR/site/webtools/analysis -name '*.cfg'`;
my $cfg_file;
my $exit = 0;
foreach $cfg_file (@cfg_files)
{
  chomp $cfg_file;
  print "Adding $cfg_file\n";
  my $rc = system "perl $BIN_DIR/geoss_add_analysis --configfile $cfg_file";
  if ($rc != 0)
  {
    warn "Unable to load analysis for $cfg_file: $!\n";
    $exit = 1;
  }
}

exit $exit;

