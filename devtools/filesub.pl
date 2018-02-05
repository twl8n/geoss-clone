#!/usr/bin/perl

my @files = `find . -name '*.pl'`;
my $file;
foreach $file (@files)
{
  if ($file !~ /filesub.pl/)
  {
    print "Converting $file\n";
    chomp($file);
    my $cmd = "sed -f convert.sed $file > temp"; 
    `$cmd`;
    `mv temp $file`;
  }
}
