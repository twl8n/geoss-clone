

use strict;
use Getopt::Long 2.13;
use AppConfig qw(:expand :argcount);


=head1 NAME

 Rwrapper - spawn and report on specified R analysis

=head1 SYNOPSIS

 ./Rwrapper --kind <qualityControl|diffDiscover|westfallYoung|permCluster>
	 --infile <filename> --outfile <filename> 
     --settings <name=arg>
     [--r_exe <R executable>]

  Multiple settings are possible and represent values in the script 
  that should be changed--essentially a command line arg hack.

  ./Rwrapper --kind qualityControl 
             --infile="dChipAfter.txt"
             --outfile="custom"
             --settings conds="2,4,5"
             --settings condLabels='"min10","min10","hr4"'
             --settings graphFormat="pdf"
             --settings path="/home/tdj"
             --settings outtxt="qc.txt"
             --settings outgph="qc.jpg"
 

=head1 DESCRIPTION 

  The Rwrapper is one component of a web solution to spawn
   various R analysis.  The kind command line parameter specifies 
   the type of analysis to be performed.  The settings file
   contains variables that need to be set inside the 
   R environment before the analysis function is called.

  infile - the name of the file containing signal data.  Should
   correspond to the condition structure as specified above.  Currently 
   expects tab separated data.

  outfile - basename of the file to store output in.  Each analysis 
   will output a text file named "basename.txt".  If other output files
   are generated (i.e. graphical) they will take the form "basename.jpg" 
   or "basename.pdf"

  Definition of settings parameters:
 
  conds - The number of elements in this list specify the
   number of conditions being analyzed.  Each element specifies 
   the number of replicates for a condition.  These values are 
   expected to correspond to the order of the data in the 
   infile.  Thus, if conds="2,4,5", then the data file
   should contain 3 conditions.  The first two columns contain values
   for two replicates of the first condition.  The next four columns
   contain values for four replicates of the second condition.  The 
   last five columns contain data for five replicates of the third 
   condition.

 condLabels - a column name for the condition - used to make results
   more meaningful.  Note that R doesn't like column names to start
   with a number and will prefix such labels with an X


  graphFormat - preferred format for graphical output.  Accepts jpg or 
   pdf.

  path - where to write temporary files.  Defaults to ".".

  r_exe - defaults to R1.9, but can be overridden

=cut

#command line options
my $kind = "" ;
my $infile = "";
my $outfile = "";
my $Rexe = "";
my %settings = (logfile => '/dev/stderr');

#main
my @cmdline = @ARGV;
getOptions();

# check for lock file
my $lockFile = $settings{path} . $kind .  ".lck";
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

parseSettings($lockFile);
my $ok = initiateAnalysis($lockFile);

#remove lock file
clearLock($lockFile);

exit($ok ? 0 : 1);
# end main


