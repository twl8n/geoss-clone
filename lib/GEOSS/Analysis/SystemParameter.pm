package GEOSS::Analysis::SystemParameter;
use strict;

package GEOSS::Analysis::SystemParameterName;
use base qw(GEOSS::Database::Object);

sub tables {
  return 'sys_parameter_names';
}

sub fields {
  return (
    [pk => 'spn_pk'],
    [analysis => 'an_fk'],
    [name => 'sp_name'],
    [default => 'sp_default'],
    [optional => 'sp_optional']
  );
}

sub pk { return shift->{pk} }
sub analysis { return GEOSS::Analysis->new(shift->{analysis}) }
sub name { return shift->{name} }
sub default { return shift->{default} }
sub optional { return shift->{optional} }

package GEOSS::Analysis::SystemParameterValue;
use base qw(GEOSS::Database::Object);

sub tables {
  return 'sys_parameter_values';
}

sub fields {
  my $prefix = shift;
  return (
      [pk => 'spv_pk'],
      [node => 'node_fk'],
      [name => 'spn_fk'],
      [value => 'sp_value']
  );
}

sub pk { return shift->{pk} }
sub value { return shift->{value} }
sub node { return GEOSS::Analysis::Node->new(pk => shift->{node}) }
sub name { 
  return GEOSS::Analysis::SystemParameterName->new(pk => shift->{name})
}

sub copy {
  my $self = shift;
  return GEOSS::Analysis::SystemParameterValue->insert(
        name => $self->{name},
        value => $self->{value},
        @_
  );
}


1;
