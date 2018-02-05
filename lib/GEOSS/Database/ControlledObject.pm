package GEOSS::Database::ControlledObject;
use strict;
use base 'GEOSS::Database::Object';
use GEOSS::Database;
use GEOSS::Session;
use GEOSS::User::User;
use GEOSS::User::Group;
use GEOSS::Database::Delete;

sub _fixup_sql_select {
  my $class = shift;
  my $sql = shift;

  return if $GEOSS::Database::ignore_security;

  my ($pk) = ($class->fields)[0]->[1];
  my $user = $GEOSS::Session::user->pk;

  $sql->table(qw(groupref grouplink));
  $sql->constraint(<<EOF);
(groupref.ref_fk = $pk and (
  (grouplink.us_fk = $user and
   groupref.us_fk = grouplink.us_fk and
   grouplink.gs_fk = groupref.gs_fk and
   (groupref.permissions & 256) > 0
  ) or
  (groupref.gs_fk = grouplink.gs_fk and
   grouplink.us_fk = $user and
   (groupref.permissions & 32) > 0
  )
))
EOF
}

sub _fixup_sql_update { _add_sql_write_permissions(@_) }
sub _fixup_sql_delete { _add_sql_write_permissions(@_) }

sub _add_sql_write_permissions {
  my $class = shift;
  my $sql = shift;

  return if $GEOSS::Database::ignore_security;

  my ($pk) = ($class->fields)[0]->[1];
  my $user_pk = $GEOSS::Session::user->pk;

  $sql->constraint(<<EOF);
  (((select permissions from groupref where ref_fk = $pk and us_fk=$user_pk)
    & 128 > 0)
    or
  ((select permissions from groupref, grouplink where 
    groupref.gs_fk = grouplink.gs_fk and
    grouplink.us_fk = $user_pk and 
    ref_fk = $pk) & 16 > 0))
EOF
}

sub delete {
  my $self = shift;

  my $rows = $self->SUPER::delete(@_);

  if ($rows > 0)
  {
    my $q = GEOSS::Database::Delete->new;
    $q->table('groupref');
    $q->constraint(ref_fk => $self->pk);
    eval { $dbh->do($q->sql) };
    if ($@)
    {
      GEOSS::Util::report_postgres_err($@);
      die GEOSS::Session->set_return_message("errmessage", "CANT_DELETE",
        $self->pk, " from the groupref table");
    }
  }
  else
  {
    warn "Delete $self of self returned $rows rows.";
  }
  return ($rows);
}

sub insert {
  my $self = shift;

  my %params = @_;
  my $owner = delete $params{owner};
  my $group = delete $params{group};
  my $perms = (exists $params{perms}) ? delete $params{perms} : 416;
  @_ = %params;

  my $new = $self->SUPER::insert(@_);
  my $newid =
    $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'pk_seq'});
  $new->{pk} = $newid;
  my $q = GEOSS::Database::Insert->new;
  $q->table('groupref');
  $q->set(ref_fk => $newid);
  $q->set(permissions => $perms); 
  $q->set(us_fk => $owner->pk);
  $q->set(gs_fk => $group->pk);
  my $sth = $dbh->prepare($q->sql);
  $sth->execute();

  return($new);
}

sub update {
  my $self = shift;

  my %params = @_; my $owner = delete $params{owner};
  my $group = delete $params{group};
  my $perms = (exists $params{perms}) ? delete $params{perms} : undef;
  @_ = %params;

  my $new = $self->SUPER::update(@_);
  my $set;
  my $q = GEOSS::Database::Update->new;
  $q->table('groupref');
  $q->set(permissions => $perms) and $set = 1 if $perms; 
  $q->set(us_fk => $owner->pk) and $set = 1 if $owner;
  $q->set(gs_fk => $group->pk) and $set = 1 if $group;
  $q->constraint(ref_fk => $self->pk);
  if ($set)
  {
    my $sth = $dbh->prepare($q->sql);
    $sth->execute();
  }
  return($new);
}


sub can_write {
  my $self = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table($self->tables, 'groupref');
  $q->field(($self->fields)[0]->[1]);
  $q->constraint(ref_fk => $self->pk);
  $q->join(($self->fields)[0]->[1], 'ref_fk');
  $self->_add_sql_write_permissions($q);
  my ($pk) = $dbh->selectrow_array($q->sql);
  return ($pk);
}

sub perms {
  my $self = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('groupref');
  $q->field('permissions');
  $q->constraint(ref_fk => $self->pk);

  return ($dbh->selectrow_array($q->sql));
}

sub owner {
  my $self = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('groupref');
  $q->field('us_fk');
  $q->constraint(ref_fk => $self->pk);

  my ($pk) = $dbh->selectrow_array($q->sql);
  return GEOSS::User::User->new(pk => $pk);
}

sub group {
  my $self = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('groupref');
  $q->field('gs_fk');
  $q->constraint(ref_fk => $self->pk);

  my ($pk) = $dbh->selectrow_array($q->sql);
  return GEOSS::User::Group->new(pk => $pk);
}


1;
