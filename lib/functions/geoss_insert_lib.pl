package main;
use strict;

use DBI;

my $dbname = 'geoss'; 

#
#  Currently supported tables include:
#    study
#    order
#    sample
#    exp_condition
#    arraymeasurement
#

#
#
# Generic insert function 
#
# INPUTS
#   $table - text string of table for insert (eg "study")
#   $fields_ref - a hash reference - keys of hash must be fields in the
#     specified table - values are the values you want in the insert statement
#     required keys vary according to table - see the error_fn for the
#     appropriate table to determine which keys are required for that table
#   $other_ref - a hash reference - contains other values of interest that
#     needed by error_fn, pre_fn, or post_fn - see those functions for
#     details
#   $error_fn - a reference to a subroutine which performs all error checks
#     prior to inserting into the table
#   $pre_fn - a reference to a subroutine which performs actions necessary
#     prior to performing an insert - this includes setting defaults
#   $post_fn - a reference to a subroutine which performs actions required
#     after the insert - often includes a call to insert_security
#   $commit - whether or not to commit changes to the the database (1 to
#      commit)
#   $debug - prints debugging statements if set to 1
#
# OUTPUTS
#   $error - 0 if no error, otherwise will contain the error string
#   $new_pk - the pk value for the row just inserted
#
sub insert_row_generic
{
  my ($dbh, $us_fk, $table, $fields_ref, $other_ref, $error_fn, $pre_fn,
      $post_fn, $commit, $debug) = @_;
  my $q_name = "insert_row_generic";

  my ($error, $new_pk) = 0;
  $error = &$pre_fn($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug);
  $error = &$error_fn($dbh, $us_fk, $fields_ref, $other_ref, $commit, 
      $debug) if (! $error);

  if (! $error)
  {
    my $sql = "insert into $table ";
    my $fields = "(";
    my $values = "(";

    my $k;
    foreach $k (keys(%$fields_ref))
    {
      if (valid_field($table, $k))
      {
        if ($fields_ref->{$k})
        {
          $fields .= "$k,";
          $values .= $dbh->quote($fields_ref->{$k}) . ",";
        }
      }
      else
      {
        $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_FIELD_FOR_TABLE", $table, $k);
        warn "$error";
      }
    }
    chop $fields; chop $values; # remove trailing comma
    $sql .= $fields . ") values " . $values . ")";   
  
    print "SQL is $sql\n\n" if ($debug);
    my $sth= $dbh->prepare($sql) || 
      die "$q_name prepare $sql\n$DBI::errstr\n";
    $sth->execute() || die "$q_name execute $sql\n$DBI::errstr\n";
    $new_pk = insert_security($dbh, $other_ref->{owner_us_pk},
        $other_ref->{owner_gs_pk}, 0660);
    $fields_ref->{new_pk} = $new_pk;
    $error = &$post_fn($dbh, $us_fk, $fields_ref, $other_ref);
  }
  $dbh->commit() if ($commit);
  return($error, $new_pk);
}

####  PRE FUNCTIONS
#
# study pre 
sub pre_insert_study
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  $fields_ref->{sty_comments} = "Insert comments here"
    if (!exists($fields_ref->{sty_comments}));

  return ($error);
}

 
# exp_condition pre
sub pre_insert_exp_condition
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  return ($error);
}

# order_info pre
sub pre_insert_order_info
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  $fields_ref->{order_number} = generate_order_number($dbh, $us_fk) 
    if (!$fields_ref->{order_number});

  return ($error);
}



# sample pre
sub pre_insert_sample
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  return ($error);
}

# arraymeasurement pre
sub pre_insert_arraymeasurement
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  return ($error);
}



#
####  ERROR FUNCTIONS

