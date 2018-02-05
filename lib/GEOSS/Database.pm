package GEOSS::Database;
use strict;
use DBI;
use Carp;
use GEOSS::LazyValue;
use GEOSS::DebugProxy;
use GEOSS::BuildOptions;
use Memoize;
use base 'Exporter';
our @EXPORT = qw($dbh $ses_dbh);

our $dbh;
tie $dbh, 'GEOSS::LazyValue', \&new_connection;
our $ses_dbh;
tie $ses_dbh, 'GEOSS::LazyValue', \&new_connection;

our $ignore_security = 0;

our $automatic_password = \&password;
sub new_connection {
  my $dbh = DBI->connect(
      "dbi:$DBMS:dbname=$DB_NAME;host=$HOST;port=$PORT",
      $SU_USER,
      $automatic_password->(),
      {
        AutoCommit => 0,
        HandleError => sub { die shift },
        ShowErrorStatement => 1
      });
  $dbh->{HandleError} = sub { 
    confess shift;
    $dbh->set_err(0,"")
  };
  if($GEOSS::BuildOptions::SQL_DEBUG || $ENV{GEOSS_SQL_DEBUG}) {
    $dbh = GEOSS::DebugProxy->new($dbh);
  }
  return $dbh;
}

memoize('password');
sub password {
  use IO::File;
  my $fn = $GEOSS::BuildOptions::WEB_DIR . '/.geoss';
  my $fh = IO::File->new($fn, 'r')
    or die "unable to open $fn: $!";
  my $password = $fh->getline;
  chomp($password);
  return $password;
}

1;
