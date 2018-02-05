package GEOSS::Database::Query;
use strict;
use GEOSS::Database;
use overload '""' => 'sql';

sub _init {
  my $self = shift;
  $self->{dbh} = shift || $dbh;
  $self->{tables} = [];
  $self->{constraints} = [];
  return $self;
}

sub table {
  my $self = shift;
  push @{$self->{tables}}, @_;
}

sub constraint {
  my $self = shift;
  my $k = shift;

  if(!@_) {
    push @{$self->{constraints}}, $k;
  }
  else {
    foreach my $v (@_) {
      push @{$self->{constraints}}, 
           defined($v) ? 
             ("$k=" . $self->{dbh}->quote($v)) :
             "$k is NULL";
    }
  }
}

sub join {
  my $self = shift;
  my $k1 = shift;
  my $k2 = shift;

  push @{$self->{constraints}}, "$k1=$k2";
}

1;