#
# study err 
# 
# Error conditions include:
#   - duplicate study name 
#   - created_by must be a valid us_fk
#   - start_date should be in a valid format
#   - study_name should contain only allowable characters
#
sub err_insert_study
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $q_name = "err_insert_study";
  my $error = 0;
  
  if ((!exists $fields_ref->{study_name}) ||
     ($fields_ref->{study_name} eq ""))
  {
    $error = set_return_message($dbh, $us_fk, "errmessage", "message",
        "FIELD_MANDATORY", "Study Name");
  }
  else
  {
    # duplicate study name 
    my $sql = "select study_name from study where study_name = '$fields_ref->{study_name}'";
    my $sth = $dbh->prepare($sql) || die "$q_name prepare $sql\n$DBI::errstr\n";
    $sth->execute() || die "$q_name execute $sql\n$DBI::errstr\n";
    while ((my $name) = $sth->fetchrow_array())
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "NAME_MUST_BE_UNIQUE");
    }
    $sth->finish();
  }

  #   created_by must exist
  if (! exists $fields_ref->{created_by})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "FIELD_MANDATORY", "created_by field for the order_info table ");
  }
  else
  {
    if (! valid_pk($dbh, "usersec", "us_pk", $fields_ref->{created_by}))
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "usersec", $fields_ref->{created_by});
    }
  }


  return($error);
}

# 
# exp_condition err
# 
# no sty_fk
# invalid sty_fk
# another exp_condition with the same short name in the same sty
# more than 6 letters in abbrev_name
# <1 letters in abbrev_name
# invalid characthers in the abbrev_name
# invalid spc_fk
# must have a name
#
sub err_insert_exp_condition
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

# no sty_fk
  if (! exists($fields_ref->{sty_fk}))
  {
    $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "INVALID_EXP_COND_NO_STUDY", "study", $fields_ref->{abbrev_name});
  }
  elsif (! valid_pk($dbh, "study", "sty_pk", $fields_ref->{sty_fk}))
  {
    # invalid sty_fk
    $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "INVALID_PK_FOR_TABLE", "study", $fields_ref->{sty_fk});
  }


  my $sql = "select ec_pk from exp_condition, study where sty_fk = sty_pk and
    abbrev_name = '$fields_ref->{abbrev_name}' and sty_pk =
    $fields_ref->{sty_fk}";
  my $sth = $dbh->prepare($sql) || die "err_insert_exp_condition:
    $sql\n$DBI::errstr\n";
  $sth->execute() || die "err_insert_exp_condition: $sql\n$DBI::errstr\n";

  if ($sth->fetchrow_array())
  {
    $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "ERROR_DUPLICATE_SHORT_NAME_IN_SAME_STUDY", "study", 
          $fields_ref->{abbrev_name});
  }
  $sth->finish();

# more than 6 letters in abbrev_name
# <1 letters in abbrev_name
  my $len = length($fields_ref->{abbrev_name});
  if ($len > 6) 
  {
   $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "ERROR_SHORT_NAME_TOO_LONG", $fields_ref->{abbrev_name});
  }
  if ($len < 1) 
  {
   $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "FIELD_MANDATORY", "Short Name");
  }

# invalid characthers in the abbrev_name
  if ($fields_ref->{abbrev_name} =~ /[^A-Za-z0-9]/)
  {
   $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "ERROR_SHORT_NAME_INVALID_CHARACTERS", $fields_ref->{abbrev_name});
  }

  # invalid spc_fk
  if ((exists $fields_ref->{spc_fk}) &&
      (! valid_pk($dbh, "species", "spc_pk", $fields_ref->{spc_fk})))
  {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "species", $fields_ref->{spc_fk});
    }

  #must have a name
  if (! exists($fields_ref->{name}))
  {
    $error = set_return_message($dbh, $us_fk, "errmessage", "message",
          "FIELD_MANDATORY", "Experimental Condition Name");
  }
  return($error);
}


# order_info err
#
#   if specified, order_number must not already be in use
#   created_by must exist
#   if specified, org_fk, default_al_fk, and default_sty_fk  must exist
#   date_report_completed, date_samples_complete, date_samples_received,
#   date_last_revised, approval_date must be in valid format

