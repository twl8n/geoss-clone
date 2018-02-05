

use PDF::API2;
use Getopt::Long 2.13;

my $infile;
my $treefile;
my $datafile;
my $pdf_out;
my $logfile;
my $zoom;
my %settings;
%datahash;

my @cmdline = @ARGV;
getOptions();
die "File: $treefile doesn't exist" if (! -e $treefile);
die "File: $datafile doesn't exist" if (! -e $datafile);
die "Zoom factor $zoom should be an integer\n" if ($zoom !~ /^[0-9]+$/);
die "Zoom factor shouldn't be 0\n" if ($zoom == 0);

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
print LOG "Running treedraw as: \n @cmdline \n\n";


#dataprint globals
$matrix_x_size = 10;

#tree variables
$x_space =8;
$y_space =10;
$thumbnail_y_space =1;
$matrix_x_thumbnail = 50;
$thumbnail_init=50;
$x_temp = 300;
$rawx_temp = $x_temp;
$y_temp = 2;
$x_init =750;
$heights = 2000;

$tree_file = convertTreefile($treefile);

open(TEMPFILE3,"< $datafile") or die "can't open $file: $!";
{
  local undef $/;
  $data_file = <TEMPFILE3>;
}
close(TEMPFILE3);

my $aref = \@array;

#parse text in the tree structure
@treelist = split(/\n/,$tree_file);
shift @treelist;
@scaleline = split(/\t/,@treelist[0]);
$scaleval = $zoom* $x_init/@scaleline[4];
foreach $line (@treelist) {	
  $lines++;    # used to compute pdf page length
  @linelist = split(/\t/,$line);
    
  @linelist[2] =~ s/\s//g;
  @linelist[3] =~ s/\s//g;
  @t1 = split(/,/,@linelist[1]);

  # we changed the format to be "probeset | gene acc".  We want gene acc.
  my $temp = $t1[2];
  $temp =~ /.*\| (.*)/;
  $t1[2] = $1;
  
  @t2 = split(/\s/,@t1[2]);
  $t3 = @t2[0];
  chomp($t3);
  if (exists($datahash{$t3})) {
    $t3 .= "_2";
  }
  @linelist[1] = $t3;
		
  @treehash{@linelist[2]} = [@linelist[1],@linelist[4],@linelist[5]];
  #add reference to parent node
  push (@{$treehash{@linelist[3]}},@linelist[2]);
  # 0:label
  # 1:Height
  # 2:Dim
  # 3:First Child
  # 4:Second Child
}

#parse text in the data file
@datalist = split(/\n/,$data_file);
@dataline = split(/\t/,@datalist[0]);
$data_num = $#dataline;

shift @datalist;
foreach $line (@datalist) {
  @dataline = split(/\t/,$line);
  $data_id = @dataline[0];	
  $data_id =~ tr/"//d;
  $data_id =~ /.*\| (.*)/;
  $data_id = $1;
  if (exists($datahash{$data_id})) {
    $data_id .= "_2";
  }
  shift @dataline;
  $df=0;
  foreach $data_element ( @dataline) {
    push @{$datahash{$data_id}},$data_element;
    $df++;
  }
  push @data, @dataline;
}

$colour = determine_colour(@data);

print LOG "Input data rows exceed 1900.  Output pdf can't be viewed with
Acrobat Reader.  Try using xpdf to view results." if ($#data > 1900);

#create the new image
$pdf2=PDF::API2->new;
$page2 = $pdf2->page;
$page2->mediabox(1000,$lines*5+20);
$gfx=$page2->gfx;
	   
my $annot = $page2->annotation();
$Helvetica = $pdf2->corefont('Helvetica',1);
$txt = $page2->text();
$txt->fillcolor(0,0,1); # nice blue links
$txt->font($Helvetica, 10);
      
tree_print(1);

$gfx->close;
$pdf2->saveas($pdf_out);
close(LOG);
clearLock($lockFile);
exit ;



#------------------------------------------------------------------------------------------
# SUBROUTINES
#------------------------------------------------------------------------------------------

