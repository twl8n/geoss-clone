#!/usr/bin/perl - w
@file_list = `find . -name '*.html' | xargs grep -il \"207\" `;
chomp(@file_list);

foreach my $file (@file_list)
{
    $allhtml = "";
    open(IN, "<", $file) || die "can't read $file\n";
    while($temp = <IN>)
    {
        $allhtml .= $temp;
    }
    close(IN);
    $allhtml =~ s/\"207\"/\"216\"/g;
    $allhtml =~ s/\"86\"/\"96\"/g;
    open(OUT, ">", $file) || die "can't write $file\n";
    print OUT "$allhtml";
    close(OUT);
    print "Fixed: $file\n";
}
