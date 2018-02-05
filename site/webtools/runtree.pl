#TODO - change to accomodate version number as part of name

=head1 NAME
  
runtree - initiates execution of an analysis tree stored in the db

=head1 SYNOPSIS

./runtree.cgi  --tree <tree pk or tree name> [--node <node_pk>]
   
=head1 DESCRIPTION
  
This script is intended for use as part of the geoss system.  It 
will select a tree structure from the database and initiate 
running of each tree node.
  
Specifying a node means the tree runs from that node down.
Log files are created for each node in the users directory.    
    
=cut
    
use strict;
use DBI;

use Getopt::Long 2.13;
use GEOSS::Database;
use GEOSS::Session;
use GEOSS::Util;
use GEOSS::Analysis::NodeNamer;
use GEOSS::Analysis::Tree;
use GEOSS::Analysis::Filetype;
require "$LIB_DIR/geoss_session_lib";

{
  my $tree_id;
  my $help;
  my $node_id;

  GetOptions(
    'tree=s' => \$tree_id,
    'node=s' => \$node_id,
    'help|?' => \$help,
  );

  $help and usage();
  $tree_id or usage();

  GEOSS::Session::set_url("webtools/runtree.cgi");

  warn "Running runtree with tree_id $tree_id";
  my $tree = GEOSS::Analysis::Tree->new_from_id($tree_id);
  warn "tree is $tree";
  $tree or die "tree $tree_id doesn't exist in db";
  warn "Checking extraction";
  check_tree_extraction($tree);

  use File::Path;
  warn "Making " . $tree->path;
  mkpath($tree->path(), 0, 0770);

  my $node;
  if($node_id) {
    $node = GEOSS::Analysis::Node->new(pk => $node_id);
    $node->is_in_tree($tree) or die "node $node does not exist in tree $tree";
    if(!possibleNodeInputs($tree, $node)) {
      $node = $tree->root;
    }
  }
  else {
    $node = $tree->root;
  }

  my $systemParams = setSystemParams($tree);
  my $names = GEOSS::Analysis::NodeNamer->new($tree);

  write_geoss_version_file($tree->path);
  warn "Running tree";
  my @status = runNodeRecur($tree, $node, $systemParams, $names);
  emailNotify($tree, $systemParams, $names, @status);
}
exit 0;

sub usage
{
      print STDERR "Usage:\n";
      print STDERR 
          "  ./runTree --tree=<tree pk or tree name> [--node=<node_pk>]\n";   
      exit 1;
} # usage

sub setSystemParams {
  my $tree = shift;
  my %r;

  $r{'--email'} = $GEOSS::Session::user->email();

  my $fi = $tree->input();
  $r{'--settings conds'} = $fi->conds();
  $r{'--settings condLabels'} = $fi->cond_labels();
  $r{'--settings chipType'} = $fi->layout->name();

  $r{'--URI'} = index_url($dbh) 
                  . '/files2.cgi?submit_analysis=1&analysis='
                  . $tree->name();
  $r{'--settings path'} = $tree->path();

  return \%r;
}

sub runNodeRecur {
  my $tree = shift;
  my $node = shift;
  my $systemParams = shift;
  my $names = shift;
  my @r;

  my $old_stderr = redirect_io(*STDERR, nodeErrorFile($tree, $node, $names));
  my $old_stdout = redirect_io(*STDOUT, nodeDebugFile($tree, $node, $names));
  my $status = eval { runNode($tree, $node, $systemParams, $names) };
  if($@) {
    $dbh->rollback;
    print STDERR "An internal error occurred.\n";
    print STDERR $@;
    $status = 1;
  }
  restore_io(*STDOUT, $old_stdout);
  restore_io(*STDERR, $old_stderr);
  fi_update($dbh,
            $GEOSS::Session::user->pk, $GEOSS::Session::user->pk,
            nodeErrorFile($tree, $node, $names),
            "Error log for node $node",
            "", "", $node->pk(), 0, undef, 0, undef);

  push @r, [$node, $status];
  return @r unless $status == 0;

  foreach my $child ($node->children()) {
    push @r, runNodeRecur($tree, $child, $systemParams, $names);
  }

  return @r;
} # runNodeRecur

sub possibleNodeInputs {
  my $tree = shift;
  my $node = shift;

  my $parent = $node->parent();
  $parent or return ['--infile', $tree->input->name];

  return map {
    my $f = $parent->output_by_type($_);
    $f ? [$_->arg, $f->name] : ()
  } $node->analysis->inputs();
}