sub err_insert_order_info
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;

  my $q_name = "err_insert_order_info";
  my $error = 0;

  #  order_number must not already be in use
  #  generally this is a given (we generate the order number), but 
  #  it can be specified by the user in a bulk load
  my $sql = "select oi_pk from order_info where order_number =
    '$fields_ref->{order_number}'";
  my $sth = $dbh->prepare($sql) || die "$q_name prepare
    $sql\n$DBI::errstr\n";
  $sth->execute() || die "$q_name execute $sql\n$DBI::errstr\n";

  if ($sth->fetchrow_array())
  {
    $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "ERROR_DUPLICATE_ORDER", $fields_ref->{order_number});
  }

  #   created_by must exist
  if (! exists $fields_ref->{created_by})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "FIELD_MANDATORY", "created_by field for the order_info table");
  }
  else
  {
    if (! valid_pk($dbh, "usersec", "us_pk", $fields_ref->{created_by}))
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "usersec", $fields_ref->{created_by});
    }
  }

  # if specified, org_fk, default_al_fk, and default_sty_fk  must exist
  if ((exists $fields_ref->{org_fk}) && 
      (! valid_pk($dbh, "organization", "org_pk", $fields_ref->{org_fk})))
  {
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "organization", $fields_ref->{org_fk});
  }

  if ((exists $fields_ref->{default_al_fk}) && 
      (! valid_pk($dbh, "arraylayout", "al_pk", $fields_ref->{default_al_fk})))
  {
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", 
            "arraylayout", $fields_ref->{default_al_fk});
  }

  if ((exists $fields_ref->{default_sty_fk}) && 
      (! valid_pk($dbh, "study", "sty_pk", $fields_ref->{study_al_fk})))
  {
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "study", $fields_ref->{default_sty_fk});
  }

  return($error);
}

#
# sample err
#   must have a valid ec_fk
#   must have a valid oi_fk
#   if specified, timestamp should be in a valid format
sub err_insert_sample
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;

  my $error = 0;

  #   ec_fk must exist
  if (! exists $fields_ref->{ec_fk})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INCOMPLETE_ORDER_SAMPLE_NEEDS_EXP_COND", "order_info");
  }
  else
  {
    if (! valid_pk($dbh, "exp_condition", "ec_pk", $fields_ref->{ec_fk}))
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "exp_condition", $fields_ref->{ec_fk});
    }
  }

  if (exists $fields_ref->{oi_fk})
  {
    if (! valid_pk($dbh, "order_info", "oi_pk", $fields_ref->{oi_fk}))
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "order_info", $fields_ref->{oi_fk});
    }
  }

  return($error);
}
#
#
# arraymeasurement err
#   hybridization_name, qc_fk, is_laoded & date_laoded must not be specified
#   must have a valid al_fk
#   must have a valid smp_fk
sub err_insert_arraymeasurement
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;

  my $error = 0;
   
#   hybridization_name, qc_fk, is_laoded & date_laoded must not be specified
  if (exists $fields_ref->{is_loaded})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "CANT_SET_CALCULATED_VALUE", "is_loaded");
  }
  if (exists $fields_ref->{date_loaded})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "CANT_SET_CALCULATED_VALUE", "date_loaded");
  }
  if (exists $fields_ref->{hybridization_name})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "CANT_SET_CALCULATED_VALUE", "hybridization_name");
  }
  if (exists $fields_ref->{qc_fk})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "CANT_SET_CALCULATED_VALUE", "qc_fk");
  }
   
  #   al_fk must exist
  if (! exists $fields_ref->{al_fk})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INCOMPLETE_HYB_NEEDS_CHIP_TYPE");
  }
  else
  {
    if (! valid_pk($dbh, "arraylayout", "al_pk", $fields_ref->{al_fk}))
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "arraylayout", $fields_ref->{al_fk});
    }
  }
  #   smp_fk must exist
  if (! exists $fields_ref->{smp_fk})
  { 
     $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INCOMPLETE_HYB_NEEDS_SAMPLE");
  }
  else
  {
    if (! valid_pk($dbh, "sample", "smp_pk", $fields_ref->{smp_fk}))
    {
      $error = set_return_message($dbh, $us_fk, "errmessage", "message",
            "INVALID_PK_FOR_TABLE", "sample", $fields_ref->{smp_fk});
    }
  }

  return($error);
}
#   


####  POST FUNCTIONS
#
# study post 
sub post_insert_study
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  
  return $error;
}

