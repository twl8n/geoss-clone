package GEOSS::Analysis::Extension;
use strict;
use base 'GEOSS::Database::Object';

sub tables {
  return ('extension');
}

sub fields {
  return (
    [pk => 'ext_pk'],
    [filetype => 'ft_fk'],
    [extension => 'extension']
  );
}

sub pk { return shift->{pk} }
sub extension { return shift->{extension} }

1;
