package GEOSS::Experiment::Study;
use strict;
use base 'GEOSS::Database::ControlledObject';
use File::Path;
use GEOSS::BuildOptions;
use GEOSS::Database;
use GEOSS::Database::Iterator;
use GEOSS::Experiment::ExpCondition;
use GEOSS::Experiment::Sample;
use GEOSS::Experiment::Arraymeasurement;
use GEOSS::Experiment::Arraylayout;

require 'geoss_session_lib';

sub tables {
  return qw(study);
}

sub fields {
  return (
    [pk => 'sty_pk'],
    [name => 'study_name'],
    [date => 'start_date'],
    [url => 'study_url'],
    [comments => 'sty_comments'],
    [creator => 'created_by'],
    [tree => 'tree_fk'],
    [abstract => 'study_abstract'],
    [exp_cond_name => 'default_exp_cond_name'],
    [species => 'default_spc_fk'],
    [sample_type => 'default_sample_type'],
    [type_details => 'default_type_details'],
    [bio_reps => 'default_bio_reps'],
    [chip_reps => 'default_chip_reps'],
    [sample_name => 'default_smp_name'],
    [lab_book => 'default_lab_book'],
    [lab_book_owner => 'default_lab_book_owner'],
    [sample_origin => 'default_smp_origin'],
    [sample_manipulation => 'default_smp_manipulation'],
    [layout => 'default_al_fk'],
  );
}

sub pk { return shift->{pk} }
sub name { return shift->{name} }
sub layout { return GEOSS::Experiment::Arraylayout->new(pk => 
    shift->{layout} )}
sub disease { return shift->{disease} }
sub comments { return shift->{comments} }
sub date { return shift->{date} }

sub update {
  my $self = shift;
  my %new = @_;

  my $status = $self->status;
  if ((($status eq "LOADED") || ($status eq "LOADING IN PROGRESS")) &&
     ((exists $new{name}) && ($new{name} ne $self->name)))
  {
    die GEOSS::Session->set_return_message(
     "errmessage", "ERROR_NAME_CHANGE_LOADED", $self->name); 
  }
  else
  {
    $self->SUPER::update(@_);
  }
} 

sub info {
  my $self = shift;

  my %info = %$self;

  $info{owner} = $self->owner;
  $info{group} = $self->group;
  $info{exp_conditions} = [$self->exp_conditions];
  $info{status} = $self->status;
  $info{disease} = ::getq_dis_fk_by_sty_fk($self->pk); 
  return \%info;

}

sub status {
  my $self = shift;
  my ($incomplete, $complete, $loading);
  return "INCOMPLETE" if (! $self->name); 
  my @ecs = $self->exp_conditions;
  foreach (@ecs)
  {
    my $status = $_->status;
    $incomplete++ and last if $status eq "INCOMPLETE";
    $loading++ if $status eq "LOADING IN PROGRESS";
    $complete++ if $status eq "COMPLETE";
  }
  
  return "INCOMPLETE" if $incomplete || @ecs == 0;
  return "LOADING IN PROGRESS" if $loading;
  return "COMPLETE" if $complete;
  return "LOADED"; 
}


sub check_mandatory_fields {
  my $self = shift;
  my @ecs = $self->exp_conditions;
  foreach (@ecs)
  {
    $_->check_mandatory_fields;
  }
}


sub exp_conditions {
  my $self = shift;
  return GEOSS::Experiment::ExpCondition->new_list(study => $self->pk);
}

sub samples {
  my $self = shift;
  return map {
    GEOSS::Experiment::Sample->new_list(exp_condition => $_->pk);
  } $self->exp_conditions;
}

sub arraymeasurements {
  my $self = shift;
  return map {
    GEOSS::Experiment::Arraymeasurement->new_list(sample => $_->pk)
  } $self->samples;
}

sub layouts {
  my $self = shift;
  my @pks = GEOSS::Util->unique (
      map { $_->layout->pk } $self->arraymeasurements);
  return map { GEOSS::Experiment::Arraylayout->new(pk => $_) } @pks;
}