#
# exp_condition post
sub post_insert_exp_condition
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;
  
  return $error;
}

#
# order_info post
#
# secure the order
# update the billing table
#
sub post_insert_order_info
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;
  
  my $sql = "insert into billing (oi_fk, chips_billed, rna_isolation_billed,
    analysis_billed) values ($fields_ref->{new_pk}, 
       '0'::bool, '0'::bool, '0'::bool)";
  $dbh->do($sql) || die "post_insert_order_info: $sql\n$DBI::errstr\n";
  return $error;
}


#
# sample post
sub post_insert_sample
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  return $error;
}
# arraymeasurement post
sub post_insert_arraymeasurement
{
  my ($dbh, $us_fk, $fields_ref, $other_ref, $commit, $debug) = @_;
  my $error = 0;

  return $error;
}
#
#

#
# ## UTILITY FUNCTIONS
#

# sub valid_pk
#
# This function verifies that the specified pk exists in the appropriate
# table.  Theoretically this should be caught as a referential integrity
# error by the db, but we are trying to format the error in a more
# user-friendly manner.
#
sub valid_pk
{
  my ($dbh, $table, $field, $pk) = @_;

  my $valid = 0;

  my $sql = "select * from $table where $field = $pk";
  my $sth = $dbh->prepare($sql) || die "valid_pk: $sql\n$DBI::errstr\n";
  $sth->execute() || die "valid_pk: $sql\n$DBI::errstr\n";

  my ($value) = $sth->fetchrow_array();
#if ($sth->fetchrow_array())
  if ($value)
  {
    $valid = 1;
  }
  
  $sth->finish();
  return $valid;
}
  
# sub valid_field
# This function verifies that the field name is valid for a specific table
#
# There must be a better way to do this, but I'm in a rush and literal is
# easy.  As I hope to come back and changes this to a generic solution, I 
# have not typed in an exhaustive list of fields.  Have tried to include
# those we use.
# 
sub valid_field
{
  my ($table, $field) = @_; 

  my $valid = 0;

  if ($table eq "study")
  {
    if (($field =~ /study_name/i) ||
        ($field =~ /start_date/i) ||
        ($field =~ /created_by/i) ||
        ($field =~ /study_abstract/i) ||
        ($field =~ /study_url/i) ||
        ($field =~ /sty_comments/i))
    {
      $valid = 1;
    }
  }
  elsif ($table eq "order_info")
  {
    if (($field =~ /order_number/i) ||
        ($field =~ /chips_ordered/i) ||
        ($field =~ /locked/i) ||
        ($field =~ /signed_analysis_report/i) ||
        ($field =~ /meeting_scheduled/i) ||
        ($field =~ /created_by/i) ||
        ($field =~ /isolations/i) ||
        ($field =~ /date_report_completed/i) ||
        ($field =~ /have_chips/i) ||
        ($field =~ /date_samples_received/i) ||
        ($field =~ /date_last_revised/i) ||
        ($field =~ /is_approved/i) ||
        ($field =~ /approval_comments/i) ||
        ($field =~ /org_fk/i) ||
        ($field =~ /approval_date/i) ||
        ($field =~ /default_smp_name/i) ||
        ($field =~ /default_lab_book/i) ||
        ($field =~ /default_lab_book_owner/i) ||
        ($field =~ /default_ams/i) ||
        ($field =~ /default_smp_origin/i) ||
        ($field =~ /default_smp_manipulation/i) ||
        ($field =~ /default_al_fk/i) ||
        ($field =~ /default_sty_fk/i))
    {
      $valid = 1;
    }
  }
  elsif ($table eq "sample")
  {

    if (($field =~ /ec_fk/i) ||
        ($field =~ /con_fk/i) ||
        ($field =~ /oi_fk/i) ||
        ($field =~ /lab_book/i) ||
        ($field =~ /lab_book_owner/i) ||
        ($field =~ /timestamp/i) ||
        ($field =~ /smp_name/i) ||
        ($field =~ /smp_manipulation/i) ||
        ($field =~ /smp_origin/i))
    {
      $valid = 1;
    }
  }
  elsif ($table eq "exp_condition")
  {

    if (($field =~ /name/i) ||
        ($field =~ /abbrev_name/i) ||
        ($field =~ /quantity/i) ||
        ($field =~ /unit/i) ||
        ($field =~ /time_series/i) ||
        ($field =~ /time_point/i) ||
        ($field =~ /sty_fk/i) ||
        ($field =~ /spc_fk/i) ||
        ($field =~ /sample_type/i) ||
        ($field =~ /description/i) ||
        ($field =~ /sample_treatement/i) ||
        ($field =~ /analysis_description/i) ||
        ($field =~ /treatment_type/i) ||
        ($field =~ /quantity_series_type/i) ||
        ($field =~ /notes/i) ||
        ($field =~ /seed_supplier_cat_num/i) ||
        ($field =~ /cultivar_name/i) ||
        ($field =~ /variety/i) ||
        ($field =~ /strain/i) ||
        ($field =~ /cell_line/i) ||
        ($field =~ /genotype/i) ||
        ($field =~ /phenotype/i) ||
        ($field =~ /sex_mating_type/i) ||
        ($field =~ /age/i) ||
        ($field =~ /age_units/i))
    {
      $valid = 1;
    }
  }
  elsif ($table eq "arraymeasurement")
  {

    if (($field =~ /hybridization_name/i) ||
        ($field =~ /type/i) ||
        ($field =~ /al_fk/i) ||
        ($field =~ /smp_fk/i) ||
        ($field =~ /is_loaded/i) ||
        ($field =~ /date_loaded/i) ||
        ($field =~ /description/i))
    {
      $valid = 1;
    }
  }
  else
  {
    warn "Unsupported table: $table in function valid_field\n";
  }

  return($valid);
} # sub valid_field

