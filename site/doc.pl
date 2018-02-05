use strict;
use CGI;

main:
{
  my $q = new CGI;
  my %ch = $q->Vars;

  my $all_html = read_file("doc.html");

  $ch{doc} = read_file($ch{file});

  $ch{module_name} = $ch{file};
  if ($ch{module_name} =~ m/\//)
  {
    $ch{module_name} =~ s/.*\/(.*)/$1/;             # remove any directory part
  }
  $ch{module_name} =~ s/_/\ /sg;                 # _ to space
  $ch{module_name} =~ s/(.*)\..*/$1/s;           # remove extension i.e. .html
  $ch{module_name} =~ s/([A-Z])/\ $1/g;          # Capital letters get a space in front
  $ch{module_name} = ucfirst($ch{module_name});  # capitalize first letter of each word

  if ($ch{tree_pk})
  {
    $ch{back_link} = "<a href=\"webtools/edit_atree1.cgi?tree_pk=$ch{tree_pk}\">Go back/Edit your tree</a>";
  }

  $ch{doc} =~ s/.*<body.*?>(.*)<\/body>/$1/is;
  $all_html =~ s/{(.*?)}/$ch{$1}/sg;
  print "Content-type: text/html\n\n$all_html\n";
}

#
# Copied from readfile in session_lib
# I only changed the name to follow our conventions.
#
sub read_file
{
  my @stat_array = stat($_[0]);
  if ($#stat_array < 7)
  {
    die "File $_[0] not found\n";
    # exit(1);
  }
  my $temp;
  #
  # 2003-01-10 Tom:
  # It is possible that someone will ask us to open a file with a leading space.
  # That requires separate args for the < and for the file name. I did a test to confirm
  # this solution. It also works for files with trailing space.
  # 
  # open(IN, "<", "$_[0]");
  # Keep the old style, until the next version so that we don't have to retest everything.
  # 
  open(IN, "< $_[0]");
  sysread(IN, $temp, $stat_array[7]);
  close(IN);
  return $temp;
}
