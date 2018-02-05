package GEOSS::Analysis::UserParameter;
use strict;

package GEOSS::Analysis::UserParameterName;
use base qw(GEOSS::Database::Object);

sub tables {
  return 'user_parameter_names';
}

sub fields {
  return (
    [pk => 'upn_pk'],
    [analysis => 'an_fk'],
    [name => 'up_name'],
    [display_name => 'up_display_name'],
    [type => 'up_type'],
    [default => 'up_default'],
    [optional => 'up_optional']
  );
}

sub pk { return shift->{pk} }
sub analysis { return GEOSS::Analysis->new(shift->{analysis}) }
sub name { return shift->{name} }
sub display_name { return shift->{display_name} }
sub type { return shift->{type} }
sub default { return shift->{default} }
sub optional { return shift->{optional} }

package GEOSS::Analysis::UserParameterValue;
use base qw(GEOSS::Database::Object);

sub tables {
  return 'user_parameter_values';
}

sub fields {
  my $prefix = shift;
  return (
      [pk => 'upv_pk'],
      [node => 'node_fk'],
      [name => 'upn_fk'],
      [value => 'up_value']
  );
}

sub pk { return shift->{pk} }
sub value { return shift->{value} }
sub node { return GEOSS::Analysis::Node->new(pk => shift->{node}) }
sub name { return GEOSS::Analysis::UserParameterName->new(pk => shift->{name}) }

sub copy {
  my $self = shift;
  return GEOSS::Analysis::UserParameterValue->insert(
        name => $self->{name},
        value => $self->{value},
        @_
  );
}

1;
