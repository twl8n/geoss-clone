package GEOSS::Database::Select;
use strict;
use GEOSS::Database::Query;
our @ISA = qw(GEOSS::Database::Query);

sub new {
  my $self = bless {}, shift;
  $self->_init(@_);
  $self->{fields} = [];
  return $self;
}

sub field {
  my $self = shift;
  push @{$self->{fields}}, @_;
}

sub has_fields {
  my $self = shift;
  return @{$self->{fields}} > 0;
}

sub distinct {
  my $self = shift;
  $self->{distinct} = shift;
}

sub orderby {
  my $self = shift;
  $self->{orderby} = shift;
}

sub sql {
  my $self = shift;
  return
    join(' ',
        'select',
        join(', ', 
          map { $self->{distinct} eq $_ ? 
                "distint($_)" :
                $_
          } @{$self->{fields}}),
        (@{$self->{tables}} ?
        ('from', join(', ', @{$self->{tables}})) :
           ()
         ),
        (@{$self->{constraints}} ?
          ('where', join(' and ', @{$self->{constraints}})) :
          ()
        ),
        ($self->{orderby} ? 
          ("order by $self->{orderby}") : 
          ()
        )
        );
}

1;
