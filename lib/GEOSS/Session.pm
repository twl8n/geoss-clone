package GEOSS::Session;
use strict;
use GEOSS::Database;
use GEOSS::User::User;
use GEOSS::LazyValue;

require "geoss_session_lib";

my $url = '';
sub set_url { $url = shift; }

our $messages_to_db = 1;
our $web_us_fk_output = 1;

our $user;
tie $user, 'GEOSS::LazyValue', \&user;

sub user {
  $web_us_fk_output ?
    return GEOSS::User::User->new(pk => ::get_us_fk($dbh, $url)) :
    return "command";
}

sub set_return_message {
  my ($self, $key, $msgnum, @params) = @_;
  if ($messages_to_db)
  { 
    ::set_session_val($ses_dbh, $self->user->pk, "message", $key, ::get_message(
      $msgnum, @params));
    $ses_dbh->commit();
  }
  my $ret_string .= ::get_message_text($msgnum, @params);
  return ($ret_string);
}

1;
