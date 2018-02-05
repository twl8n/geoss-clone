package GEOSS::Experiment::Arraymeasurement;
use strict;
use base 'GEOSS::Database::ControlledObject';
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;
use GEOSS::Util;
use GEOSS::Experiment::Arraylayout;

sub tables {
  return 'arraymeasurement';
}

sub fields {
  return (
    [pk => 'am_pk'],
    [name => 'hybridization_name'],
    [description => 'description'],
    [layout => 'al_fk'],
    [submission_date => 'submission_date'],
    [comments => 'am_comments'],
    [sample => 'smp_fk'],
    [quality_control => 'am_pk'],
    [is_loaded => 'is_loaded'],
    [date_loaded => 'date_loaded'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub sample { return GEOSS::Experiment::Sample->new(pk => shift->{sample}) }
sub is_loaded { return shift->{is_loaded} }
sub date_loaded { return shift->{date_loaded} }
sub layout { return GEOSS::Experiment::Arraylayout->new(pk => 
    shift->{layout}) }

sub set_loading_flag {
  my $self = shift;
  $self->update( is_loaded => 't');
}

sub clear_loading_flag {
  my $self = shift;
  $self->update( is_loaded => undef, );
}

sub check_mandatory_fields {
  my $self = shift;

  GEOSS::Session->set_return_message("errmessage", "FIELD_MANDATORY",
    "Chip name") if (! $self->layout);
}

sub status {
  my $self = shift;

  return "LOADING IN PROGRESS" 
    if (($self->is_loaded) && (!  $self->date_loaded));
  return "LOADED" if $self->date_loaded;
  return "SUBMITTED" 
    if (($self->sample->order) && ($self->sample->order->locked));
  return "COMPLETE" if $self->layout;
  return "INCOMPLETE";
}

sub delete {
  my $self = shift;

  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "CANT_DELETE_LOADED", "Arraymeasurement " . $self->name)
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));
  die GEOSS::Session->set_return_message("errmessage",
    "CANT_DELETE_LOCKED", "Arraymeasurement " . $self->name)
    if (($status eq "SUBMITTED"));
  $self->SUPER::delete(@_);
}

sub update {
  my $self = shift;

  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
    "ERROR_CANT_MODIFY_LOADED", "hybridization " . $self->name)
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));
  $self->SUPER::update(@_);
}

sub in_study {
  my $self = shift;
  my $study = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('exp_condition', 'sample');
  $q->field('count(sty_fk)');
  $q->constraint(smp_pk => $self->sample->pk);
  $q->constraint(sty_fk => $study->pk);
  $q->join(ec_pk => 'ec_fk');
 
  return ($dbh->selectrow_array($q->sql))[0]; 
}

sub set_measurement {
  my $self = shift;
  my @fields = qw(als_fk signal statpairs statpairsused detection detectionp);

  if(!$self->{am_spots_sth}) {
    my $q = GEOSS::Database::Insert->new;
    $q->table('am_spots_mas5');
    $q->set(am_fk => $self->pk);
    $q->set_placeholder(@fields);
    $self->{am_spots_sth} = $dbh->prepare($q);
  }
  $_[1] = undef if ($_[1] =~ /^null$/i);
  # DBI insists that we pad out the undefs ourselves
  foreach my $i (@_ .. $#fields) { push @_, undef }
  eval {
    $self->{am_spots_sth}->execute(@_);
  };
  if ($@)
  {
    return(GEOSS::Util::report_postgres_err($@));
  }
  return 0;
}

sub unlock {
  my $self = shift;

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
    die GEOSS::set_return_message("errmessage", "ERROR_UNLOCK", $self->name);
  }
}

sub lock {
  my $self = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('groupref');
  $q->field('permissions');
  $q->constraint(ref_fk => $self->pk);
  my $perms = ($dbh->selectrow_array($q->sql))[0];

  $q = GEOSS::Database::Update->new;
  $q->table('groupref');
  $q->set('old_permissions', $perms);
  $q->set('permissions', 288);
  $q->constraint(ref_fk => $self->pk);
  eval { $dbh->do($q->sql()) };
  if ($@)
  {
    GEOSS::Util::report_postgres_err($@);
    die GEOSS::set_return_message("errmessage", "ERROR_LOCK", $self->name);
  }
}

1;
