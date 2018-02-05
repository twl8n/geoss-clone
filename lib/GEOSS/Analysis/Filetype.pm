package GEOSS::Analysis::Filetype;
use strict;
use GEOSS::Analysis::Extension;
use base 'GEOSS::Database::Object';

sub tables {
  return ('filetypes');
}

sub fields {
  return (
    [pk => 'ft_pk'],
    [name => 'ft_name'],
    [arg => 'arg_name'],
    [comments => 'ft_comments']
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub arg { return shift->{arg} }
sub extension { return GEOSS::Analysis::Extension->new(filetype => shift->pk) }

1;