sub getOptions
{

  my $help;

  if (@ARGV > 0 ) 
  {
    GetOptions('kind=s'	=> \$kind,
		  'settings=s' => \%settings,
      'infile=s' => \$infile,
      'outfile=s' => \$outfile,
      'logfile=s' => sub {}, # noop for backwards compatibility
      'fileURI=s' => sub {}, # noop for backwards compatibility
      'email=s' => sub {}, # noop for backwards compatibility
      'r_exe=s' => \$Rexe,
      'help|?' => \$help);
  } #have command line args
  else
  { 
     $help = 1;
  }

  if ($help) 
  {
    print "Usage: \n";
    print "./Rwrapper.pl \n --kind <type of analysis> \n";
    print "[--r_exe <R_executable>]\n";
    print "--infile <value> --outfile <value>\n";
    print "--settings <name>=<value>\n";
    print "	setting names: conds condLabels ";
    print " path graphFormat\n";
    exit;
  };

  if (! $Rexe)
  {
    $Rexe = 'R1.9';
  }

  $settings{path} = "./" if (!exists $settings{path});

  # ensure that path ends in /
  my $temp = $settings{path};
  my $lastchar = chop($temp);
  $settings{path} .= "/" if ($lastchar ne "/");

  die "Must specify an input file\n" if ($infile eq "");
  die "Must specify an output file\n" if ($outfile eq "");

  $settings{infile} = $infile;
  $settings{outfile} = $outfile;

  # where is inputFile - user might give us complete path to input file
  # or may give us name and assume we will prepend path 
  if (exists($settings{infile}))
  {
  	if (! -s $settings{infile})
  	{
    		my $other = $settings{path} . $settings{infile};
    		$settings{infile} = $other if (-s $other);
	}
  }

  #what about output file - if they don't supply specific path info
  #then prepend settings path 
  if (exists($settings{outfile}))
  {
    if ($settings{outfile} !~ /\//)
    {
       $settings{outfile} = $settings{path} . $settings{outfile};
    }
  }  


  
} # getOptions

sub parseSettings
{
  my $lockFile = shift;

  $kind =~ /(.*)_\d+$/;
  my $kindroot = $1;
  open(INFILE, "$WEB_DIR/site/webtools/analysis/$kindroot/$kind.rw") || 
	((clearLock($lockFile)) && 
         (die "Couldn't open $WEB_DIR/site/webtools/analysis/$kindroot/$kind.rw: $!\n"));
  open(OUTFILE, "> $settings{path}/$kind.r") || 
	((clearLock($lockFile)) &&
	(die "Couldn't open $settings{path}/$kind.r: $!\n"));

  my $line;
  while ($line = <INFILE>)
  {
    if ($line =~ /### REPLACE ([\S]*)/)
    {
       #print "Line: $line\n";
       #print "About to replace $1\n";
       my $match = $1;
       my $nextline = <INFILE>;

	   # check needed to handle non-existent string
	   if (!exists $settings{$match})
	   {
	      clearLock($lockFile);
          #my $key; my $val;
          #while (($key, $val) = each(%settings))
          #{
          #  print "Key: $key    Val: $val \n";
          #}
		  die "Require $match parameter for $kind\n";
	   }
	   else
	   {
       	  $nextline =~ /(.*)$match(.*)/;
       	  $line = "$1$settings{$match}$2\n";
	   }
    }
    print OUTFILE $line;
  } #while
  
  close(INFILE);
  close(OUTFILE);

} #parseSettings

sub initiateAnalysis
{
  my $lockFile = shift;

  my $config = AppConfig->new();
  $config->define('name', {ARGCOUNT =>  ARGCOUNT_ONE},
        'cmdstr', {ARGCOUNT => ARGCOUNT_ONE},
        'version', {ARGCOUNT => ARGCOUNT_ONE},
        'an_type', {ARGCOUNT => ARGCOUNT_ONE},
        'current', {ARGCOUNT => ARGCOUNT_ONE},
        'up', { ARGCOUNT => ARGCOUNT_LIST },
        'filetype',{ ARGCOUNT => ARGCOUNT_LIST },
        'extension',{ ARGCOUNT => ARGCOUNT_LIST },
        'sp', { ARGCOUNT => ARGCOUNT_LIST },
        'analysisfile', { ARGCOUNT => ARGCOUNT_LIST,});
  $kind =~ /(.*)_\d+$/;
  my $kindroot = $1;
  unless ($config->file("$WEB_DIR/site/webtools/analysis/$kindroot/$kind" . ".cfg"))
  {
    clearLock($lockFile);
    die "Invalid config file format";
  }

  # verify that we have all non-optional user_parameters
  my ($element, $key, $value, $val);
  my @vallist; my @must;
  my $up = $config->get('up');
  my $sp = $config->get('sp');
  my @input = (@$up, @$sp);
  while ($element = shift(@input))
  {
    ($key, $value) = split(/=/, $element, 2);
    $key =~ tr/ //d;
    if ($key eq "name")
    {
        @vallist = split(/ /, $value);
        $val = $vallist[$#vallist];
        if ($val =~ /^--(.*)/)
        {
            $val = $1;
        }
        push @must, $val;
    }
    elsif ($key eq "optional")
    {
        pop @must;
    }
  }

  foreach $val (@must)
  {
     if (!exists $settings{$val})
     {
        clearLock($lockFile);
        die "Setting $val must be specified\n" ;
     }
  }

  my $script = $settings{path} . "$kind.r";
  my $done = system("exec $Rexe --no-save --no-restore <$script");

  use POSIX;
  WIFSIGNALED($done)
    and print STDERR 'R died with signal ' . WTERMSIG($done) . "\n";
  return WIFEXITED($done) && WEXITSTATUS($done) == 0;
} #initiateAnalysis

sub clearLock
{
  my $lockFile = shift;
  unlink($lockFile);
}

=head1 NOTES


=head1 AUTHOR

Teela James
