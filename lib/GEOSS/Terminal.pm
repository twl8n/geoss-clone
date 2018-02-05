package GEOSS::Terminal;
use strict;
use GEOSS::Database;
use GEOSS::Session;
use base 'Exporter';
our @EXPORT;

$GEOSS::Database::ignore_security = 1;
$GEOSS::Session::messages_to_db = 0;
$GEOSS::Session::web_us_fk_output = 0;

push @EXPORT, 'ask_user';
sub ask_user {
  my $q = shift;
  my $hidden = shift;

  local $| = 1;
  print $q;
  $hidden and system("stty -echo");
  chomp(my $r = <STDIN>);
  $hidden and system("stty echo");
  return $r;
}

push @EXPORT, 'dbpass_from_user';
sub dbpass_from_user {
  return ask_user("Please enter the database access password:\n", 1);
}

$GEOSS::Database::automatic_password = \&dbpass_from_file_or_user;
push @EXPORT, 'dbpass_from_file_or_user';
sub dbpass_from_file_or_user {
  use GEOSS::Database;
  my $pass = eval { GEOSS::Database::password() };
  return $@ ? dbpass_from_user() : $pass;
}

1;
