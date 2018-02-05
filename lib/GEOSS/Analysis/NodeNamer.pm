package GEOSS::Analysis::NodeNamer;
use strict;
use GEOSS::Analysis::Tree;
use GEOSS::Analysis::Node;

sub new {
  my $self = bless {}, shift;
  my $tree = shift;

  my %names;
  foreach my $node ($tree->nodes()) {
    my $name = $node->analysis->name;
    exists($names{$name})
      or $names{$name} = [];
    push @{$names{$name}}, $node->pk;
  }
  while(my ($name, $nodes) = each %names) {
    if(@$nodes == 1) {
      $self->{$nodes->[0]} = $name;
    }
    else {
      my $i = 1;
      foreach my $node (@$nodes) {
        $self->{$node} = "$name $i";
        $i++;
      }
    }
  }

  return $self;
}

sub name {
  my $self = shift;
  my $node = shift;

  exists($self->{$node->pk}) or die "name requested for unknown node";
  return $self->{$node->pk};
}

1;
