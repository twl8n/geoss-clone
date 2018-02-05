package GEOSS::Experiment::ExpCondition;
use strict;
use base 'GEOSS::Database::ControlledObject';
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;

sub tables {
  return 'exp_condition';
}

sub fields {
  return (
    [pk => 'ec_pk'],
    [name => 'name'],
    [short_name => 'abbrev_name'],
    [species => 'spc_fk'],
    ['study' => 'sty_fk'],
    [type => 'sample_type'],
    [description => 'description'],
    [notes => 'notes'],
    [cell_line => 'cell_line'],
    [tissue_type => 'tissue_type'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub notes { return shift->{notes} }
sub description { return shift->{description} }
sub short_name { return shift->{short_name} }
sub species { return shift->{species} }
sub study { return GEOSS::Experiment::Study->new(pk => shift->{study} ) }
sub type { return shift->{type} }
sub type_details {
  my $self = shift;
  return $self->{cell_line} if $self->{type} eq "cells";
  return $self->{tissue_type} if $self->{type} eq "tissue";
  return "";
}

sub check_mandatory_fields {
  my $self = shift;

  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
      "Experimental condition name") if (! $self->name);
  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
      "Short name", " for experimental condition " . $self->name) 
      if (! $self->short_name);
  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
      "Species", " for experimental condition " . $self->name) 
      if (! $self->species);
  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
      "Study", " for experimental condition " . $self->name) 
      if (! $self->study);

  my @smps = $self->samples;
  foreach (@smps)
  {
    $_->check_mandatory_fields;
  }
}

sub status {
  my $self = shift;
  my ($incomplete, $complete, $loading);

  return "INCOMPLETE" if (
     (! $self->name) ||
     (! $self->short_name) ||
     (! $self->species) ||
     (! $self->study)); 

  my @smps = $self->samples;
  foreach (@smps)
  {
    my $status = $_->status;
    $incomplete++ and last if $status eq "INCOMPLETE";
    $loading++ if ($status eq "LOADING IN PROGRESS");
    $complete++  if (($status eq "COMPLETE") || ($status eq "SUBMITTED"));
  }
  return "INCOMPLETE" if $incomplete || @smps == 0;
  return "LOADING IN PROGRESS" if $loading;
  return "COMPLETE" if $complete;
  return "LOADED";
}

sub add_samples {
  my $self = shift;
  my $num = shift;
  
  my $study = $self->study;

  # set defaults according to study defaults if they exist
  my %defaults;
  $defaults{lab_book} = $study->{lab_book} if $study->{lab_book};
  $defaults{lab_book_owner} = $study->{lab_book_owner} 
  if $study->{lab_book_owner};
  $defaults{manipulation} = $study->{sample_manipulation}
  if $study->{sample_manipulation};
  $defaults{origin} = $study->{sample_origin} 
  if $study->{sample_origin};
  $defaults{name} = $study->{sample_name} if $study->{sample_name};

  my @smps;
  for (my $x= 0; $x<$num; $x++)
  {
    my $smp = GEOSS::Experiment::Sample->insert(
        exp_condition => $self->pk,
        owner => $study->owner,
        group => $study->group,
        perms => $study->perms,
        %defaults,
    );
    $smp->add_arraymeasurements($study->{chip_reps});
    push @smps, $smp;
  }
  return (@smps);
}

sub delete {
  my $self = shift;
  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "CANT_DELETE_LOADED", "Experimental condition " . $self->name)
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));

  foreach my $smp ($self->samples)
  {
    $smp->delete;
  }
  $self->SUPER::delete(@_);
}

sub update {
  my $self = shift;
  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "ERROR_CANT_MODIFY_LOADED", "experimental condition " . $self->name)
  if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));
  $self->SUPER::update(@_);
}

sub samples  {
  my $self = shift;

  return GEOSS::Experiment::Sample->new_list(exp_condition => $self->pk);
}

1;
