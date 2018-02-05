package GEOSS::Database::Iterator;
use strict;
use GEOSS::Database;
use GEOSS::Database::Select;

sub new {
  my $self = bless {}, shift;
  my $values = shift;
  my $tables = shift;
  my $fields = shift;
  my $join = shift;

  my $q = GEOSS::Database::Select->new();
  $q->table(@$tables);

  my @fields_to_get;
  foreach my $f (@$fields) {
    my ($obj_field, $db_field) = @$f;
    if(exists($values->{$obj_field})) {
      $q->constraint($db_field, $values->{$obj_field});
    }
    else {
      $q->field($db_field);
      push @fields_to_get, $obj_field;
    }

    $q->orderby($db_field) if $obj_field eq 'pk';
  }

  foreach my $j (@$join) {
    $q->join(@$j);
  }

  $self->{query} = $q;
  $self->{fields} = \@fields_to_get;

  return $self;
}

sub query { return shift->{query} }

sub start {
  my $self = shift;
  $self->{sth} = $dbh->prepare($self->{query});
  $self->{sth}->execute();
}

sub fill_hashref {
  my $self = shift;
  my $hashref = shift;

  my @v = $self->{sth}->fetchrow_array;
  @v or return 0;

  foreach my $i (0 .. $#v) {
    $hashref->{$self->{fields}->[$i]} = $v[$i];
  }
  return 1;
}

1;
