use strict;
use CGI;
use GEOSS::Experiment::Study;
use GEOSS::User::User;
use GEOSS::Session;
use GEOSS::Species;
use GEOSS::Experiment::Arraylayout;
use GEOSS::Arraycenter::Order;

require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_analysis_lib";

my $q = new CGI;
my %ch = $q->Vars();
my $user = GEOSS::Session->user;

my $study;

if ($user->type eq "public")
{
  GEOSS::Session->set_return_message("errmessage", "INVALID_PERMS");
  my $url = index_url($dbh, "webtools");
  print "Location: $url\n\n";
  exit;
}
if ($ch{pk})
{
  $study = GEOSS::Experiment::Study->new(pk => $ch{pk});
}
if ($ch{submit} eq "Add Experimental Conditions")
{
  $ch{num_exp_conds} = $ch{num_exp_conds} > $ch{num_exp_conds2} ?
    $ch{num_exp_conds} : $ch{num_exp_conds2};
  if (($ch{num_exp_conds} < 1) || ($ch{num_exp_conds} > 99))
  {
    GEOSS::Session->set_return_message("errmessage",
        "INVALID_NUM_EXP_CONDS_ADD");
    %ch = (%ch, %{$study->info});
    draw_study($study, \%ch);
  }
  else
  {
    eval { $study = write_study($study, \%ch) } ;
    if (!$@)
    {
      $study->add_exp_condition($ch{num_exp_conds});
      delete($ch{num_exp_conds});
      %ch = (%ch, %{$study->info});
    }
    else
    {
      $dbh->rollback();
      warn "Failed to write_study: $@";
    }
    draw_study($study, \%ch);
  }
}
elsif ($ch{submit} eq "Save Study")
{
  eval { $study = write_study($study, \%ch) } ;
  if ($@)
  {
    warn "Bad return from write_study $@";
  }
  %ch = (%ch, %{$study->info});
  draw_study($study, \%ch);
}
elsif ($ch{submit} eq "Order Chips From Array Center")
{
  if (! get_config_entry($dbh, "array_center"))
  {
    GEOSS::Session->set_return_message("errmessage",
        "ERROR_ARRAY_CENTER_NOT_ENABLED");
    draw_study($study, \%ch);
  }
  else
  {
    eval { $study = write_study($study, \%ch) } ;
    if ($@)
    {
      warn "Bad return from write_study $@";
    }
    else
    {
      my $info = $study->info;
      if ($info->{status} ne "COMPLETE")
      {
        $study->check_mandatory_fields;
        GEOSS::Session->set_return_message("errmessage",
            "CANT_PLACE_ORDER_STUDY_NOT_COMPLETE", $info->{status});
        draw_study($study, $info);
      }
      else
      {
        draw_order_form($study, $info);
      }
    }
  }
}
elsif ($ch{submit} eq "Submit Order")
{
  my $info = $study->info;
  if (! get_config_entry($dbh, "array_center"))
  {
    GEOSS::Session->set_return_message("errmessage",
        "ERROR_ARRAY_CENTER_NOT_ENABLED");
    draw_study($study, \%ch);
  } 
  elsif ($info->{status} ne "COMPLETE")
  {
    GEOSS::Session->set_return_message("errmessage",
        "CANT_PLACE_ORDER_STUDY_NOT_COMPLETE", $info->status);
    draw_study($study, $info);
  }
  else
  {
    eval { order_chips($study, \%ch) };
    draw_order_form($study, $info) if ($@);
  }
}
else
{
  %ch = (%ch, %{$study->info}) if ($study);
  draw_study($study, \%ch);
}
$dbh->commit;
$dbh->disconnect;


