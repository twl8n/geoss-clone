package GEOSS::Database::Delete;
use strict;
use GEOSS::Database::Query;
our @ISA = qw(GEOSS::Database::Query);

sub new {
  my $self = bless {}, shift;
  $self->_init(@_);
  $self->{values} = [];
  return $self;
}

sub sql {
  my $self = shift;
  return
    join(' ',
        'delete from',
        join(', ', @{$self->{tables}}),
        @{$self->{constraints}} ?
          ('where', join(' and ', @{$self->{constraints}})) :
          ()
        );
}

1;
