package GEOSS::Experiment::Arraylayout;
use strict;
use base 'GEOSS::Database::Object';
use GEOSS::Database;
use GEOSS::Database::Iterator;

sub tables {
  return 'arraylayout';
}

sub fields {
  return (
    [pk => 'al_pk'],
    [name => 'name'],
    [contact => 'con_fk'],
    [technology_type => 'technology_type'],
    [medium => 'medium'],
    [chip_cost => 'chip_cost'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub chip_cost { return shift->{chip_cost} }

sub al_spots
{
  my $self = shift;
  my $probeset = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('al_spots');
  $q->field('als_pk','spot_identifier');
  $q->constraint(al_fk => $self->pk);

  my %r = map { $_->[1] => $_->[0] } @{$dbh->selectall_arrayref($q->sql)};
  return \%r;
}

1;
