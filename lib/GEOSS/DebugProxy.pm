package GEOSS::DebugProxy;
use strict;

sub new {
  my $class = shift;
  my $self = bless {}, "${class}::Object";
  $self->{object} = shift;
  $self->{dumpargs} = 1;
  $self->{stacktrace} = 1;
  %$self = (%$self, @_);
  return $self;
}

package GEOSS::DebugProxy::Object;
use Data::Dumper;
use Carp;

our $AUTOLOAD;

sub AUTOLOAD {
  my $self = shift;
  my $func = $AUTOLOAD;
  $func =~ s/.*://;

  print STDERR 'DEBUGPROXY: ' . ref($self->{object}) . '::' . $func . "\n";
  print STDERR map { "  ARGS: $_\n" } (split /\n/, Dumper(@_))
    if($self->{dumpargs});
  print STDERR map { "  STACK: $_\n" } (split /\n/, Carp::longmess())
    if($self->{stacktrace});

  return $self->{object}->$func(@_);
}

1;
