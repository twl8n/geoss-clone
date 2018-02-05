package GEOSS::Arraycenter::Order;
use strict;
use base 'GEOSS::Database::ControlledObject';
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;
use GEOSS::Experiment::Sample;
use GEOSS::Arraycenter::Organization;

sub tables {
  return 'order_info';
}

sub fields {
  return (
    [pk => 'oi_pk'],
    [name => 'order_number'],
    [locked => 'locked'],
    [organization => 'org_fk'],
    [approved => 'is_approved'],
    [approval_date => 'approval_date'],
    [created_by => 'created_by'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub locked { return shift->{locked} }
sub approved { return shift->{approved} }
sub approval_date { return shift->{approval_date} }
sub created_by { return shift->{created_by} }
sub organization { return 
  GEOSS::Arraycenter::Organization->new(pk => shift->{organization} )}

sub unlock {
  my $self = shift;

  foreach my $s ($self->samples)
  {
    eval  { $s->unlock };
    if ($@)
    {
      GEOSS::Session->set_return_message("errmessage", "ERROR_UNLOCK_ORDER", 
        $self);
      die; 
    };
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
    GEOSS::Session->set_return_message("errmessage", "ERROR_UNLOCK", 
     "order " . $self); 
  }
  else
  {
    eval { $self->update( locked => undef) };
    die GEOSS::Session->set_return_message("errmessage", "ERROR_UNLOCK", 
       "order " . $self) if ($@);
  }
}

sub lock {
  my $self = shift;

  foreach my $s ($self->samples)
  {
    eval  { $s->unlock };
    die if ($@);
  }

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
    GEOSS::Session->set_return_message("errmessage", "ERROR_LOCK", 
     "order " . $self); 
    die;
  }
  else
  {
    eval { $self->update( locked => 't') };
    die GEOSS::Session->set_return_message("errmessage", "ERROR_LOCK", 
     "order " . $self) if ($@);
  }
}

sub billing_code {
  my $self = shift;
  
  my $q = GEOSS::Database::Select->new;
  $q->table('billing');
  $q->field('billing_code');
  $q->constraint(oi_fk => $self->pk);

  return ($dbh->selectrow_array($q->sql))[0];
}

sub delete {
  my $self = shift;

  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage", "CANT_DELETE",
      $self, "The order status ($status) is LOADED or LOADING IN PROGRESS")
    if ($status eq "LOADED") || ($status eq "LOADING IN PROGRESS");
 
  my $locked = $self->locked;
  $self->unlock if $locked;
  foreach my $s ($self->samples)
  {
    eval { $s->update(order => undef) };
    if ($@)
    {
      $self->lock if $locked;
      GEOSS::set_return_message("errmessage", "CANT_DELETE", $self, 
        "Unable to delete billing information.");
      die;
    }
  }
  my $q = GEOSS::Database::Delete->new;
  $q->table('billing');
  $q->constraint(oi_fk => $self->pk);
  eval { $dbh->do($q->sql) };
  my $rows;
  if ($@)
  {
    $self->lock if $locked;
    GEOSS::Util::report_postgres_err($@);
    GEOSS::set_return_message("errmessage", "CANT_DELETE", $self, 
        "Unable to delete billing information.");
    die;
  }
  else 
  {
    eval { $rows = $self->SUPER::delete(@_) };
    if ($@)
    {
      $self->lock if $locked;
      GEOSS::set_return_message("errmessage", "CANT_DELETE", $self, 
        "Unable to delete billing information.");
      die;
    }
  }
  return $rows;
}

sub insert {
  my $self = shift;
  
  my %params = @_;
  my $billing_code = delete $params{billing_code};
  @_ = %params;

  my $order = $self->SUPER::insert(@_);

  my $q = GEOSS::Database::Insert->new;
  $q->table('billing');
  $q->set(oi_fk => $order->pk);
  $q->set(billing_code => $billing_code);
  my $sth = $dbh->prepare($q->sql);
  $sth->execute(); 
  return ($order);
}

sub status {
  my $self = shift;
  my ($incomplete, $complete, $loaded, $loading);

  my @smps = $self->samples;
  my $num_smps = @smps;
  return "INCOMPLETE" if $num_smps == 0;
  foreach (@smps)
  {
    my $status = $_->status;
    $incomplete++ and last if $status eq "INCOMPLETE";
    $complete++  if $status eq "COMPLETE";
    $loading++ if $status eq "LOADING IN PROGRESS";
    $loaded++ if $status eq "LOADED";
  }
  return "LOADED" if ($loaded == $num_smps); 
  return "LOADING IN PROGRESS" if $loading;
  return "APPROVED" if $self->{approved};
  return "SUBMITTTED" if $self->{locked};
  return "INCOMPLETE" if $incomplete;
  return "COMPLETE";
}

sub samples {
  my $self = shift;
  return GEOSS::Experiment::Sample->new_list(order => $self->pk);
}

sub study {
  my $self = shift;
  
  my $q = GEOSS::Database::Select->new;
  $q->table('sample','exp_condition');
  $q->field('sty_fk');
  $q->constraint('oi_fk' => $self->pk);
  $q->join('ec_pk' => 'ec_fk');
 
  return GEOSS::Experiment::Study->new(
      pk => ($dbh->selectrow_array($q->sql))[0] ); 
}
1;
