package GEOSS::Experiment::Sample;
use strict;
use base 'GEOSS::Database::ControlledObject';
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;
use GEOSS::Experiment::Arraymeasurement;
use GEOSS::Experiment::ExpCondition;
use GEOSS::Arraycenter::Order;

sub tables {
  return 'sample';
}

sub fields {
  return (
    [pk => 'smp_pk'],
    [exp_condition => 'ec_fk'],
    [order => 'oi_fk'],
    [lab_book => 'lab_book'],
    [lab_book_owner => 'lab_book_owner'],
    [name => 'smp_name'],
    [manipulation => 'smp_manipulation'],
    [origin => 'smp_origin'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub origin { return shift->{origin} }
sub manipulation { return shift->{manipulation} }
sub lab_book { return shift->{lab_book} }
sub lab_book_owner { return shift->{lab_book_owner} }
sub order { 
  return GEOSS::Arraycenter::Order->new(pk => shift->{order} )}
sub exp_condition { 
  return GEOSS::Experiment::ExpCondition->new(pk => shift->{exp_condition} )}
sub study {
  return GEOSS::Experiment::Study->new(pk => shift->exp_condition->study->pk);
}

sub delete {
  my $self = shift;

  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "CANT_DELETE_LOADED", "Sample " . $self->name) 
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));
  die GEOSS::Session->set_return_message("errmessage",
    "CANT_DELETE_LOCKED", "Sample " . $self->name) 
    if ($status eq "SUBMITTED");

  foreach my $am ($self->arraymeasurements)
  {
    $am->delete;
  }
  $self->SUPER::delete(@_);
}

sub update {
  my $self = shift;

  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "ERROR_CANT_MODIFY_LOADED", "sample " . $self->name) 
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));
  $self->SUPER::update(@_);
}

sub check_mandatory_fields {
  my $self = shift;

  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
    "Experimental condition", " for sample " . $self->name) 
    if (! $self->exp_condition);

  my @ams = $self->arraymeasurements;
  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
    "Number of chip replicates", " for sample " . $self->name) 
    if (! @ams);
  foreach (@ams)
  {
    $_->check_mandatory_fields;
  }
}

sub status {
  my $self = shift;
  my ($incomplete,$complete, $loading, $submitted);

  return "INCOMPLETE" if (! $self->exp_condition);

  my @ams = $self->arraymeasurements;
  foreach (@ams)
  {
    my $status = $_->status;
    $submitted++ if $status eq "SUBMITTED";
    $complete++ if $status eq "COMPLETE";
    $loading++ if $status eq "LOADING IN PROGRESS";
    $incomplete++ and last if $status eq "INCOMPLETE";
  }
  return "INCOMPLETE" if $incomplete || @ams == 0;
  return "LOADING IN PROGRESS" if $loading;
  return "SUBMITTED" if $submitted;
  return "COMPLETE" if $complete;
  return "LOADED";
}

sub layout {
 my $self = shift; 
 my $layout;
 
 foreach my $am ($self->arraymeasurements)
 {
   $layout = $am->layout if (! $layout); 
   warn "Sample contains different chip types" 
     if ($layout->pk ne $am->layout->pk);
 }
 return $layout; 
}

sub add_arraymeasurements {
  my $self = shift;
  my $num = shift;

  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "ERROR_CANT_MODIFY_LOADED", "sample " . $self->name) 
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));
  my @ams;
  my $layout = $self->layout? $self->layout->pk : $self->study->layout->pk;
  for (my $x = 0; $x < $num; $x++)
  {
    push @ams, GEOSS::Experiment::Arraymeasurement->insert(
        sample => $self->pk,
        layout => $layout,
        owner => $self->owner,
        group => $self->group,
        perms => $self->perms,
        );
  }
  return @ams;
}

sub arraymeasurements {
  my $self = shift;
  return GEOSS::Experiment::Arraymeasurement->new_list(sample => $self->pk);
}

sub lock {
  my $self = shift;

  foreach my $a ($self->arraymeasurements)
  {
    eval  { $a->lock };
    die if ($@);
  }

  my $q = GEOSS::Database::Select->new;
  $q->table('groupref');
  $q->field('permissions');
  $q->constraint(ref_fk => $self->pk);
  my $perms = ($dbh->selectrow_array($q->sql))[0];

  $q = GEOSS::Database::Update->new;
  $q->table('groupref');
  $q->set('permissions', $perms);
  $q->set('permissions', 288);
  $q->constraint(ref_fk => $self->pk);
  eval { $dbh->do($q->sql()) };
  if ($@)
  {
    GEOSS::Util::report_postgres_err($@);
    die GEOSS::Session->set_return_message("errmessage", "ERROR_LOCK",
        "sample " . $self);
  }
}

sub unlock {
  my $self = shift;

  foreach my $a ($self->arraymeasurements)
  {
    eval  { $a->unlock };
    die if ($@);
  }

  my $q = GEOSS::Database::Select->new;
  $q->table('groupref');
  $q->field('old_permissions');
  $q->constraint(ref_fk => $self->pk);
  my $old_perms = ($dbh->selectrow_array($q->sql))[0];

  $q = GEOSS::Database::Update->new;
  $q->table('groupref');
  $q->set('permissions', $old_perms);
  $q->constraint(ref_fk => $self->pk);
  eval { $dbh->do($q->sql()) };
  if ($@)
  {
    GEOSS::Util::report_postgres_err($@);
    die GEOSS::Session->set_return_message("errmessage", "ERROR_UNLOCK",
        "sample " . $self);
  }
}

sub assign_order {
  my $self = shift;
  my $order = shift;

  $self->update(order => $order->pk);
}

1;
