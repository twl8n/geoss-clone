package GEOSS::Database::Update;
use strict;
use GEOSS::Database::Query;
our @ISA = qw(GEOSS::Database::Query);

sub new {
  my $self = bless {}, shift;
  $self->_init(@_);
  $self->{values} = [];
  return $self;
}

sub set {
  my $self = shift;
  while(my $k = shift) {
    my $v = shift;
    push @{$self->{values}}, "$k = " . $self->{dbh}->quote($v);
  }
}

sub sql {
  my $self = shift;
  return
    join(' ',
        'update',
        join(', ', @{$self->{tables}}),
        'set',
        join(', ', @{$self->{values}}),
        @{$self->{constraints}} ?
          ('where', join(' and ', @{$self->{constraints}})) :
          ()
        );
}

1;