sub verify_study_data_dir {
  my $self = shift;
  my $data_dir= shift;

  my $error;
  my $fh;

  my @hybs = $self->arraymeasurements;

  foreach my $hyb (@hybs)
  {
    my $hyb_name = $hyb->name;
    # verify appropriate files exists (txt)
    die "Hybrdization name unknown: $hyb" if ($hyb->name eq ""); 
    my @files = `find "$data_dir" -iname "$hyb_name.txt"`;
    my $file = $files[0]; chomp($file);
    if (! -e $file)
    {
      die GEOSS::Session->set_return_message(
        "errmessage", "ERROR_DATA_LOAD_NO_DATA_FILE", $file, $data_dir); 
    }
    # if an rpt file exists, verify the chip type
    my @files = `find "$data_dir" -iname "$hyb_name.rpt"`;
    my $file = $files[0]; chomp($file);
    if (! -e $file)
    {
      my $file_chip = ::get_file_chip($file);
      my $hyb_chip = $hyb->layout->name;

      if ($file_chip ne $hyb_chip)
      {
        die GEOSS::Session->set_return_message(
          "errmessage", "ERROR_CHIP_TYPE_FILE_MISMATCH", $hyb_chip,
          $file_chip);
      }
    }
  }
  return @hybs;
}

sub verify_study_data_file {
  my $self = shift;
  my $filename = shift;

  my $sty_path = "$GEOSS::BuildOptions::USER_DATA_DIR/" . 
    $self->owner->login() .  "/Data_Files/" . $self->{name};
  mkpath $sty_path, 0, 0770 or die "Unable to make $sty_path: $!" 
    if (! -e $sty_path);
  my $base = ::basename($filename);
  ::link_or_copy("$filename", "$sty_path/$base", 1)
     or die "Unable to link_or_copy $filename: $!"; 
  my $file = GEOSS::Fileinfo->update_or_insert(
      { name => "$sty_path/$base" },
      { owner => $self->owner,
        group => $self->group,
        perms => 288,}
      );
  my @hybs = $self->arraymeasurements;
  my %hybs;
  foreach my $h (@hybs)
  {
    $hybs{"$h->{name}"} = $h->{pk};
  }
  my @layouts = $self->layouts;
  my $spots = $layouts[0]->al_spots;
  die (GEOSS::Session->set_return_message(
      "errmessage", "ERROR_DATA_LOAD_MULT_CHIP_TYPE_SINGLE_FILE")) 
    if (@layouts > 1); 

  open(my $fh, $filename) or
    die (GEOSS::Session->set_return_message(
    "errmessage", "ERROR_FILE_OPEN", $filename . ":$!")); 

  chomp(my $line = <$fh>);
  $line =~ s/^Probesets\t//i or
  $line =~ s/^probe_set_name\t//i or
    die (GEOSS::Session->set_return_message(
            "errmessage", "ERROR_DATA_LOAD_PARSE", $filename)); 

  map {
      die (GEOSS::Session->set_return_message(
       "errmessage", "ERROR_DATA_LOAD_HYB_EXIST", $_, $filename))
        if (! $hybs{$_});
  } split /\s+/, $line;
  close($fh);
  return 0;
}

sub set_loading_flag {
  my $self = shift;
  my @hybs = $self->arraymeasurements;
  foreach my $hyb (@hybs)
  {
    my $status = $hyb->status;
    $hyb->set_loading_flag 
      if (($status ne "LOADED") && ($status ne "LOADING IN PROGRESS"));
  }
  # the purpose of this flag is to indicate that a load has started,
  # so we need to commit this change
}

sub clear_loading_flag {
  my $self = shift;
  my @hybs = $self->arraymeasurements;
  foreach my $hyb (@hybs)
  {
    my $status = $hyb->status;
    $hyb->clear_loading_flag
      if (($status ne "LOADED") && ($status ne "LOADING IN PROGRESS"));
  }
  # the purpose of this flag is to indicate that a load has started,
  # so we need to commit this change
}

