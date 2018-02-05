package GEOSS::Species;
use strict;
use base 'GEOSS::Database::Object';
require 'geoss_session_lib';

sub tables {
  return 'species';
}

sub fields {
  return (
    [pk => 'spc_pk'],
    [name => 'primary_scientific_name'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }

1;
