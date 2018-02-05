#!/usr/bin/perl -w
use strict;

print "Enter old order number:\n";
my $old = <STDIN>;
chomp($old);

print "Enter new order number:\n";
my $new = <STDIN>;
chomp($new);

opendir (DIR, ".") || die "Unable to open . for reading: $!";
my $file;
while ($file = readdir DIR)
{
  if ($file =~ /(.*)$old(.*)/)
  {
    my $newfile = $1 . $new . $2; 
    print "Moving $file to $newfile\n";
    `mv $file $newfile`;
  }
}

close(DIR);