sub load_from_directory {
  my $self = shift;
  my $dirname = shift;
  my $verified = shift;
  my $error;

  my $status = $self->status;
  die (GEOSS::Session->set_return_message(
    "errmessage", "ERROR_DATA_LOAD", 
    "$self status ($status) must be COMPLETE in order to load."))
     if (($status eq "INCOMPLETE") || ($status eq "LOADED"));

  my $sty_path = "$GEOSS::BuildOptions::USER_DATA_DIR/" . 
    $self->owner->login() .  "/Data_Files/" . $self->{name};
  mkpath $sty_path, 0770 or die "Unable to make $sty_path: $!" 
    if (! -e $sty_path);
  $self->verify_study_data_dir($dirname) if (! $verified);

  my $startdate = localtime();
  open (my $log, ">", "$sty_path/load_log.txt") or
    die (GEOSS::Session->set_return_message(
    "errmessage", "ERROR_FILE_OPEN", $sty_path . "/load_log.txt" . ":$!")); 
  print $log "Data load for " . $self->name . " starts running: $startdate\n";

  my @hybs = $self->arraymeasurements();

  my $us_fk = GEOSS::Session->user;
  foreach my $h (@hybs)
  {
    my $hyb_name = $h->name;
    my %files;
    foreach my $ext (qw(txt dtt cab cel dat chp exp rpt))
    {
      my @files = `find "$dirname" -iname "$hyb_name.${ext}"`;
      chomp(@files);
      die "Ambiguous load file for $ext extension in $dirname" 
        if ((@files > 1) && ($ext ne "cab") && ($ext ne "dtt"));
      foreach my $f (@files)
      {
        ::link_or_copy("$f", "$sty_path/$hyb_name.${ext}", 1);
        GEOSS::Fileinfo->update_or_insert(
          { name => "$sty_path/$hyb_name.${ext}" },
          { owner => $self->owner,
            group => $self->group,
            perms => 288,}
            );
        $files{$ext} = "$sty_path/$hyb_name.${ext}"; 
      }
    }   
    if ($files{rpt})
    {
      my %qc = ::parse_rpt($files{'rpt'}) if ($files{'rpt'});
      ::insert_qc($dbh, $h->pk, \%qc);
    }
    if ($files{'exp'})
    {
      my $lot_number = ::get_lot_number($dbh, $us_fk, $files{'exp'}, 
          $files{'txt'});
      ::doq_update_lot_number($dbh, $us_fk, $h->pk, $lot_number)
        if $lot_number;
    } 


    my $success = ::insert_txt_data($dbh, $us_fk, $files{'txt'},
      $h->pk, $h->layout->pk, $log);
    print $log "Load for $h completed at " . localtime() . "\n";
    if ($success != 1)
    {
        # set all the messges stored in success
        # we assume messages are stored as ##m followed by an optional param
        # : separates messages
      my $success2;
      foreach (split(/:/, $success))
      {
        /(\d+m)(.*)/;
        $success2 .= GEOSS::Session->set_return_message(
          "errmessage", "$1", "$2");
      }
      $success2 .= GEOSS::Session->set_return_message(
        "errmessage", "ERROR_DATA_LOAD");
      return $success2;
    }
    else
    {
# XXX the update function doesn't handle literal values that should not
# be quoted (like now()).
    $dbh->do('update arraymeasurement set date_loaded=now() where am_pk='
        . $h->pk);
    }
  }
  GEOSS::Fileinfo->update_or_insert(
     { name => "$sty_path/load_log.txt" },
     { owner => $self->owner,
       group => $self->group,
       perms => 288,}
     );
  
  return 1;
}