sub tree_print{
# print LOG "In tree_print";
  #Prints the Tree image based on the tree files
  #Transverses the tree using recursion

  #inputs
  local $label = @{$treehash{$_[0]}}[0];
  local $height = @{$treehash{$_[0]}}[1];
  local $dim = @{$treehash{$_[0]}}[2];
  local $child1 = @{$treehash{$_[0]}}[3];
  local $child2 = @{$treehash{$_[0]}}[4];
   
  $scaleVal = 100;

  #passed back from children indicating their x-position
  my $x_left;
  my $x_right;
    
  #passed back from children indicating their y-position
  my $y_left;
  my $y_right;

  # $thisHeight = sprintf("%.0f",10 * log(@heights[$_[0]+1] * $scaleVal ));
  $xcoord = $_[1];
   
  if ($dim  <= 2) {
    # End of branch--go home folks, there's nothing to see here
    $font_size = 10;
	  $xp =  $x_init + 25 + ($data_num * $matrix_x_size);   
	  $yp = $y_temp + 4 ;
	  
	  $url = "http:\/\/www.ncbi.nlm.nih.gov\/entrez\/query.fcgi?" . 
      "db=nucleotide\&cmd=search\&term=" . $label;

    if ($y_temp < 12500) {
	    $txt->translate( $xp ,$yp);
      $txt->text($label);
    }
	  my $annot = $page2->annotation();
	  $annot->url($url, 
      -rect => [$xp + ($Helvetica->width($label) * $font_size), 
        $yp + $font_size,
        $xp,
        $yp,
      ], 
      -border => [0,0,0],
    );

    #print LOG "About to data print $label\n";
    data_print($x_init +10, $y_temp + 4,$thumbnail_y_temp,$label);
    $genbank_array_string .= "\"$label\",\n";
    #increment vertical space
    $y_temp += $y_space;
    $thumbnail_y_temp += $thumbnail_y_space;
    #reset horizontal space to init value
    $x_temp = $x_init;
    return($x_temp,$y_temp);
  }
  else
  {
	  #local @node = split(/\s/,$tree[$_[0]]);
    $thisHeight = sprintf("%.0f",$height * $scaleVal );

	  local $child1_dim = @{$treehash{$child1}}[2];
	  local $child2_dim = @{$treehash{$child2}}[2];
	  local $child1_height = @{$treehash{$child1}}[1];
	  local $child2_height = @{$treehash{$child2}}[1];

	  # both children are terminal, highest negative value goes to right
    #print LOG "About to tree print 1: " .
    #  "$child1_dim 2: $child2_dim 3: $child1 4: $child2\n";
	  if (( $child1_dim <=2 ) && ( $child2_dim <=2))
    {
	    if ($child1  < $child2 )
      {
	      ($x_left,$y_left) = tree_print($child1,$x_temp);
        ($x_right,$y_right) = tree_print($child2,$x_temp);
		  }
		  else
      {
        ($x_left,$y_left) = tree_print($child2,$x_temp);
        ($x_right,$y_right) = tree_print($child1,$x_temp);
      }
	  }
	  # One child is terminal, terminal child goes to left
	  elsif (( $child1_dim <= 2) || ( $child2_dim <= 2 ))
    {
      if ($child1_dim <= 2 )
      {
	      ($x_left,$y_left) = tree_print($child1,$x_temp);
        ($x_right,$y_right) = tree_print($child2,$x_temp);
		  }
	 	  else
      {
        ($x_left,$y_left) = tree_print($child2,$x_temp);
        ($x_right,$y_right) = tree_print($child1,$x_temp);
      } 
    }
    # Neither children is terminal---lowest height goes to left
    else
    {
      if ( $child1_height  < $child2_height  )
      {
        ($x_left,$y_left) = tree_print($child1,$x_temp);
        ($x_right,$y_right) = tree_print($child2,$x_temp);
		  }
      else
      {
        ($x_left,$y_left) = tree_print($child2,$x_temp);
        ($x_right,$y_right) = tree_print($child1,$x_temp);
		  }
    }
     
    $thisHeight =  $height;
	  $current_height = $thisHeight * $scaleval;
	  $x_temp = $x_init - $current_height ;
	  $hLeft =  $x_left - $x_temp ; 
	  $hRight = $x_right - $x_temp; 
     
	  # line down to left child
	  VLineXY($gfx,$x_temp,$y_left,$x_left,$y_left);
	
	  # line down to right child
	  VLineXY($gfx,$x_temp,$y_right,$x_right,$y_right);
	
	  #line bridging children
	  HLineXY($gfx,$x_temp ,$y_left,$x_temp,$y_right);
	
    #new vertical space is average of the two children values
	  my $y_temp =( $y_left + $y_right)/2;

	  return($x_temp,$y_temp);
  }
}

