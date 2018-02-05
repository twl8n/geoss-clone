#!/usr/bin/perl

use Getopt::Long 2.13;

my $infile;
my $logfile;
my $type;
my $where;
my %settings;
my $outfile;

my @cmdline = @ARGV;
getOptions();
die "File: $infile doesn't exist" if (! -e $infile);

# check for lock file
my $lockFile = $settings{path} . $kind . ".lck";
if (-s $lockFile)
{
  print "Found lock $lockFile\n";
  print "You can only run one $kind analysis at a time\n";
  exit(1);
}
else
{
  open(LOCK, "> $lockFile") || die "Unable to open $lockFile:$!\n";
  print LOCK $$;
  close(LOCK);
}

open(LOG, "> $logfile") || die "Unable to open $logfile:$!\n";
print LOG "Running addLinks as: \n @cmdline \n\n";

open(INFILE, "$infile") || die "Unable to open $infile:$!\n";
open(OUTFILE, "> $outfile") || die "Unable to open $outfile: $!\n";
my $line;
	  
$header = headerFormat($type);
print OUTFILE $header;
while ($line = (<INFILE>))
{
  my $ncbi = processNCBI($line);
  my $out = linkFormat($line, $ncbi, $type, $where);
  print OUTFILE $out;
}
my $footer = footerFormat($type);
print OUTFILE $footer;

close(INFILE);
close(OUTFILE);
clearLock($lockFile);

sub headerFormat
{
  my ($type) = @_;

  my $string = "";
  if ($type eq "html")
  {
    $string .= "<HTML><HEAD><TITLE>addLinks Output</TITLE></HEAD>";
    $string .= "<BODY>";
    $string .= "<table width=\"600\" border=1 cellspacing=0 cellpadding=3>";
  } elsif ($type eq "txt")
  {
    
  } elsif ($type eq "pdf")
  {

  } else
  {
    die "Unrecognized output type: $type";
  }

  return ($string);
}

sub footerFormat
{
  my ($type) = @_;

  my $string = "";
  if ($type eq "html")
  {
    $string .= "</table></BODY></HTML>";
  } elsif ($type eq "txt")
  {

  } elsif ($type eq "pdf")
  {

  } else
  {
    die "Unrecognized output type: $type";
  }

  return ($string);
}
sub linkFormat
{
  my ($line, $add, $type, $where) = @_;
  
  my $string = "";
  if ($type eq "html")
  {
    
    if ($add =~ /term=(.*)$/)
    {
      #unless it is the header line, it should be formatted as a link
      $add = "<a href=\"" . $add . "\">$1</a>";
    }
    my @data;
    if ($where eq "front")
    {
      @data = split(/\t/, $add . "\t" . $line);
    }
    else
    {
      @data = split(/\t/, $line . "\t" . $add);
    }
    $string .= "<tr>";
    foreach my $data (@data)
    {
      $string .= "<td>$data</td>";
    }
    $string .= "</tr>";
  }
  elsif ($type eq "txt")
  {
    if ($where eq "front")
    {
      $string = $add . "\t" . $line;
    }
    else
    {
      chomp($line);
      $string = $line . "\t" . $add . "\n";
    }
  }
  elsif ($type eq "pdf")
  {

  }
  else
  {
    die "Unsupported output type: $type\n";
  }
  return ($string);
} # linkFormat

sub processNCBI
{
  ($line) = @_;
  if ($line =~ /([^\|]*) \| ([^"]*)"/)
  {
    $url = "http:\/\/www.ncbi.nlm.nih.gov\/entrez\/query.fcgi?" . 
      "db=nucleotide\&cmd=search\&term=" . $2;
  }
  else
  {
    #header line
    $url = "NCBI link";
  }
  return($url)
}

sub getOptions
{

    my $help;
    if (@ARGV > 0)
    {
        GetOptions(
            'infile=s' => \$infile,
            'outfile=s' => \$outfile,
            'logfile=s' => \$logfile,
            'type=s' => \$type, 
            'where=s' => \$where, 
            'settings=s' => \%settings,
            'help|?' => \$help);
    }
    else
    {
        $help = 1;
    } 

    usage() if $help;
    die "Must specify an infile\n" if ($infile eq "");
    die "Must specify a logfile\n" if ($logfile eq "");
    die "Must specify a outfile\n" if ($outfile eq "");
    die "Must specify an output type\n" if ($type eq "");
    $settings{path} = "./" if (!exists $settings{path});
    # ensure that path ends in /
    my $temp = $settings{path};
    my $lastchar = chop($temp);
    $settings{path} .= "/" if ($lastchar ne "/");

    # where is infile - user might give us complete path to input file
    # or may give us name and assume we will prepend path
    if (! -s $infile)
    {
        my $other = $settings{path} . $infile;
        $infile = $other if (-s $other);
    }
   
    #what about output file - if they don't supply specific path info
    #then prepend settings path
    if ($outfile !~ /\//)
    {
       $outfile = $settings{path} . $outfile;
    }
    if ($logfile !~ /\//)
    {
       $logfile = $settings{path} . $logfile;
    }

    die "File: $infile doesn't exist" if (! -e $infile);
}

sub usage
{
    print STDERR "Usage: ./addLinks.pl --infile <infile>" .
        " --outfile <outfile> --logfile <infile> --type <html|txt>\n";
    die;
}

sub clearLock
{
  my $lockFile = shift;
  unlink($lockFile);
}