sub load_from_file {
  my $self = shift;
  my $filename = shift;
  my $verified = shift;
  my $error;

  my $status = $self->status;
  die (GEOSS::Session->set_return_message(
    "errmessage", "ERROR_DATA_LOAD", 
    "$self status ($status) must be COMPLETE in order to load."))
     if (($status eq "INCOMPLETE") || ($status eq "LOADED"));

  $self->verify_study_data_file($filename) if (! $verified);

  my $chip = ($self->layouts)[0];
  my $spots = $chip->al_spots;
  my @hybs = $self->arraymeasurements;

  my $sty_path = "$GEOSS::BuildOptions::USER_DATA_DIR/" . 
    $self->owner->login() .  "/Data_Files/" . $self->{name};
  mkpath $sty_path, 0770 or die "Unable to make $sty_path: $!" 
    if (! -e $sty_path);
  my $startdate = localtime();
  open (my $log, "> $sty_path/load_log.txt") or
    die (GEOSS::Session->set_return_message(
    "errmessage", "ERROR_FILE_OPEN", "$sty_path/load_log.txt :$!")); 
  print $log "Data load for " . $self->name . " starts running: $startdate\n";

  open(my $fh, $filename) or
    die (GEOSS::Session->set_return_message(
    "errmessage", "ERROR_FILE_OPEN", $filename . ":$!")); 

  my $line = <$fh>; # strip the header line
  my $linecount = 1;
  while ($line = <$fh>)
  {
    $linecount++;
    print $log "Loading data.  Done $linecount lines.\n" 
      if ($linecount % 1000 == 0);
    chomp($line);
    next unless length($line);

    my ($probeset, @signals) = split /\s+/, $line;
    if (@signals != @hybs)
    {
       die (GEOSS::Session->set_return_message(
          "errmessage", "ERROR_DATA_LOAD_INVALID_ROW", $linecount,
          "Number of data columns does not match number of hybridizations.")); 
    }
    exists($spots->{$probeset}) or 
      die (GEOSS::Session->set_return_message(
        "errmessage", "ERROR_DATA_LOAD_INVALID_ROW", $linecount,
        "unknown probeset ($probeset) for chip $chip"));

    my $als = $spots->{$probeset};
    foreach my $i (0 .. $#signals) {
      my $error = $hybs[$i]->set_measurement($als, $signals[$i]);
      die (GEOSS::Session->set_return_message(
        "errmessage", "ERROR_DATA_LOAD_INVALID_ROW", $linecount,
        "Unable to set signal value.")) if ($error);
    }
  }
  print $log "Spots loaded.  Setting date_loaded field for hybridizations.\n";
  foreach (@hybs) {
# XXX the update function doesn't handle literal values that should not
# be quoted (like now()).
    $dbh->do('update arraymeasurement set date_loaded=now() where am_pk='
        . $_->pk);
  };

  my $stopdate = localtime();
  print $log "Load completed at $stopdate\n";
  close($fh);
  close($log);
  GEOSS::Fileinfo->update_or_insert(
     { name => "$sty_path/load_log.txt" },
     { owner => $self->owner,
       group => $self->group,
       perms => 288,}
     );
  
  return 1;
}

sub add_exp_condition {
  my $self = shift;
  my $num = shift;

  my %defaults;
  $defaults{name} = $self->{exp_cond_name} ? $self->{exp_cond_name} : "";
  $defaults{type} = $self->{sample_type} if $self->{sample_type};
  $defaults{cell_line} = $self->{default_type_details}
    if (($defaults{type} eq "cells") && ($self->{default_type_details}));
  $defaults{tissue_type} = $self->{default_type_details}
    if (($defaults{type} eq "tissue") && ($self->{default_type_details}));
  $defaults{species} = $self->{species} ? $self->{species} : undef;
  
  my @ecs;
  for (my $x=0; $x<$num; $x++)
  {
    my $ec =  GEOSS::Experiment::ExpCondition->insert(
          study => $self->pk,
          owner => $self->owner,
          group => $self->group,
          perms => $self->perms,
          %defaults
        );
    $ec->add_samples($self->{bio_reps});
    push @ecs, $ec;
  }
}

sub delete
{
  my $self = shift;
  my $status = $self->status;
  die GEOSS::Session->set_return_message("errmessage",
      "CANT_DELETE_LOADED", "Study " . $self->name)
    if (($status eq "LOADED") || ($status eq "LOADING IN PROGRESS"));

  foreach my $ec ($self->exp_conditions)
  {
    $ec->delete;
  }
  $self->SUPER::delete(@_);
}

sub assign_order {
  my $self = shift;
  my $order = shift;

  foreach my $s ($self->samples)
  { 
    $s->assign_order($order) 
  }
}

1;
