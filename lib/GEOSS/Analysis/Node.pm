package GEOSS::Analysis::Node;
use strict;
#use base 'GEOSS::Database::ControlledObject';
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;
use GEOSS::Analysis;
use GEOSS::Analysis::SystemParameter;
use GEOSS::Analysis::UserParameter;
use GEOSS::Analysis::Tree;
our @ISA = qw(GEOSS::Database::ControlledObject);

sub tables {
  return ('node');
}

sub fields {
  return (
    [pk => 'node_pk'],
    [tree => 'tree_fk'],
    [analysis => 'an_fk'],
    [parent => 'parent_key']
  );
}

sub pk { return shift->{pk} }
sub analysis { return GEOSS::Analysis->new(pk => shift->{analysis}) }
sub tree { return GEOSS::Analysis::Tree->new(pk => shift->{tree}) }

sub copy {
  my $self = shift;

  my $new_node = GEOSS::Analysis::Node->insert(
      analysis => $self->{analysis},
      owner => $self->owner,
      group => $self->group,
      perms => $self->perms,
      @_
      );
  foreach ($self->user_parameter_values, $self->sys_parameter_values)
  {
    $_->copy(node => $new_node->pk);
  }
  foreach my $n ($self->children) {
    $n->copy(@_, parent => $new_node->pk);
  }
  return $new_node;
}

sub status {
  my $self = shift;
  $self->analysis->current ? "CURRENT" : "OBSOLETE";
}

sub parent {
  my $self = shift;
  return $self->{parent} == -1 ?
         undef :
         GEOSS::Analysis::Node->new(pk => $self->{parent});
}

sub children {
  return GEOSS::Analysis::Node->new_list(parent => shift->pk);
}

sub sys_parameter_values {
  return GEOSS::Analysis::SystemParameterValue->new_list(
           node => shift->pk, @_);
}
sub user_parameter_values {
  return GEOSS::Analysis::UserParameterValue->new_list(node => shift->pk, @_);
}

sub output_by_type {
  my $self = shift;
  my $type = shift;

  my $q = GEOSS::Database::Select->new();
  $q->table('file_info', 'filetypes');
  $q->field('fi_pk');
  $q->join('ft_fk', 'ft_pk');
  $q->constraint(ft_name => $type->name());
  $q->constraint(node_fk => $self->pk());

  my $pk = $dbh->selectrow_array($q->sql());
  return $pk ? GEOSS::Fileinfo->new(pk => $pk) : undef;
}

sub is_in_tree {
  my $self = shift;
  my $tree = shift;

  return $self->{tree} eq $tree->pk();
}

sub upgrade {
  my $self = shift;

  my $current_ver = $self->analysis->current_version;
  if ($current_ver) 
  {
    if ($current_ver->pk != $self->analysis->pk)
    {
      my %cur_pks;
      foreach my $upn ($current_ver->user_parameter_names)
      {
        $cur_pks{$upn->name} = $upn->pk;
      }
      foreach my $upv ($self->user_parameter_values)
      {
        if ($cur_pks{$upv->name->name})
        {
          $upv->update(
            name => $cur_pks{$upv->name->name},
          );
        }
        else
        {
          $upv->delete;
        }
      }
      $self->update(
          analysis => $current_ver->pk,
          );
    }
    return ($self); 
  }
  return undef;
}
