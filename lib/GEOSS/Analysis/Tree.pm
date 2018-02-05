package GEOSS::Analysis::Tree;
use strict;
use base 'GEOSS::Database::ControlledObject';
use File::Path;
use GEOSS::Database;
use GEOSS::Database::Select;
use GEOSS::Session;
use GEOSS::Fileinfo;
use GEOSS::Analysis::Node;

sub tables {
  return 'tree';
}

sub fields {
  return (
    [pk => 'tree_pk'],
    [name => 'tree_name'],
    [input => 'fi_input_fk']
  );
}

sub name { return shift->{name} }
sub pk { return shift->{pk} }
sub input { return GEOSS::Fileinfo->new(pk => shift->{input}) }

sub copy {
  my $self = shift;

  my $new_tree = GEOSS::Analysis::Tree->insert(
    owner => $self->owner,
    group => $self->group,
    perms => $self->perms,
    @_
    );

  my $newtreepath = "$GEOSS::BuildOptions::USER_DATA_DIR/" .
   $self->owner->login . "/Analysis_Trees/" . $new_tree->name;

  mkpath $newtreepath, 0, 0770 or die "Unable to make $newtreepath: $!";
  $self->root->copy(tree => $new_tree->pk, parent => -1);
  my $new_input;
  eval {
    $new_input = $self->input->copy(
      node => $self->root->pk,
      name => $newtreepath . "/" . $new_tree->name . ".txt",
      perms => $self->perms,
      );
  };
  if ($@)
  {
    die "Unable to copy tree: $!";
  }
  else
  {
    $new_tree->update(
        input => $new_input->pk,
    );
    return $new_tree;
  }
}

sub status {
  my $self = shift;

  foreach ($self->nodes)
  {
    return "OBSOLETE" if $_->status eq "OBSOLETE";
  }
  return "CURRENT";
}

sub new_from_id {
  my $class = shift;
  my $id = shift;

  return $id =~ /^[0-9]+$/ ?
    $class->new(pk => $id) :
    $class->new(name => $id);
}


sub path {
  my $self = shift;
  return join('/',
      $::USER_DATA_DIR,
      $GEOSS::Session::user->login(),
      'Analysis_Trees',
      $self->{name});
}

sub root {
  my $self = shift;

  my $q = GEOSS::Database::Select->new();
  $q->table('node');
  $q->field('node_pk');
  $q->constraint('tree_fk', $self->{pk});
  $q->constraint('parent_key', '-1');

  my ($root) = $dbh->selectrow_array("$q");
  return GEOSS::Analysis::Node->new(pk => $root);
}

sub nodes {
  return GEOSS::Analysis::Node->new_list(tree => shift->pk);
}

sub upgrade {
  my $self = shift;

  foreach my $n ($self->nodes)
  {
    return undef if (! $n->upgrade);
  }
  return $self;
}


1;
