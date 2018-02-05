
=head1 NAME
 
 geoss_rm_analysis - removes an analysis from the database

=head1 SYNOPSIS

 ./geoss_rm_analysis --analysis <analysis_name | an_pk | configfile_name>

=head1 DESCRIPTION

The geoss_rm_analysis is intended to remove an analysis from the database.
It will delete all records associated (via joins) to the specified analysis.

=cut

  use strict;
  use GEOSS::Database;
  use GEOSS::Terminal;
  use Getopt::Long 2.13;
  require "$LIB_DIR/geoss_session_lib";

  my $ana; my $stm;

  getOptions();

  if ($ana =~ /^[0-9]+$/)
  {
    $stm = "select an_pk from analysis where an_pk = '$ana'";
  }
  else
  {
	  if ($ana =~ /([^\/]*)\.cfg/)
	  {
		  $ana = $1;
	  }
    $stm= "select an_pk from analysis where an_name = '$ana'";
  }

  my $an_pk = $dbh->selectrow_array($stm);

  die "Error!  Unable to find analysis: $ana\n" if (!defined $an_pk);

  #TODO - move into a loop
  rm_extension($dbh, $an_pk);
  rm_filetypes($dbh, $an_pk);
  rm_analysis_filetypes_link($dbh, $an_pk);
  rm_sys_parameter_names($dbh, $an_pk);
  rm_user_parameter_names($dbh, $an_pk);
  rm_analysis($dbh, $an_pk);

  $dbh->disconnect(); 


### SUBROUTINES ###

sub rm_extension
{
  my ($dbh, $an_pk) = @_;

  my $stm = "select ext_pk from analysis, analysis_filetypes_link," .
    " filetypes, extension where extension.ft_fk = ft_pk and " .
    " ft_pk = analysis_filetypes_link.ft_fk and an_pk = " .
    " analysis_filetypes_link.an_fk and an_pk = '$an_pk'";
  my $sth = $dbh->prepare($stm);
  $sth->execute;

  while (my ($key) = $sth->fetchrow_array)
  {
    $dbh->do("delete from extension where ext_pk = '$key'");
  }
  $dbh->commit;
}

sub rm_filetypes
{
  my ($dbh, $an_pk) = @_;

  my $stm = "select ft_pk from analysis, analysis_filetypes_link, " .
    "filetypes where ft_pk = ".
    "analysis_filetypes_link.ft_fk and an_pk = " .
    "analysis_filetypes_link.an_fk and an_pk = '$an_pk'";
  my $sth = $dbh->prepare($stm);
  $sth->execute;

  while (my ($key) = $sth->fetchrow_array)
  {
    $dbh->do("delete from filetypes where ft_pk = '$key'");
  }
  $dbh->commit;
}

sub rm_analysis_filetypes_link
{
  my ($dbh, $an_pk) = @_;

  $dbh->do(
    "delete from analysis_filetypes_link where an_fk = '$an_pk'");
  $dbh->commit;
}

sub rm_user_parameter_names
{
  my ($dbh, $an_pk) = @_;

  $dbh->do(
    "delete from user_parameter_names where an_fk = '$an_pk'");
  $dbh->commit;
}

sub rm_sys_parameter_names
{
  my ($dbh, $an_pk) = @_;

  $dbh->do(
    "delete from sys_parameter_names where an_fk = '$an_pk'");
  $dbh->commit;
}

sub rm_analysis
{
  my ($dbh, $an_pk) = @_;

  $dbh->do(
    "delete from analysis where an_pk = '$an_pk'");
  $dbh->commit;
}

sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
      'analysis=s'  => \$ana,
      'help|?'      => \$help,
    );
  }
  usage() if $help;

  if ($ana eq "")
  {
    print "Must specify an analysis to delete.\n";
    usage() ;
  }
}

sub usage
{
      print "Usage: \n";
      print "./geoss_rm_analysis.pl --analysis <an_name | an_pk | configfile >\n";
      exit;
} # usage

=head1 NOTES


=head1 AUTHOR

Teela James
