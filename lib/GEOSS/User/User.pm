package GEOSS::User::User;
use strict;
require 'geoss_sql_lib';
use base 'GEOSS::Database::Object';
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;

sub tables {
  return ('usersec', 'contact');
}

sub fields {
  return (
    [pk => 'us_pk'],  #con_pk and us_pk are always the same
    [login => 'login'],
    [type => 'type'],
    [first_name => 'contact_fname'],
    [last_name => 'contact_lname'],
    [phone => 'contact_phone'],
  );
}

sub join {
  return (
    [qw(us_pk con_pk)]
  );
}

sub pk { return shift->{pk} }
sub login { return shift->{login} }
sub email { return ::doq_get_email($dbh, shift->{pk}) }
sub type { return shift->{type} }
sub first_name { return shift->{first_name} }
sub last_name { return shift->{last_name} }
sub phone { return shift->{phone} }

sub name {
 my $self = shift;
 return $self->first_name . " " .$self->last_name; 
}

sub as_string {
  my $self = shift;
  return "$self->{login}($self->{pk})";
}

sub is_pi {
  my $self = shift;
  my $q = GEOSS::Database::Select->new;
  $q->table('pi_sec');
  $q->field('pi_key');
  $q->constraint(pi_key => $self->pk);
  return ($dbh->selectrow_array($q->sql))[0];
}

sub groups {
  my $self = shift;

  my $q = GEOSS::Database::Select->new;
  $q->table('grouplink');
  $q->field('gs_fk');
  $q->constraint(us_fk => $self->pk);

  my $sth = $dbh->prepare($q->sql);
  $sth->execute();

  my @gs_pks;
  while ((my $gs_pk) = $sth->fetchrow_array())
  {
    push @gs_pks, $gs_pk;
  }
  return map {
    GEOSS::User::Group->new(pk => $_); 
  } @gs_pks;
}

sub send_email {
  my $self = shift;
  my $subject = shift;
  my $content = shift;

  my $safe_email = quotemeta($self->email);
  open (my $mail, "| mail -s \"$subject\" $safe_email")
    or warn "Can't send mail ($subject) to $safe_email :$!";
  print $mail $content;
  close ($mail) or warn "Error sending ($subject) mail to $safe_email :$!";
}
1;
