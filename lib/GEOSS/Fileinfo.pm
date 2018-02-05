package GEOSS::Fileinfo;
use strict;
use base 'GEOSS::Database::ControlledObject';
use GEOSS::Layout;
use GEOSS::Database::Object;
require 'geoss_session_lib';

sub tables {
  return 'file_info';
}

sub fields {
  return (
    [pk => 'fi_pk'],
    [node => 'node_fk'],
    [name => 'file_name'],
    [input => 'use_as_input'],
    [comments => 'fi_comments'],
    [conds => 'conds'],
    [cond_labels => 'cond_labels'],
    [type => 'ft_fk'],
    [layout => 'al_fk']
  );
}

sub pk { return shift->{pk} }
sub conds { return shift->{conds} }
sub cond_labels { return shift->{cond_labels} }
sub name { return shift->{name} }
sub input { return shift->{input} }
sub comments { return shift->{comments} }
sub layout { return GEOSS::Layout->new(pk => shift->{layout}) }

sub cond_labels_list { 
  my $self = shift;
  return map {
    tr/"//d; $_
  } split /","/, $self->cond_labels
}

sub copy {
  my $self=shift;
  my $new_file = GEOSS::Fileinfo->insert(
      input => $self->{input},
      comments => $self->{fi_comments},
      conds => $self->{conds},
      cond_labels => $self->{cond_labels},
      type => $self->{type},
      layout => $self->{layout},
      group => $self->group,
      owner => $self->owner,
      @_
  );
  if (! ::link_or_copy($self->{name}, $new_file->name, 1))
  {
    die "error in link_or_copy of $self->{file_name} to " . $new_file->name;
  }
  return $new_file;
}

1;