sub write_study_exp_cond_info
{
  (my $study, my $chref) = @_;

  my @exp_conds = $study->exp_conditions;
  foreach my $ec (@exp_conds)
  {
    my $pk = $ec->pk;

# if we are supposed to delete this condition, delete and do nothing else
    if (exists $chref->{"exp_cond_delete_$pk"})
    {
      $ec->delete and next;
    }

# update the exp_condition fields as specified
    my %updates = ();
    $updates{name} = $chref->{"exp_name_$pk"} 
    if ((exists($chref->{"exp_name_$pk"})) && 
        ($chref->{"exp_name_$pk"} ne $ec->name));
    $updates{short_name} = $chref->{"short_name_$pk"} 
    if ((exists($chref->{"short_name_$pk"})) && 
        ($chref->{"short_name_$pk"} ne $ec->short_name));
    $updates{type} = $chref->{"sample_type_$pk"} 
    if ((exists($chref->{"sample_type_$pk"})) &&
        ( $chref->{"sample_type_$pk"} ne $ec->type));
    $updates{notes} = $chref->{"notes_$pk"} 
    if ((exists($chref->{"notes_$pk"})) &&
        ( $chref->{"notes_$pk"} ne $ec->notes));
    $updates{description} = $chref->{"description_$pk"} 
    if ((exists($chref->{"description_$pk"} )) &&
        ( $chref->{"description_$pk"} ne $ec->description));
    $updates{species} = $chref->{"species_$pk"} 
    if ((exists($chref->{"species_$pk"} )) &&
        ( $chref->{"species_$pk"} ne $ec->species));
    $ec->update(%updates) if (%updates);

# process all samples in the exp_condition
    my @smps = $ec->samples;
    my $smp_str;
    foreach my $smp (@smps)
    {
      my $smp_pk = $smp->pk; 
      $smp_str .= "$smp_pk,";

# delete the sample if specified
      if (exists $chref->{"smp_delete_$smp_pk"})
      {
        $smp->delete and next;
      }

# update the samples as specified
      %updates = ();
      $updates{name} = $chref->{"smp_name_$smp_pk"} 
      if ((exists($chref->{"smp_name_$smp_pk"} )) &&
          ($chref->{"smp_name_$smp_pk"} ne $smp->name));
      $updates{lab_book} = $chref->{"lab_book_$smp_pk"} 
      if ((exists($chref->{"lab_book_$smp_pk"} )) &&
          ($chref->{"lab_book_$smp_pk"} ne $smp->lab_book));
      $updates{origin} = $chref->{"origin_$smp_pk"} 
      if ((exists($chref->{"origin_$smp_pk"} )) &&
          ($chref->{"origin_$smp_pk"} ne $smp->origin));
      $updates{manipulation} = $chref->{"manipulation_$smp_pk"} 
      if ((exists($chref->{"manipulation_$smp_pk"} )) &&
          ($chref->{"manipulation_$smp_pk"} ne $smp->manipulation));
      $updates{lab_book_owner} = $chref->{"lab_book_owner_$smp_pk"} 
      if ((exists($chref->{"lab_book_owner_$smp_pk"} )) &&
          ($chref->{"lab_book_owner_$smp_pk"} ne $smp->lab_book_owner));

      $smp->update(%updates) if (%updates); 

# modify num  arraymeasurements if appropriate
      my @ams = $smp->arraymeasurements;
      my $num = @ams;

      if (exists $chref->{"smp_num_am_$smp_pk"})
      {
        if ($chref->{"smp_num_am_$smp_pk"} > @ams)
        {
          $smp->add_arraymeasurements($chref->{"smp_num_am_$smp_pk"} - @ams);
        }
        elsif ($chref->{"smp_num_am_$smp_pk"} < @ams)
        {
          for (my $x = @ams; $x > $chref->{"smp_num_am_$smp_pk"}; $x--)
          {
            my $ams = pop(@ams);
            $ams->delete;
          } 
        }
      }
      if ($chref->{"layout_$smp_pk"})
      {
        foreach my $am (@ams)
        {
          $am->update(layout => $chref->{"layout_$smp_pk"}) 
            if $chref->{"layout_$smp_pk"} != $am->layout->pk;
        }
      }

# add samples if required
      if ($chref->{"add_smp_$pk"})
      {
        foreach ($ec->add_samples($chref->{"add_smp_$pk"}))
        {
          $smp_str .= "$_,";
        }
        delete($chref->{"add_smp_$pk"});
      }
    }

    chop($smp_str);
    update_hn($smp_str) if ($ec->status eq "COMPLETE");
  }
} 

