package GEOSS::LazyValue;

sub TIESCALAR {
  my $self = bless {}, shift;
  $self->{generator} = shift;
  $self->{args} = [@_];
  return $self;
}

sub FETCH {
  my $self = shift;
  exists($self->{value})
    or $self->{value} = $self->{generator}->(@{$self->{args}});
  return $self->{value};
}

sub STORE {
  my $self = shift;
  $self->{value} = shift;
}

1;