sub runNode {
  my $tree = shift;
  my $node = shift;
  my $systemParams = shift;
  my $names = shift;
  
  my @inputs = possibleNodeInputs($tree, $node);
  @inputs or die 'no input file found for ' . $names->name($node);
  @inputs > 1 and die 'too many possible inputs for ' .  $names->name($node);
  my ($infile_arg, $infile_value) = @{$inputs[0]};

  insertSysParams($tree, $node, 
      {%$systemParams, $infile_arg => $infile_value}, 
      $names);

  my %params;
  foreach my $upv ($node->user_parameter_values()) {
    my $upn = $upv->name();
    my $upt = $upn->type();
    my $v = $upv->value();
    $upn->name() =~ /file|out/i and
      $v = $tree->path() . '/' . $v;
    if ($upt eq "fileUpload")
    {
      if ($v)
      {
        my $file_info = GEOSS::Fileinfo->new(pk => $v);
        $v = $file_info->name();
        $params{$upn->name()} = $v;
      }
      else
      {
        $v = "";
      }
    }
    $params{$upn->name()} = $v;
  }
  foreach my $spv ($node->sys_parameter_values()) {
    my $spn = $spv->name();
    $params{$spn->name()} = $spv->value();
  }

  my $analysis = $node->analysis;
  my $cmd = join(' ',
                 'nice',
                 $analysis->cmd(),
                 (map { $_ . '=' . quotemeta($params{$_}) } keys(%params)));
  print STDOUT "runtree: CMD: $cmd\n";
  my $rc = system("exec $cmd");
  print STDOUT "runtree: CMDEXIT: $rc\n";
  $rc == -1 and die "unable to start node: $!";

  use POSIX qw(WIFSIGNALED WTERMSIG);
  WIFSIGNALED($rc) and die "Rwrapper died with signal " . WTERMSIG($rc);

  foreach my $output ($analysis->outputs()) {
    my ($ft, $use_as_input) = 
      $output->arg() eq '--outfile' ?
      ($output->pk(), 1) :
      (undef, 0);

    fi_update($dbh,
              $GEOSS::Session::user->pk,
              $GEOSS::Session::user->pk,
              $params{$output->arg()},
              "Output from node $node",
              $params{'--settings conds'},
              $params{'--settings condLabels'},
              $node->pk(),
              $use_as_input,
              $ft,
              0,
              $tree->input->layout->pk());
  }

  use POSIX qw(WIFEXITED WEXITSTATUS);
  return WIFEXITED($rc) ? WEXITSTATUS($rc) : 1;
} # runNode

sub insertSysParams {
  my $tree = shift;
  my $node = shift;
  my $systemParams = shift;
  my $names = shift;

  my $analysis = $node->analysis;

  foreach my $spn ($analysis->sys_parameter_names) {
    my $value;
    if(exists($systemParams->{$spn->name})) {
      $value = $systemParams->{$spn->name};
    } else {
      $value = $spn->default;
      $spn->name =~ /out/i and
        $value = canonicalFilename(
            $tree->path() . '/' . $names->name($node) . ' - ' . $value);
    }

    my ($ft) = $analysis->files(arg => $spn->name);
    if($ft) {
      my $ext = $ft->extension;
      my $upn = $analysis->user_parameter_names(name => $ext->extension);

      my $new_extension = 
        $upn ?
        $node->user_parameter_values(name => $upn->pk)->value :
        $ext->extension;
      $value =~ s/\.[^.]+$/.$new_extension/;
    }

    GEOSS::Analysis::SystemParameterValue->update_or_insert(
        { name => $spn->pk, node => $node->pk() },
        { value => $value });
  }

  $dbh->commit;
} #insertSysParams

sub nodeLogFile {
  my $type = shift;
  my $tree = shift;
  my $node = shift;
  my $names = shift;

  return canonicalFilename(
           $tree->path() . '/' . $names->name($node) . " - $type Log.txt");
}
sub nodeErrorFile { return nodeLogFile('Error', @_) }
sub nodeDebugFile { return nodeLogFile('Debug', @_) }

sub emailNotify {
  my $tree = shift;
  my $systemParams = shift;
  my $names = shift;

  my $failures = 0;
  foreach my $r (@_) {
    $failures++ unless $r->[1] == 0;
  }

  my $email = $systemParams->{"--email"};
  my $URI =  $systemParams->{"--URI"};
  
  my $mail;
  open($mail, 
    "| mail -s \"Statistical Analysis Complete\" " . quotemeta($email)) 
    or warn "Can't send mail to $email: $!\n";
  print $mail "Your analysis tree: $tree is complete.\n";
  $failures and print $mail "Some nodes did not run correctly.\n";
  foreach my $v (@_) {
    my ($node, $status) = @$v;
    if($status == 0) {
      print $mail $names->name($node) . ": SUCCESS\n";
    }
    else {
      print $mail $names->name($node) . ": FAILED\n";
      use IO::File;
      my $fh = IO::File->new(nodeErrorFile($tree, $node, $names));
      if($fh) {
        while(my $line = $fh->getline()) {
          print $mail '  ' . $line;
        }
      }
      else {
        print $mail '  [unable to retrieve error messages]';
      }
    }
  }
  print $mail "Result file(s) are at: $URI\n ";
  close ($mail);
  $? and warn "error sending mail to $email";
} # emailNotify

sub redirect_io {
  my $io = shift;
  my $to = shift;
  open(my $old, '>&', $io) or die "unable to dup $io: $!";
  open($io, '>', $to) or die "unable to redirect $io to $to: $!";
  return $old;
}

sub restore_io {
  my $io = shift;
  my $from = shift;
  open($io, '>&', $from) or die "unable to restore $io: $!";
}

sub check_tree_extraction {
  my $tree = shift;
  for(my $sanity = 0; $sanity < 100; $sanity++) {
    my $fi = $tree->input;
    return if($fi->input);
    sleep(10);
  }
  die "tree extraction failed to complete";
}

sub write_geoss_version_file {
  my $path = shift;
  my $fn = "$path/versions.txt";

  open(my $fh, '>', $fn)
    or die "unable to open $fn for writing: $!";
  print $fh GEOSS::Util::versions;
  close($fh);

  fi_update($dbh,
            $GEOSS::Session::user->pk, $GEOSS::Session::user->pk,
            $fn, "Versions at time of running tree",
            "", "", undef, 0, undef, 0, undef);
}
