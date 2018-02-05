package AffyLayoutReader;
use strict;
use Carp;
#use Spreadsheet::ParseExcel;
use vars qw(%COLUMNBINDING  %COLUMNBINDING_TAB );
BEGIN {
    %COLUMNBINDING = ( 'GeneDescription' => 3,
                       'ProbeSet'=>1,
                       'GeneID'=>2,
                       'SpotType'=>5,
                     );
    #
    # 2002-03-11
    # Tom Laudeman: Affymetrix calls the columns by these names
    #
    %COLUMNBINDING_TAB=( 'TargetID' => 0,
                         'ProbeSetID'=>1,
                         'SeqDerivedFrom'=>2,
                         'ConsensusID'=>3,
                         'SequenceType'=>4
                       );
    
}

sub new {
	my ($class,$input_file)=@_;
	my $thisRow;
        die "File $input_file not found" unless (-r $input_file && -f $input_file); 
	my $self= {};
        #if ($input_file =~ m/\.xls/) {
        #  my $ExcelParser = new Spreadsheet::ParseExcel;
        #  my $workbook= $ExcelParser->Parse($input_file);
        #  $self->{worksheet}= $workbook->{Worksheet}[0];
        #  $self->{row_count}=5;
        #}
        #else {
          open(IN, "< $input_file") || die "Could not open $input_file\n";
          $self->{fd} = \*IN; 
          $self->{tab} = 1;
          $self->{row_count}=0;
        #}
        bless $self;
	return $self;
}


sub get_next_datarow {
  my $this=shift;
  $this->{row_count}++;
  my %contents;
  if (exists($this->{tab})) {
    #
    # Perl gets upset with <$this->{fd}>, so put the file descriptor into a scalar.
    # 
    # Affy provides records with varying numbers of fields. If the Probe ID is a group,
    # some fields repeat for each group member and for the exemplar. The exemplar
    # data is in the last 2 fields, thus $#cols-1 and $#cols
    #
    my $fd = $this->{fd}; 
    my $temp;
    my @cols;
    if ( $temp = <$fd>) {
      chomp($temp);
      @cols = split('\t',$temp);
    }
    else {
      return undef;
    }
    
    $contents{RowNumber}=$this->{row_count};
    $contents{GeneID}=$cols[$COLUMNBINDING_TAB{SeqDerivedFrom}]; # [$COLUMNBINDING{GeneID}]
    $contents{SpotID}=$cols[$COLUMNBINDING_TAB{ProbeSetID}];     # [$COLUMNBINDING{ProbeSet}]
    $contents{SpotType}=$cols[$#cols-1];                         # [$COLUMNBINDING{SpotType}]
    $contents{GeneDescription}=$cols[$#cols];                    # [$COLUMNBINDING{GeneDescription}]

    #
    # See comments below re: description and how it is prepared.
    #

    # Affy provides us with descriptions that have no / preceding field names,
    # and no spaces between words in the fields. We should wait until later
    # to try to parse the description field.

#    my $description=$cols[$#cols];                               # [$COLUMNBINDING{GeneDescription}]
#      my @fields = split '/',$description;
#      my $genedescription =  shift(@fields);
#      foreach my $field (@fields) {
#        my ($key,$value) = split("=", $field);
#        $contents{$key} = $value;
#      }
#      if (exists($contents{DEFINITION})) {
#        $genedescription = $contents{DEFINITION};
#      }
#      $genedescription =~ s/^Cluster.*://;
#    $contents{GeneDescription} = $genedescription;

    # debug 
#      printf "geneid: %s spotid %s spottype %s\n",
#        $contents{GeneID},
#          $contents{SpotID},
#            $contents{SpotType},
#              $contents{GeneDescription} ;


  } else {
    my $worksheet = $this->{worksheet};
    my $thisRow=$worksheet->{MinRow}+$this->{row_count};
    return undef unless $thisRow <= $worksheet->{MaxRow};
    $contents{RowNumber}=$thisRow;
    $contents{GeneID}=$worksheet->{Cells}[$thisRow][$COLUMNBINDING{GeneID}]->Value;
    my $description=$worksheet->{Cells}[$thisRow][$COLUMNBINDING{GeneDescription}]->Value;
    $contents{SpotID}=$worksheet->{Cells}[$thisRow][$COLUMNBINDING{ProbeSet}]->Value;
    $contents{SpotType} = $worksheet->{Cells}[$thisRow][$COLUMNBINDING{SpotType}]->Value;

          
    # 
    # 2002-03-11
    # Tom Laudeman
    # The old comment:Clean up redundant info and split off fields
    # Split fields on /, and make key-value pairs by splitting on =.
    # Remove a leading Cluster.*: which I've made non-greedy Cluster.*?:
    #
    # It isn't clear when exists($contents{DEFINITION}) will be true. It seems
    # confusing since it will overwrite whatever gene description we got from 
    # the first field.
    # 
    my @fields = split '/',$description;
    my $genedescription =  shift @fields;
    foreach my $field (@fields) {
      my ($key,$value) = split("=", $field);
      $contents{$key} = $value;
    }
    if (exists($contents{DEFINITION})) {
      $genedescription = $contents{DEFINITION};
    }
    $genedescription =~ s/^Cluster.*://;
    #
    # 2002-03-11
    # Tom Laudeman
    # The following regexp did not do what the author intended, and we can't see a reason to rip
    # M. musculus and Mus musculus out of the description so I've commented it out.
    # As written below, it deletes everything from the first M in the description through the 
    # end of musculus. Opps.
    #
    # $genedescription =~ s/M.*[mM]usculus //;
    $contents{GeneDescription} = $genedescription;
  }
  return \%contents;
}

	
1;