#-----------------------------------------------------------------------------------------------
 
  
sub data_print{
  #print LOG "In data_print\n";
  $matrix_square_size= 10;
    
  $matrix_x = $_[0];
  $matrix_y = $_[1];
  $thumbnail_matrix_y = $_[2];
  $thumbnail_matrix_x = $thumbnail_init;

  $data_elements = $datahash{$_[3]};
  #print LOG "Data elements" . @$data_elements[0],"\n";
	  
  foreach $data_element (@$data_elements) {
   #will be 0..255
   $gfx->rect($matrix_x,$matrix_y,$matrix_square_size,$matrix_square_size);
   $gfx->fillcolor($colour->{$data_element}->{'red'},
		   $colour->{$data_element}->{'green'}, 0);
   $gfx->fill;
   $matrix_x += $matrix_x_size;
   $thumbnail_matrix_x += $matrix_x_size;
  }
}


sub determine_colour {
  my @data_vals = @_;
  my %output;
  my $mid = int($#data_vals/2);

  @sorted = sort { $a < $b ? -1 : 1 } @data_vals;

  for (my $i = 0; $i <= $mid; $i++ ) {
    $output{$sorted[$i]} = {
	'red' => 0,
 	'green' => 1 - ($i / ($mid + 1))
    }
  };

  for (my $i = $mid; $i <= $#sorted; $i++ ) {
    $output{$sorted[$i]} = {
	'green' => 0,
 	'red' => 1 - (($i-$mid) / ($mid + 1))
    }
  };
  return \%output;
} # determine_colour



sub HLineXY()
 {
 my ($gfx, $x1, $y1, $x2, $y2) = @_;
 
 $gfx->move( $x1, $y1 );
 $gfx->line( $x2, $y2 );
 $gfx->stroke;
 }
 
 sub VLineXY()
 {
  my ($gfx,$x1, $y1, $x2, $y2) = @_;
 
 $gfx->move( $x1, $y1 );
 $gfx->line( $x2, $y2 );
 $gfx->stroke;
 }

sub getOptions
{

    my $help;
    if (@ARGV > 0)
    {
        GetOptions(
            'infile=s' => \$infile,
            'treefile=s' => \$treefile,
            'datafile=s' => \$datafile,
            'outfile=s' => \$pdf_out,
            'logfile=s' => \$logfile,
            'settings=s' => \%settings,
            'zoom=i' => \$zoom,
            'help|?' => \$help);
    }
    else
    {
        $help = 1;
    } 

    usage() if $help;
    die "Must specify an infile\n" if ($infile eq "");
    #die "Must specify a treefile\n" if ($treefile eq "");
    #die "Must specify a datafile\n" if ($datafile eq "");
    die "Must specify a logfile\n" if ($logfile eq "");
    die "Must specify a outfile\n" if ($pdf_out eq "");
    $settings{path} = "./" if (!exists $settings{path});
    # ensure that path ends in /
    my $temp = $settings{path};
    my $lastchar = chop($temp);
    $settings{path} .= "/" if ($lastchar ne "/");

    # where is inputFile - user might give us complete path to input file
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
    # infile contains the names of the treefile and the datafile
    # this is because analysis trees can only handle input coming from one
    # node of the tree, so parent nodes must concat files to send more
    # than one

    open (INFILE, "$infile") || die "Unable to open $infile: $!\n";
    $datafile=<INFILE>;
    $treefile=<INFILE>;
    close(INFILE);
    chomp($datafile); chomp($treefile);


}

# This functions serves solely to convert the graph format passed in an R 
# format to our desired format.  The current R format will put two leaf 
# nodes in one line.  Our code expected one leaf node.  
# I decided (in the interests of time) to create a conversion function 
# to give each node its own line, rather than change our tree drawing code.
# 
# We are changing from this format:
#ACC  GRAPHLABEL  NODE  PARENT  HEIGHT  Dim
#1 0,0,ORIG  1 0 2.0071311957  6
#-1  1,1,335_r_at | HG3033-HT3194  2 1 2.0071311957  1
#-1  1,2,  3 1 0.8201843252  5
#-1  2,1,  4 3 0.2881099882  3
#-1  2,2,38309_r_at | AA805659 40042_r_at | U82381 5 3 0.2883419250  2
#-1  3,1,37746_r_at | U15131 6 4 0.2881099882  1
#-1  3,2,41227_at | AL022162 34503_at | AF007146 7 4 0.1966039183  2

# To this format:
#ACC GRAPHLABEL  NODE  PARENT  HEIGHT  Dim
#1 0,0,ORIG  1 0 2.0071311957  11
#-1  1,1,335_r_at | HG3033-HT3194  2 1 2.0071311957  1
#-1  1,2,  3 1 0.8201843252  9
#-1  2,1,  4 3 0.2881099882  5
#-1  2,2,  5 3 0.2883419250  3
#-1  2,2,38309_r_at | AA805659 6 5 0.1441709625  1
#-1  2,2,40042_r_at | U82381 7 5 0.1441709625  1
#-1  3,1,37746_r_at | U15131 8 4 0.2881099882  1
#-1  3,2,  9 4 0.1966039183  3
#-1  3,2,41227_at | AL022162 10  9 0.09830195915 1
#-1  3,2,34503_at | AF007146 11  9 0.09830195915 1


sub convertTreefile
{
  my ($treefile) =  @_;

	open(TEMPFILE,"< $treefile") or die "can't open $file: $!";
	my $headers = <TEMPFILE>;
	$nodeincr = 0;
	%nodemap = ( 1 => "0");
	%dims = ();
	%parentmap = ();
	while ($line = <TEMPFILE>)
	{
	  chomp($line);
	  my ($acc, $label, $node, $parent, $height, $dim)  = split(/\t/, $line);
    # seems to be some whitespace around parent and node that confuse stuff
    $parent =~ /([0-9]+)/;
    $parent = $1;
    $node =~ /([0-9]+)/;
    $node = $1;

	  # we have to increment the node to account for rows we've added
	  $newnode = $node + $nodeincr;
	  # store the mapping between the newnode and the old node so we can
	  # correct parents
	  $nodemap{$node} = $newnode;
	  $parent = $nodemap{$parent};
	
	  if ($label =~ /([0-9]+,[0-9]+,)(.+ \| .+) (.+ \| .+)/)
	  {
	    $nodeincr += 2;
	    $commapart = $1;
	    $node1label = $2;
	    $node2label = $3;
	    $node1 = $newnode+1;
	    $node2 = $newnode+2;
	 
	    $parentrow = "$acc\t$commapart\t$newnode\t$parent\t$height\t1";
	    calcDims($newnode, $parent);
	    $parentMap{$newnode} =  $parent;
	    $newheight= $height/2;
	    $node1row = "$acc\t$commapart$node1label\t$node1\t$newnode\t$newheight\t1";
	    calcDims($node1, $newnode);
	    $parentMap{$node1} =  $newnode;
	    $node2row = "$acc\t$commapart$node2label\t$node2\t$newnode\t$newheight\t1";
	    calcDims($node2, $newnode);
	    $parentMap{$node2} =  $newnode;
	    push(@treerows, $parentrow, $node1row, $node2row);
	  }
	  else
	  {
	    $line = "$acc\t$label\t$newnode\t$parent\t$height\t1";
	    calcDims($newnode, $parent);
	    $parentMap{$newnode} =  $parent;
	    push (@treerows, $line);
	  }
	}
	close(TEMPFILE);
	
	foreach $line (@treerows)
	{
	  my ($acc, $label, $node, $parent, $height, $dim)  = split(/\t/, $line);
	  $dim = $dims{$node};
	  $line = "$acc\t$label\t$node\t$parent\t$height\t$dim";
	  push (@datawithdim, $line);
	}
	
	my $treestr = "$headers";
	foreach $line (@datawithdim)
	{
	  $treestr .= $line . "\n";
	}

  return($treestr);
}# covertTreefile

sub calcDims
{
  my ($node, $parent) = @_;
  $dims{$node} = 1;
  $recur = $parent;
  while ($dims{$recur} != 0)
  {
    $dims{$recur}++;
    $recur = $parentMap{$recur};
  }

}

sub usage
{
    print STDERR "Usage: ./treedraw.pl --infile <infile>" .
        "--outfile <outfile> --logfile <infile> --zoom <zoom> \n";
    die;
}

sub clearLock
{
  my $lockFile = shift;
  unlink($lockFile);
}

