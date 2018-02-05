package GEOSS::Analysis;
use strict;
use GEOSS::Database;
use GEOSS::Database::Object;
use GEOSS::Database::Iterator;
use GEOSS::Analysis::Filetype;
our @ISA = qw(GEOSS::Database::Object);

sub tables {
  return 'analysis';
}

sub fields {
  return (
    [pk => 'an_pk'],
    [name => 'an_name'],
    [cmd => 'cmdstr'],
    [version => 'version'],
    [current => 'current'],
    [type => 'an_type']
  );
}

sub pk { return shift->{pk} }
sub cmd { return shift->{cmd} }
sub name { return shift->{name} }
sub current { return shift->{current} }

sub current_version {
  my $self = shift;

  return $self if $self->{current};
  my $q = GEOSS::Database::Select->new;
  $q->table('analysis');
  $q->field('an_pk');
  $q->constraint(current => 1);
  $q->constraint(an_name => $self->name);
  my $an_pk =  ($dbh->selectrow_array($q->sql))[0];
  $an_pk ? GEOSS::Analysis->new(pk => $an_pk) : undef; 
}

sub files {
  my $self = shift;
  my @files;

  my $v = {analysis => $self->pk, @_};
  my $oi = GEOSS::Database::Iterator->new($v,
             [GEOSS::Analysis::Filetype::tables(), 'analysis_filetypes_link'],
             [GEOSS::Analysis::Filetype::fields(), 
               [analysis => 'an_fk'],
               [input => 'input']]);
  $oi->query->join('ft_fk', 'ft_pk');
  $oi->start();
  while($oi->fill_hashref($v)) {
    push @files, GEOSS::Analysis::Filetype->new(%$v);
  }

  return @files;
}

sub inputs { return shift->files(input => 't') }
sub outputs { return shift->files(input => 'f') }

sub sys_parameter_names {
  return 
    GEOSS::Analysis::SystemParameterName->new_list(analysis => shift->pk, @_);
}

sub user_parameter_names {
  return GEOSS::Analysis::UserParameterName->new_list(
            analysis => shift->pk, @_);
}

1;
