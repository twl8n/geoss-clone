#!/usr/bin/perl

print "What is new tag? (i.e. Test-2_1_2_3 or Rel-2_1_2_3)";
my $tag = <STDIN>;
chomp($tag);
my ($type, $ver) = split(/-/, $tag);
my $ver_dot = $ver;
$ver_dot =~ s/_/./g;

print "cp geoss-X.X.spec ~/.rpm/SPECS/geoss-${ver_dot}.spec\n";
print "cd ..\n";
print "cvs commit -m \"Updated version numbers\"\n";
print "cvs tag ${type}-${ver}\n";
print "cd ..\n";
print "cvs export -r ${type}-${ver} -d geoss-${ver_dot} geoss\n";
print "cp geoss-${ver_dot}/build-options.default geoss-${ver_dot}/build-options.mk\n";
print "tar cvf geoss-${ver_dot}.tar geoss-${ver_dot}\n";
print "gzip geoss-${ver_dot}.tar\n";
print "mv geoss-$ver_dot.tar.gz .rpm/SOURCES/\n";
print "cd .rpm/SPECS\n";
print "rpmbuild -ba --buildroot /home/tdj4m/buildroot geoss-${ver_dot}.spec\n";
print "cd ../RPMS/i386\n";
print "scp geoss-${ver_dot}-1.i386.rpm reed6.med.virginia.edu:~/\n";
