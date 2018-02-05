package GEOSS::User::Group;
use strict;
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;

our @ISA = qw(GEOSS::Database::Object);

sub tables {
  return 'groupsec';
}

sub fields {
  return (
    [pk => 'gs_pk'],  
    [name => 'gs_name'],
    [owner => 'gs_owner'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }

1;
