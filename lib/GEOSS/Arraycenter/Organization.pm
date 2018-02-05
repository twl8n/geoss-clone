package GEOSS::Arraycenter::Organization;
use strict;
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;
our @ISA = qw(GEOSS::Database::Object);

sub tables {
  return 'organization';
}

sub fields {
  return (
    [pk => 'org_pk'],
    [name => 'org_name'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }

1;
