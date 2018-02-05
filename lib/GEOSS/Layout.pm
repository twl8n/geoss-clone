package GEOSS::Layout;
use strict;
use GEOSS::Database::Object;
our @ISA = qw(GEOSS::Database::Object);

sub tables {
  return 'arraylayout';
}

sub fields {
  return (
    [pk => 'arraylayout.al_pk'],
    [contact => 'arraylayout.con_fk'],
    [name => 'arraylayout.name'],
    [technology_type => 'arraylayout.technology_type'],
    [identifier_code => 'arraylayout.identifier_code'],
    [medium => 'arraylayout.medium']
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