sub write_study
{
  (my $study, my $chref) = @_;
  die GEOSS::Session->set_return_message("errmessage",
      "ERROR_SAMPLES_PER_CONDITION_INVALID") if (! $chref->{bio_reps} > 0);
  die GEOSS::Session->set_return_message("errmessage",
      "ERROR_CHIPS_PER_SAMPLE_INVALID") if (! $chref->{chip_reps} > 0);
  die GEOSS::Session->set_return_message("errmessage",
      "NAME_CANT_BE_BLANK") if ($chref->{name} eq "");
  die GEOSS::Session->set_return_message("errmessage",
      "BAD_DATE_FORMAT") if (($chref->{start_date}) &&
        ($chref->{start_date} !~ /^(\d\d\d\d)-(\d\d?)-(\d\d?)$/));

  my $created = 0;
  if (! $study)
  {
    die GEOSS::Session->set_return_message("errmessage",
        "NAME_MUST_BE_UNIQUE") 
      if GEOSS::Experiment::Study->new(name => $chref->{name});

    my ($owner, $group) = split(',', $chref->{pi_info});
    $owner = GEOSS::User::User->new(pk => $owner);
    $group = GEOSS::User::User->new(pk => $group);
    eval { $study = GEOSS::Experiment::Study->insert(
        name => $chref->{name},
        comments => $chref->{comments},
        owner => $owner,
        group => $group,
        perms => 432,
        )
    };
    if ($@)
    {
      $dbh->rollback;
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_UNABLE_TO_CREATE", "study");
    }
    else
    {
      $created=1;
    }
  }

  if ($study)
  {
    my %updates;
    foreach my $u (qw (name comments date species exp_cond_name
          sample_name sample_type sample_origin sample_manipulation
          lab_book lab_book_owner layout bio_reps chip_reps))
    {
      $updates{$u} = $chref->{$u} if (exists $chref->{$u});
    }
    foreach my $u (qw (lab_book_owner date))
    {
      delete $updates{$u} if (! $updates{$u});
    }
    if (%updates)
    {
      eval { $study->update( %updates ) };
      if (! $@)
      {
        associate_study_disease($dbh, $study->pk, $chref->{classification})
          if ($chref->{classification});
        if (! $created)
        {
          write_study_exp_cond_info($study, $chref);
        }
        GEOSS::Session->set_return_message("goodmessage",
            "SUCCESS_STUDY_CREATED", $chref->{study_name}) if ($created);
      }
      else
      {
        $dbh->rollback;
        die;
      }
    }
  }
  return $study;
} 

  sub draw_order_form
  {
    my ($study, $chref) = @_;


    $chref->{htmltitle} = "Order Chips";
    $chref->{htmldescription} = "Use this for to order chips from the array
      center.";
    $chref->{help} = set_help_url($dbh,
        "edit_or_delete_an_existing_array_study");

    $chref->{user_pi} = user_pi();
    my $us_fk = GEOSS::Session->user->pk;
    $chref->{select_org} = select_org($dbh, $us_fk);

    my ($allhtml, $loop_template)=readtemplate("order_chips.html",
        "site/webtools/header.html", "/site/webtools/footer.html");

    foreach my $smp_ref ($study->samples)
    {
      my $sub;
      $sub->{name} = $smp_ref->{name};
      $sub->{layout} = $smp_ref->layout->name;
      my @ams = $smp_ref->arraymeasurements;
      $sub->{chip_count} = @ams;

      if ($smp_ref->{order})
      {
        if ($smp_ref->order->name) 
        {
          $sub->{order_status} = $smp_ref->order->name; 
        }
        else
        {
          $sub->{order_status} = "Pending";
        }
      }
      else
      {
        $sub->{order_status} = "Not yet ordered";
      }
      my $loop_instance = $loop_template;
      $loop_instance =~ s/{(.*?)}/$sub->{$1}/gs;
      $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    } 
    $allhtml =~ s/<loop_here>//s;
    my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    $allhtml = fixselect("pi_info", "$chref->{pi_us_fk},$chref->{pi_group_fk}",
        $allhtml);
    print "Content-type: text/html\n\n$allhtml\n";
  }

  sub draw_study
  {
    my $study = shift;
    my $chref = shift;

    my $user = GEOSS::Session->user;

    $chref->{htmltitle} = "Edit Array Study";
    $chref->{htmldescription} = "Use this page to configure studies.";
    $chref->{help} = set_help_url($dbh, "edit_or_delete_an_existing_array_study");


    if (! $study) 
    { 
# add default values for study create
      $chref->{date} = `date`; chomp $chref->{date};
      $chref->{date} = date2sql($chref->{date});
      $chref->{date} =~ s/^(\d{4}-\d{2}-\d{2}) (.*)$/$1/;

      $chref->{species} = GEOSS::Species->new(name => 'Homo sapiens')->pk;
      $chref->{layout} = GEOSS::Experiment::Arraylayout->new(name =>
          'HG-U133_Plus_2')->pk;
    }

#build selects
    $chref->{classification_select} = select_disease($dbh, "classification",
        "Please select");
    ($chref->{select_species}, undef) = select_species($dbh, "species");
    $chref->{select_arraylayout} = build_al_select($dbh, "layout");
    $chref->{select_lab_book_owner} = select_lab_book_owner();
    $chref->{bio_reps} = 1 if (! exists($chref->{bio_reps}));
    $chref->{chip_reps} = 1 if (! exists($chref->{chip_reps}));


    if ((! $chref->{pk}) || 
        ($chref->{status} eq "INCOMPLETE") ||
        ($chref->{status} eq "COMPLETE"))
    {
      $chref->{name} = qq#<input type="text" name="name" value="$chref->{name}"
        maxlength="128">#;
    }
    else
    {
      $chref->{name} = $chref->{name} . 
        qq# <input type="hidden" name="name" value="$chref->{name}"
        maxlength="128">#;
    }

    if (($chref->{owner}) && ($chref->{group}))
    {
      $chref->{user_pi} = $chref->{owner}->name . "/" . $chref->{group}->name;
    }
    else
    {
      $chref->{user_pi} = user_pi();
    }

    $chref->{date} = $1 if ($chref->{date} =~ /^(\d\d\d\d-\d\d-\d\d)( .*)/);
    $chref->{num_ec} = 0;
    if ($chref->{exp_conditions})
    {
      ($chref->{exp_cond_html}, my $loop_template, undef, my $loop_template2) 
        = readtemplate( "edit_exp_cond.html", "", "");

      my $ec_ref;
      my @exp_conds = @{$chref->{exp_conditions}};
      $chref->{number_of_conditions} = @exp_conds;
      foreach $ec_ref (@exp_conds)
      {
# To Do : Can use about select species and just change name
        ($ec_ref->{select_species}, undef) = select_species($dbh, 
            "species_$ec_ref->{pk}");
        $ec_ref->{num_ec} = ++$chref->{num_ec};
        $ec_ref->{type_details} = $ec_ref->type_details;
        $ec_ref->{add_smp} = "add_smp_" . $ec_ref->pk;
        my $ec_status = $ec_ref->status;
        if (($ec_status eq "LOADED") || 
            ($ec_status eq "LOADING IN PROGRESS") ||
            (! $ec_ref->can_write))
        {
          $ec_ref->{exp_name} = $ec_ref->{name};
          $ec_ref->{exp_delete} = "Locked";
          $ec_ref->{short_name} = $ec_ref->{short_name};
          $ec_ref->{select_species} =~ /value="$ec_ref->{species}">(.*)</;
          $ec_ref->{select_species} = $1;
          $ec_ref->{select_sample} = $ec_ref->{sample_type};
          $ec_ref->{notes} = $ec_ref->{notes};
          $ec_ref->{description} = $ec_ref->{description};
        }
        else
        {
          $ec_ref->{exp_name} = qq#<input type="text"
            name="exp_name_$ec_ref->{pk}" value="$ec_ref->{name}">#;
          $ec_ref->{exp_delete} = qq#<input type="checkbox"
            name="exp_cond_delete_$ec_ref->{pk}" value=""><br>#; 
          $ec_ref->{short_name} = qq#<input type="text" size=6 maxlength=6
            name="short_name_$ec_ref->{pk}"
            value="$ec_ref->{short_name}">#;
          $ec_ref->{select_sample}=qq#
            <select name="sample_type_$ec_ref->{pk}">
            <option value="tissue">tissue</option>
            <option value="cells">cells</option>
            <option value="total RNA">total RNA</option>
            </select>
#;
            $ec_ref->{type_details} = qq#<input type="text"
            name="type_details_$ec_ref->{pk}" value="$ec_ref->{type_details}">#;
          $ec_ref->{notes} = qq#<textarea rows=2 cols=25
            name="notes_$ec_ref->{pk}">$ec_ref->{notes}</textarea>#;
          $ec_ref->{description} = qq#<textarea rows=2 cols=25 name=
            "description_$ec_ref->{pk}">$ec_ref->{description}</textarea>#;
        }
        my $loop_instance = $loop_template;
        $loop_instance =~ s/{(.*?)}/$ec_ref->{$1}/gs;
        $chref->{exp_cond_html} =~ s/<loop_here>/$loop_instance<loop_here>/s;
        $chref->{exp_cond_html} = fixselect("sample_type_$ec_ref->{pk}", 
            $ec_ref->{type}, $chref->{exp_cond_html});
        $chref->{exp_cond_html} = fixselect("species_$ec_ref->{pk}", 
            $ec_ref->{species}, $chref->{exp_cond_html});
        my $smp_ref;
        my @smp_array = $ec_ref->samples;
        foreach $smp_ref(@smp_array)
        {
          my @hybs = $smp_ref->arraymeasurements;
          my $smp_status = $smp_ref->status;

          my $readonly;
          if (($smp_status eq "LOADED") || 
              ($smp_status eq "LOADING IN PROGRESS") || 
              ($smp_status eq "SUBMITTED") ||
              (! $smp_ref->can_write))
          {
            $smp_ref->{select_layout} = GEOSS::Experiment::Arraylayout->new(
                pk => $smp_ref->layout->pk)->name;
            $smp_ref->{select_lab_book_owner} = $smp_ref->{lab_book_owner};
            $smp_ref->{smp_delete} = "Locked";
            $smp_ref->{num_am} = @hybs;
            $readonly = 1;
          }
          else
          {
            $smp_ref->{smp_name} = qq#<input type="text" name=
              "smp_name_$smp_ref->{pk}" value="$smp_ref->{name}">#;
            $smp_ref->{select_layout} = build_al_select($dbh,
                "layout_$smp_ref->{pk}");
            $smp_ref->{num_am} = qq#<input type="text" size=2 maxlength=2 
              name="smp_num_am_$smp_ref->{pk}" value="# . @hybs . qq#">#;
            $smp_ref->{lab_book} = qq#<input type="text" size=4 
              name="lab_book_$smp_ref->{pk}" value="$smp_ref->{lab_book}">#;
            $smp_ref->{select_lab_book_owner} = select_lab_book_owner( 
                "lab_book_owner_$smp_ref->{pk}");
            $smp_ref->{origin} = qq#<input type="text" name=
              "origin_$smp_ref->{pk}" value="$smp_ref->{origin}">#;
            $smp_ref->{manipulation} = qq#<input type="text" name=
              "manipulation_$smp_ref->{pk}" value=
              "$smp_ref->{manipulation}">#;
            $smp_ref->{smp_delete} = qq#<input type="checkbox" name=
              "smp_delete_$smp_ref->{pk}" value="">#;
          }
          my $loop_instance2 = $loop_template2;
          $loop_instance2 =~ s/{(.*?)}/$smp_ref->{$1}/gs;
          if (! $readonly)
          {
            $loop_instance2 = fixselect("select_layout_$smp_ref->{pk}",
                $smp_ref->layout->pk, $loop_instance2) if ($smp_ref->layout);
            $loop_instance2 = fixselect("lab_book_owner_$smp_ref->{pk}",
                $smp_ref->{lab_book_owner}, $loop_instance2);
          }
          $chref->{exp_cond_html} =~ 
            s/<loop_here2>/$loop_instance2<loop_here2>/s;
        }
        $chref->{exp_cond_html} =~ s/<loop_here2>//s;
      }
    }
    if ($chref->{num_ec} > 0)
    {
      $chref->{submit_html} = qq!
        <table width="100%">
        <tr>
        <td>
        Add
        <input type="text" maxlength="4" size="4" name="num_exp_conds"
        value="{num_exp_conds}"> &nbsp; experimental conditions to 
        this study&nbsp;&nbsp;
      <input type=submit name="submit" 
        value="Add Experimental Conditions">
        </td>
        <td>
        <input type=submit name="submit" value="Save Study">
        </td>
        !;

      if (get_config_entry($dbh, "array_center"))
      {
        $chref->{submit_html}  .= qq!
          <td>
          <input type=submit name ="submit" 
          value="Order Chips From Array Center">
          </td>
          !;
      }
      $chref->{submit_html} .= " </tr> </table>";     
      $chref->{submit2_html} = $chref->{submit_html};
      $chref->{submit2_html} =~ s/num_exp_conds/num_exp_conds2/ ;
    }
    else
    {
      $chref->{submit_html} = qq!
        <table width="100%">
        <tr>
        <td>
        Add
        <input type="text" maxlength="4" size="4" name="num_exp_conds"
        value="{num_exp_conds}"> &nbsp; experimental conditions to 
        this study
        <input type=submit name="submit" 
        value="Add Experimental Conditions">
        </td>
        <td colspan=2>&nbsp</td>
        <tr>
        </table>
        !;     

    }
    $chref->{status} = ($chref->{status} eq "INCOMPLETE") || (! $chref->{pk}) ?
      qq!<font color="#FF0000">INCOMPLETE</font>! :
      qq!<font color="#008000">$chref->{status}</font>!;
    my $allhtml = get_allhtml($dbh, GEOSS::Session->user->pk, "edit_study.html",
        "site/webtools/header.html", "/site/webtools/footer.html", $chref);
    $allhtml = fixselect("classification", $chref->{disease}, $allhtml);
    $allhtml = fixselect("sample_type", $chref->{sample_type},
        $allhtml);
    $allhtml = fixselect("select_arraylayout", $chref->{layout}, $allhtml);
    $allhtml = fixselect("select_species", $chref->{species}, $allhtml)
      if $chref->{species};
    $allhtml = fixselect("select_lab_book_owner", $chref->{lab_book_owner},
        $allhtml);
    $allhtml =~ s/{(.*?)}/$chref->{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";
  }


  sub order_chips
  {
    my ($study, $chref) = @_;

    my @samples = grep {
      ! $_->order;  
    } $study->samples;
    my $num = @samples;
    die GEOSS::Session->set_return_message("errmessage",
        "ERROR_NO_CHIPS_IN_ORDER") if (@samples == 0);

    my $us_fk = GEOSS::Session->user->pk;
    my ($owner, $group) = split(',', $chref->{pi_info});
    $owner = GEOSS::User::User->new(pk => $owner);
    $group = GEOSS::User::User->new(pk => $group);
    my $org_fk = ($chref->{select_org} ne "NULL") ? $chref->{select_org} : undef;
    my $order = GEOSS::Arraycenter::Order->insert(
        created_by => $us_fk,
        owner=>$owner,
        group=>$group,    
        organization=>$org_fk,
        billing_code =>$chref->{billing_code},
        perms => 432,
        );

    foreach my $sample (@samples)
    {
      $sample->update(
          ( order => $order->pk )
          );
    }

    if (submit_order($dbh, $us_fk, $order->pk))
    {
      GEOSS::Session->set_return_message("goodmessage",
          "SUCCESS_SUBMIT_ORDER");
    }
    my $url = index_url($dbh, "webtools");
    print "Location: $url\n\n";
    exit;
  }
