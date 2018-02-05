package GEOSS::Util;
use strict;
use GEOSS::BuildOptions;
use GEOSS::Database;
use base 'Exporter';
our @EXPORT;

push @EXPORT, 'slurp_file';
sub slurp_file {
  my $fn = shift;
  open(my $fh, '<', $fn)
    or die "unable to open $fn for reading: $!";
  local $/ = undef;
  return <$fh>;
}

sub versions {
  use IPC::Open2;
  my $r;

  $r .= "GEOSS version: $GEOSS::BuildOptions::VERSION\n";
  $r .= `uname -a`;
  $r .= `postmaster --version`;
  $r .= join("\n", grep { /^This is perl/ } `perl -v`);
  $r .= join("\n", grep { /^R version/ } `R --version`);

  open2(my $r_in, my $r_out, qw(R --no-save --no-restore));
  print $r_out '.libPaths()';
  close $r_out;
  my @paths;
  while(<$r_in>) {
    next if $_ !~ /\[\d+\] "(.*)"/;
    push @paths, $1;
  }

  foreach my $p (@paths)
  {
    my $dir;
    opendir ($dir, $p) or die "can't open $dir: $!";
    my $subdir;
    while ($subdir = readdir($dir))
    {
      if (-r "$p/$subdir/DESCRIPTION")
      {
        my $fh;
        open ($fh, "$p/$subdir/DESCRIPTION") 
          or die "can't open $p/$subdir/DESCRIPTION:$!";
        my $line;
        while ($line = <$fh>)
        {
          $r .= $line if ($line =~ s/^(Package: .*)\n/$1  /);
          if ($line =~ /^Version:/)
          {
            $r .= $line;
            last;
          }
        }
        close ($fh);
      }
    }
  }
  return $r;
}

sub unique {
  my $self = shift;
  my @in = @_;

  my %saw;
  @saw{@in} = ();
  return ( sort keys %saw );
}

sub report_postgres_err
{
  my $self = shift;
  my ($err) = @_;
  $err =~ /(ERROR.*)/;
  my $msg = $1;
  my $success = GEOSS::Session->set_return_message( "errmessage", 
      "ERROR_POSTGRES", $msg);
  return ($success);
}