sub generate_order_number
{
  my ($dbh, $us_fk) = @_;

  my $ord_num_format = get_config_entry($dbh, "ord_num_format");
  my $order_number;
  if ($ord_num_format eq "year_seq")
  {
    $order_number = generate_order_number_year_seq($dbh, $us_fk);
  }
  elsif ($ord_num_format eq "seq")
  {
    $order_number = generate_order_number_seq($dbh, $us_fk);
  }
  return($order_number);
}


sub generate_order_number_seq
{
    my ($dbh, $us_fk) = @_;
    my $sql;

    $sql = "select nextval('order_seq')";
    (my $order_number) = $dbh->selectrow_array($sql);
    return "$order_number";
}

sub generate_order_number_year_seq
{
    my ($dbh, $us_fk) = @_;
    my $sql;

    my $year = `date +%y`; # two digit year
    chomp($year);
    check_rollover($dbh, $us_fk, $year);
    $sql = "select nextval('order_seq')";
    (my $order_number) = $dbh->selectrow_array($sql);
    #
    # Sequence numbers with one digit are zero padded.
    # It is possible to use sprintf() for the number padding, 
    # but it is better to eschew obfuscation.
    #
    if ($order_number < 10)
    {
        $order_number = "0$order_number";
    }

    $order_number = $year. "-". $order_number;
    return "$order_number";
}

sub check_rollover
{
   my ($dbh, $us_fk, $year) = @_;

   if (! is_value($dbh,$us_fk,"global","yearoflastrollover"))
   {
       #warn "setting global $year\n";
       set_session_val($dbh, $us_fk, "global", "yearoflastrollover", $year);
   }
   else
   {
     my ($valuesref) = get_session_val($dbh, $us_fk, "global", 
	"yearoflastrollover");
     my $lastyear = $$valuesref[1];

     if ($lastyear < $year)
     {
     # we reset the sequence and update the lastyear value
       set_session_val($dbh, $us_fk, "global", "yearoflastrollover", $year);
       my $sql = "select setval('order_seq',0)";
       (my $order_number) = $dbh->selectrow_array($sql);
       write_log("Resetting order number in insert_order_curator3.cgi");
     }
     else
     {
       set_session_val($dbh, $us_fk, "global", "yearoflastrollover", $lastyear);
     }
   }
}
1;
