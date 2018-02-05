package GEOSS::Database::Object;
use strict;
use GEOSS::Database;
use GEOSS::Database::Iterator;
use GEOSS::Database::Update;
use GEOSS::Database::Insert;
use overload '""' => 'as_string';

sub new {
  my $class = shift;
  my @objects = $class->new_list(@_);
  use Data::Dumper;
  @objects > 1 and 
    die "multiple objects matched constraints given to ${class}::new:\n"
            . Dumper({@_});
  return $objects[0];
}

sub _fixup_sql_select { }
sub _fixup_sql_update { }
sub _fixup_sql_delete { }

sub join { }

sub new_list {
  my $class = shift;
  my $constraints = {@_};

  my $oi = GEOSS::Database::Iterator->new($constraints, [$class->tables],
                                          [$class->fields], [$class->join]);
  $class->_fixup_sql_select($oi->query);
  $oi->query->has_fields() or return (bless $constraints, $class);

  my @r;
#print STDERR $oi->query . ";\n";
  $oi->start();
  while(1) {
    my $obj = bless {%$constraints}, $class;
    $oi->fill_hashref($obj) or last;
    push @r, $obj;
  }

  return wantarray ? @r : $r[0];
}

sub _update {
  my $obj = shift;
  my $tables = shift;
  my $fields = shift;
  my $new = shift;

  my $set;
  my $q = GEOSS::Database::Update->new();
  $q->table(@$tables);
  foreach my $f (@$fields) {
    my ($obj_field, $db_field) = @$f;
    if(exists($new->{$obj_field})) {
      $set = 1;
      $q->set($db_field, $new->{$obj_field});
    }
    else {
      $q->constraint($db_field, $obj->{$obj_field});
    }
  }
  $obj->_fixup_sql_update($q);
  if ($set)
  {
    eval { $dbh->do($q->sql()) };
    if ($@)
    {
      GEOSS::Util->report_postgres_err($@);
      die;
    }
    %$obj = (%$obj, %$new);
  }
}

sub update {
  my $self = shift;
  $self->_update([$self->tables()], [$self->fields()], {@_});
}

sub delete {
  my $self = shift;
  return ($self->_delete([$self->tables()], [$self->fields()]));
}

sub _delete {
  my $obj = shift;
  my $tables = shift;
  my $fields = shift;

  my $q = GEOSS::Database::Delete->new();
  $q->table(@$tables);
  foreach my $f (@$fields) {
    my ($obj_field, $db_field) = @$f;
    $q->constraint($db_field, $obj->{$obj_field});
  }
  $obj->_fixup_sql_delete($q);
  my $rows;
  eval { $rows = $dbh->do($q->sql()) };
  if ($@)
  {
    GEOSS::Util::report_postgres_err($@); 
    die GEOSS::Session->set_return_message("errmessage", "CANT_DELETE",
      "from $tables", $obj);
  }
  return $rows;
}

sub _insert {
  my $obj = shift;
  my $tables = shift;
  my $fields = shift;

  my $q = GEOSS::Database::Insert->new();
  $q->table(@$tables);
  foreach my $f (@$fields) {
    my ($obj_field, $db_field) = @$f;
    exists($obj->{$obj_field})
      and $q->set($db_field, $obj->{$obj_field});
  }
  eval { $dbh->do($q->sql()) };
  if ($@)
  {
    GEOSS::Util->report_postgres_err($@);
    die;
  }
}

sub insert {
  my $self = bless {}, shift;
  %$self = @_;
  $self->_insert([$self->tables()], [$self->fields()]);
  return $self;
}

sub update_or_insert {
  my $class = shift;
  my $old = shift;
  my $new = shift;

  my $obj = $class->new(%$old);
  if($obj) {
    $obj->update(%$new);
    return $obj;
  }
  return $class->insert(%$old, %$new);
}

sub as_string {
  my $self = shift;
  return $self->{name} ? "$self->{name}($self->{pk})" : "($self->{pk})";
}

1;
