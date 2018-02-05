package GEOSS::Database::Insert;
use strict;
use GEOSS::Database::Query;
our @ISA = qw(GEOSS::Database::Query);

sub new {
  my $self = bless {}, shift;
  $self->_init(@_);
  $self->{fields} = [];
  $self->{values} = [];
  return $self;
}

sub set {
  my $self = shift;
  while(my $k = shift) {
    my $v = shift;
    push @{$self->{fields}}, $k;
    push @{$self->{values}}, $self->{dbh}->quote($v);
  }
}

sub set_placeholder {
  my $self = shift;
  push @{$self->{fields}}, @_;
  push @{$self->{values}}, map { '?' } @_;
}

sub sql {
  my $self = shift;
  return
    join(' ',
        'insert into',
        join(', ', @{$self->{tables}}),
        '(' . join(', ', @{$self->{fields}}) . ')',
        'values',
        '(' . join(', ', @{$self->{values}}) . ')',
        );
}

1;
