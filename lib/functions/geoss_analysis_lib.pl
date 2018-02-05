package main;
use strict;
use GEOSS::Experiment::Study;

##
## MISC SUBS
##

sub verify_criteria_file
{
  my ($dbh, $us_fk, $fi_pk) = @_;
  my $success = "true";
  my $line_number = 1;
  my $i;
  my %auto_cond;
  my @col_headers;

  my $file_name = doq($dbh, "get_file_name", $fi_pk);
  $file_name =~ /.*\/(.*)/;
  my $base = $1; 
  # translate the file to get rid of ^M dos format stuff if necessary
  `tr -d '\r' < $file_name > /tmp/geoss_$base`;
  if ($?)
  {
    warn "Error in tr -d '\r' < $file_name > /tmp/geoss_$base : $!";
  }
  else
  {
    `mv /tmp/geoss_$base $file_name`;
    warn "Error in mv /tmp/geoss_$base $file_name : $!" if ($?);
  }

  # verify that the file is of type text
  my $typestr = `file $file_name`;
  if ($typestr !~ /ASCII text/i)
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_BAD_FILE_TYPE_CRITERIA_NOT_ASCII", $typestr);
  }
  else
  {
    open (IN, "< $file_name") || die "verify_criteria_file: cannot open
      $file_name: $!\n";
    my $header_line = <IN>;
    chop($header_line);
   

    @col_headers = split(/\t/, $header_line);
    if ($#col_headers < 1)
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_BAD_FILE_FORMAT", 
        "$file_name Line: $line_number. The file must have a minimum of two"
        . " tab separated columns.");
    }   

    # verify that the first column is arraymeasurement::hybridization_name
    my $first = $col_headers[0];
    if ($first !~ /^name/i)
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_BAD_FILE_FIRST_COL", $line_number, $col_headers[0]);
    }

    # foreach subsequent columns
    for ($i = 1; $i<= $#col_headers; $i++)
    {
      my $header = $col_headers[$i]; 
      # verify that it fits the syntax
      if ($header !~ /(.+)::(categorical|continuous)(::condition)?(::set)?$/i)
      {
        $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_BAD_FILE_CAT_OR_CONT", $line_number, $i);
      }

      if (($header =~ /::categorical/i) && ($header =~ /::continuous/i))
      {
        $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_BAD_FILE_CAT_AND_CONT", $line_number, $header);
      }

      $header =~ /([^(::)]+)::/;
      my $cond_root = $1;
      # if ::Condition is specified, warn if the condition already exists
      if ($header =~ /::Condition/i)
      {
        $auto_cond{$i} = $cond_root . "--";
      } 
    
      # if ::Set is specified, warn if the set already exists
      if ($header =~ /::Set/i)
      {
        $file_name =~ /.*\/(.*)/;
        my $set_name = $cond_root . "--$1";
        my $an_set_ref = getq_an_set_pk_by_name($dbh, $us_fk, $set_name);
        my @an_set_ref = @$an_set_ref;
        if ($#an_set_ref != -1)
        {
          set_return_message($dbh, $us_fk, "message", "warnmessage",
            "WARN_ANALYSIS_SET_EXISTS", $set_name, $i);
        }
      }
  
    }

    # foreach data line
    my $data_line;
    my %conds_to_check = ();
    my %hyb = ();
    while ($data_line = <IN>)
    {
      $line_number++;
      chop($data_line);
      next if ($data_line eq "");
      my @data = split(/\t/,$data_line);
      my $hyb_name = $data[0];
 
      # check if the hyb name has already been specified in the file and
      # has different data
      if ((exists $hyb{$hyb_name}) && ($data_line ne $hyb{$hyb_name}))
      {
          $success = set_return_message($dbh, $us_fk, "message", "errmessage",
            "ERROR_BAD_FILE_DUPLICATE_ROWS", $hyb_name);
      }
  
      $hyb{$hyb_name} = $data_line;
      #  for the first column, verify that the hybridization exists
      if (!check_duplicate_hyb_name($dbh, $us_fk, $hyb_name))
      {
          $success = set_return_message($dbh, $us_fk, "message", "errmessage",
            "ERROR_BAD_FILE_INVALID_HYB", $line_number, $hyb_name);
      }

      # for subsequent columns, warn if there is the incorrect amount of data
      foreach ($i = 0; $i <= $#col_headers; $i++)
      {
        if ((! exists($data[$i])) || ($data[$i] eq ""))
        {
          set_return_message($dbh, $us_fk, "message", "warnmessage",
            "WARN_BAD_FILE_MISSING_DATA", $line_number, $i);
        }

        if ($auto_cond{$i})
        {
          my $key = $auto_cond{$i} . $data[$i];
          $conds_to_check{$key} = $i;
        }
      }
    }

    my $cond_name;
    foreach $cond_name (keys %conds_to_check)
    {
        my $an_cond_ref = getq_an_cond_pk_by_name($dbh, $us_fk, $cond_name);
        my @an_cond_ref = @$an_cond_ref;
        if ($#an_cond_ref != -1)
        {
          set_return_message($dbh, $us_fk, "message", "warnmessage",
            "WARN_ANALYSIS_COND_EXISTS", $cond_name, 
            $conds_to_check{$cond_name});
        }
  
    }
  
    close(IN);
  }
  return ($success);
}

sub check_redirect
{
    my ($dbh, $us_fk, $chref) = @_; 
    ## Check if request to edit an_set and redirect
    my $key;
    foreach $key (keys(%$chref))
    {
      if ($key =~ /edit_an_set_(\d+)\../ )
      {
        post_redirect($dbh, $us_fk, "edit_an_set", "an_set_pk", 
          $1, "edit_an_set.cgi");
      }
      if ($key =~ /edit_an_cond_(\d+)\../){
        post_redirect($dbh, $us_fk, "edit_an_cond", "an_cond_pk",
          $1, "edit_an_cond.cgi");
      }

    }
}


## check_logic
## 8-10-04  Steve Tropello
## Takes criteria case string (=, !=, >, <, >= or <=) and performs boolean logic
## on a criteria file field value and the form value for that field
## Return 0 or 1
sub check_logic
{
                                                                                                                   
  my ($form_value, $hash_value, $case_string) = @_;
                                                                                                                   
# values may be either numberic (continuous or conditional) or 
# string (conditional), so use the string operator for # checking the 
# eq case
  if ($case_string eq "="){
    return ($form_value == $hash_value);
  }
  if ($case_string eq "!="){
    return ($form_value != $hash_value);
  }
  if ($case_string eq "<"){
    return ($hash_value < $form_value);
  }
  if ($case_string eq ">"){
    return ($hash_value > $form_value);
  }
  if ($case_string eq "<="){
    return ($hash_value <= $form_value);
  }
  if ($case_string eq ">="){
    return ($hash_value >= $form_value);
  }
  return 0;
}


## merge_array_and
## 8-10-04  Steve Tropello
## Creates the intersection of objects in two arrays
## Return @temp_array which contains common objects
sub merge_array_and
{
                                                                                                               
  my ($new_array_ref, $old_array_ref) = @_;
  my @new_array = @{$new_array_ref};
  my @old_array = @{$old_array_ref};
  my @temp_array = ();
  my $value;
                                                                                                               
  foreach $value (@new_array){
                                                                                                               
    if (in_array($value, @old_array)){
                                                                                                               
      push @temp_array, $value;
                                                                                                               
    }
                                                                                                               
  }
                                                                                                               
  return @temp_array;
                                                                                                               
} # merge_array_and


## merge_array_or
## 8-10-04  Steve Tropello
## Creates the union of objects in two arrays
## Return @old_array which contains all distinct objects between new and old arrays
sub merge_array_or
{
                                                                                                               
  my ($new_array_ref, $old_array_ref) = @_;
  my @new_array = @{$new_array_ref};
  my @old_array = @{$old_array_ref};
  my $value;
                                                                                                               
  foreach $value (@new_array){
                                                                                                               
    if (!in_array($value, @old_array)){

      push @old_array, $value;
                                                                                                               
    }
                                                                                                               
  }
                                                                                                               
  return @old_array;
                                                                                                               
} # merge_array_or


## parse_criteria_file
## 8-10-04  Steve Tropello
## Parses criteria file and returns a criteria hash of a hash
## Hash keys: hybridization_name (primary) and field name (secondary)
## Return %criteria_hash
sub parse_criteria_file
{

  (my $dbh, my $fi_fk) = @_;
  
  my $criteria_file_name = doq($dbh, "get_file_name", $fi_fk);
  open (IN, "< $criteria_file_name") || die "sub parse_criteria_file: cannot open $criteria_file_name\n";
  my $text_line = <IN>;
  chop($text_line);
  my @field_string_array = split(/\t/, $text_line);
  my @field_name_array = @field_string_array;
  my @field_value_array;
  my %criteria_hash;
  my $hybridization_name;

  while($text_line = <IN>){
                                                                                                                      
    chop($text_line);
    @field_value_array = split(/\t/, $text_line);
    $hybridization_name = $field_value_array[0];
                                                                                                                     
    for(my $counter=0; $counter < @field_value_array; $counter++){
      $criteria_hash{$hybridization_name}{$field_name_array[$counter]} = $field_value_array[$counter];
    }    

  }

  close(IN);

  return %criteria_hash;

} #parse_criteria_file


## post_redirect
## 8-10-04  Steve Tropello
## Pass the URL of the next CGI and corresponding values to access via POST
## This function prevents using the GET method of information transfer between CGIs
## Return null; exits current process (CGI) and ends $dbh connection
sub post_redirect
{
                                                                                                                   
  my ($dbh, $us_fk, $type, $key_value, $value, $page) = @_;
  set_session_val($dbh, $us_fk, $type, $key_value, $value);
  my $url = index_url() . "/" . $page;
  print "Location: $url\n\n";
  $dbh->commit;
  $dbh->disconnect;
  exit(0);
                                                                                                                   
} #post_redirect


## radio_source
## 8-10-04  Steve Tropello
## Function maintains proper source selection in GUI
## Return %ch
sub radio_source
{

  my ($chref) = @_;
  my %ch = %$chref;

  if ($ch{source} eq "an_cond"){
    $ch{an_cond_checked} = "CHECKED";
  }
  if ($ch{source} eq "study"){
    $ch{study_checked} = "CHECKED";
  }
  if ($ch{source} eq "exp_condition"){
    $ch{exp_condition_checked} = "CHECKED";
  }
  if ($ch{source} eq "arraymeasurement"){
    $ch{arraymeasurement_checked} = "CHECKED";
  }
  if ($ch{source} eq "criteria_file"){
    $ch{criteria_file_checked} = "CHECKED";
  }
  if ($ch{source} eq "an_set"){
    $ch{an_set_checked} = "CHECKED";
  }
  if ($ch{source} eq "public"){
    $ch{public_checked} = "CHECKED";
  }
  if ($ch{source} eq "an_file"){
    $ch{an_file_checked} = "CHECKED";
  }

  return %ch;

} # radio_source


##
## CREATE SUBS
##

## create_automatic_components
## 2-1-05 Teela James
## Uses criteria file input to automatically create analysis conditions
## and analysis sets
sub create_automatic_components
{
  my ($dbh, $us_fk, $fi_pk, $chref) = @_;

  my $criteria_file_name = doq($dbh, "get_file_name", $fi_pk);
  $criteria_file_name =~ /.*\/(.*)/;
  my $an_desc = "$1 criteria file automatic creation";
  my %criteria_hash = parse_criteria_file($dbh, $fi_pk);
  my @field_name_array = get_field_names(\%criteria_hash, "categorical");
  my $field_name;
  my %conditions_to_create = ();
  my %sets_to_create = ();
  foreach $field_name (@field_name_array)
  {
     if (($field_name =~ /::condition/i) || ($field_name =~/::set/i))
     {
       my $hyb;
       foreach $hyb (keys %criteria_hash)
       {
         my $value = $criteria_hash{$hyb}{$field_name};
#         warn "$field_name\t$hyb\t$value\n";
         my ($cond_root) = split(/::/,$field_name);
         my $cond_name = $cond_root . "--$value";
         my @hybs_in_cond = ();
         @hybs_in_cond = @{$conditions_to_create{$cond_name}} if (exists
             $conditions_to_create{$cond_name});
         push @hybs_in_cond, $hyb;
         $conditions_to_create{$cond_name} = \@hybs_in_cond;

         if ($field_name =~ /::set/i)
         {
           $criteria_file_name =~ /.*\/(.*)/;
           my $set_name = $cond_root . "--$1";
           my %conds_in_set = ();
           %conds_in_set = %{$sets_to_create{$set_name}} if (exists
               $sets_to_create{$set_name});
           $conds_in_set{$cond_name} = 1;
           $sets_to_create{$set_name} = \%conds_in_set;
         }
       }
     }
  }
  my $cond_name;
  my $master_an_cond_pk = "";
  foreach $cond_name (keys (%conditions_to_create))
  {
    my @hybs = @{$conditions_to_create{$cond_name}};
#    warn "Creating $cond_name with hybs: @hybs";
    my $an_cond_ref = getq_an_cond_pk_by_name($dbh, $us_fk, $cond_name);
    my @an_conds = @$an_cond_ref;
    if ($#an_conds == -1)
    {
      my $an_cond_pk = create_an_cond($dbh, $cond_name, $an_desc, $us_fk, $us_fk);
      insert_ams_into_an_cond($an_cond_pk, \@hybs, $dbh, "hybridization_name");
      $master_an_cond_pk .= "$an_cond_pk,";
    }
  }
  #get rid of trailing comma
  chop($master_an_cond_pk);

  my $set_name;
  if ($master_an_cond_pk ne "")
  {
    foreach $set_name (keys (%sets_to_create))
    {
      my %conds = %{$sets_to_create{$set_name}};
      my $an_set_ref = getq_an_set_pk_by_name($dbh, $us_fk, $set_name);
      my @an_sets = @$an_set_ref;
      if ($#an_sets == -1)
      {
        # make list of an_cond_pks.  Only include an_conds created
        # when we uploaded this file.  Only create the set if the 
        # set name is unique and if we have just created all necessary
        # an_conds

        my @an_conds=();
        my $good = 1;
        foreach $cond_name (keys (%conds))
        {
          #get the cond_pk
          my $sql = "select an_cond_pk from an_cond where
            an_cond_name='$cond_name' and an_cond_pk in ($master_an_cond_pk)";
          my $sth = $dbh->prepare($sql) || die "prepare $sql\n$DBI::errstr\n";
          $sth->execute() || die "execute $sql\n$DBI::errstr\n";
          my $pk;
          ($pk) = $sth->fetchrow_array();
          if ($pk)
          {
            push @an_conds, $pk;
          }
          else
          {
            $good=0;
          }
        }
        if ($good)
        {
          my $an_set_pk = create_an_set($dbh, $set_name, $an_desc, $us_fk,
            $us_fk);
      
          insert_an_conds_into_an_set($an_set_pk, \@an_conds, $dbh);
        }
      }
    }
  }   
}

sub exists_an_cond
{
  my ($dbh, $an_cond_name, $an_cond_created) = @_;
  my ($exists) = $dbh->selectrow_array("select count(*) from an_cond where" .
     " an_cond_name = '$an_cond_name' and " .
     " an_cond_created='$an_cond_created'");
  return($exists);
}

## create_an_cond
## 8-10-04  Steve Tropello
## Creates a new an_cond with specified name, description, owner and group
## Return $an_cond_pk
sub create_an_cond
{

  my ($dbh, $an_cond_name, $an_cond_desc, $owner, $group) = @_;

  my $an_cond_created = `date`;
  chomp($an_cond_created);
  $an_cond_created = date2sql($an_cond_created);

  if (exists_an_cond($dbh, $an_cond_name, $an_cond_created))
  {
    sleep 1;
    $an_cond_created = `date`;
    chomp($an_cond_created);
    $an_cond_created = date2sql($an_cond_created);
  }

  my $sql = "insert into an_cond (an_cond_name, an_cond_desc, an_cond_created) values (trim(?), trim(?), ?)";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_cond_name, $an_cond_desc, $an_cond_created) || die "Execute $sql \n$DBI::errstr";

  my $an_cond_pk = insert_security($dbh, $owner, $group, 0660);

  $dbh->commit;

  return $an_cond_pk;

} #create_an_cond


## create_an_set
## 8-10-04  Steve Tropello
## Creates a new an_set with specified name, description, owner and group
## Return $an_set_pk
sub create_an_set
{

  my ($dbh, $an_set_name, $an_set_desc, $owner, $group) = @_;
  my $an_set_created = `date`;

  chomp($an_set_created);
  $an_set_created = date2sql($an_set_created);

  my $sql = "insert into an_set (an_set_name, an_set_desc, an_set_created) values (trim(?), trim(?), ?)";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_set_name, $an_set_desc, $an_set_created) || die "Execute $sql \n$DBI::errstr";

  my $an_set_pk = insert_security($dbh, $owner, $group, 0660);

  $dbh->commit;

  return $an_set_pk;

} #create_an_set


## create_analysis_hash_from_an_set
## 8-10-04  Steve Tropello
## Creates an analysis_hash from an an_set
## Return %analysis_hash (key = an_cond_pk; element = @ams)
sub create_analysis_hash_from_an_set
{
                                                                                                               
  my $an_set_pk = $_[0];
  my $dbh = $_[1];
  my $us_fk = $_[2];
  my %analysis_hash;
  my @am_pk_array;
  my $chref1;
  my $chref2;
                                                                                                               
  my ($fclause, $wclause) = read_where_clause("an_cond", "an_cond_pk", $us_fk);
  my $sql = "select an_cond_pk from an_cond, an_set_cond_link, $fclause where $wclause and an_set_cond_link.an_set_fk=? and an_set_cond_link.an_cond_fk=an_cond.an_cond_pk";
  my $sth1 = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
                                                                                                               
  ($fclause, $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk);
  $sql = "select am_pk from arraymeasurement, an_cond_am_link, $fclause where $wclause and an_cond_am_link.an_cond_fk=? and an_cond_am_link.am_fk=arraymeasurement.am_pk";
  my $sth2 = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
                                                                                                               
  $sth1->execute($an_set_pk) || die "Execute $sql \n$DBI::errstr";
                                                                                                               
  while($chref1 = $sth1->fetchrow_hashref()){
                                                                                                               
    $sth2->execute($chref1->{an_cond_pk}) || die "Execute $sql \n$DBI::errstr";
    my @am_pk_array;
                                                                                                               
    while($chref2 = $sth2->fetchrow_hashref()){
                                                                                                               
      push @am_pk_array, $chref2->{am_pk};
                                                                                                               
    }
                                                                                                               
    $analysis_hash{$chref1->{an_cond_pk}} = \@am_pk_array;
                                                                                                               
  }
                                                                                                               
  return %analysis_hash;
                                                                                                               
} #create_analysis_hash_from_an_set


## create_an_fi
## 8-10-04  Steve Tropello
## Creates an analysis file from an analysis hash
## Return fi_pk of newly created file
sub create_an_fi
{
    my $dbh = $_[0];
    my $chref = $_[1];
    my %ana = %{$_[2]};
    my $us_fk = $_[3];
    my $extract_type = $_[4];
    my @am_pk_list;
    my %ch = %$chref;
    my $al_pk;                                                                                                           
    my $conds = "";
    my $cond_tween = "";
    my $curr_cond_count;
    my $cond_label1 = "";
    my $cond_label2 = "probe_set_name";
    my ($fclause, $wclause) = read_where_clause("an_cond", "an_cond_pk", $us_fk);
    my $sql = "select an_cond_pk, an_cond_name, an_cond_created from an_cond, an_set_cond_link, $fclause where $wclause and an_cond.an_cond_pk=?";
    my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
    my $cname_sth = getq("hyb_info", $dbh);
                                                                                                               
    foreach my $an_cond_pk (keys(%ana))
    {
      $curr_cond_count = 0;
      $sth->execute($an_cond_pk) || die "Execute $sql \n$DBI::errstr"; 
      my $chref = $sth->fetchrow_hashref();
      $sth->finish();

      if ($cond_label1 ne ""){

        $cond_label1 .= ",";
      }

      $cond_label1 .= "\"" . $chref->{an_cond_name} . "\"";
                                                                                                               
      foreach my $am_pk (@{$ana{$an_cond_pk}}){

        $curr_cond_count++;
        push(@am_pk_list,$am_pk);
        $cname_sth->execute($am_pk) || die "Execute $sql \n$DBI::errstr";
        my $hr = $cname_sth->fetchrow_hashref();
        $cname_sth->finish();
        $cond_label2 .= "\t$hr->{hybridization_name}";
      }

      $conds .= "$cond_tween$curr_cond_count";
      $cond_tween = ",";
    }
                                                                                                               
    my %all_data;
    $sth = getq("get_spot_identifier", $dbh);
    $sth->execute($am_pk_list[0]) || die "Execute $sql \n$DBI::errstr";

    while((my $als_pk, my $spot_identifier, my $usf_name) = $sth->fetchrow_array()){

      $all_data{$als_pk} = "$spot_identifier | $usf_name";

    }

    $sth = getq("get_signal", $dbh);
    my $sth2 = getq("al_pk_by_am_pk", $dbh);

    foreach my $am_pk (@am_pk_list){
      $sth2->execute($am_pk) || die "execute al_pk_by_am_pk\n$DBI::errstr\n";
      if ($al_pk eq "")
      {
        $al_pk = $sth2->fetchrow_array();
      }
      else
      {
        if ($al_pk ne $sth2->fetchrow_array())
        {
          set_session_val($dbh, $us_fk, "message", "warnmessage", 
            get_message("WARN_LAYOUT_MISMATCH"));
        }
      }
    
      # fetch data
      $sth->execute($am_pk) || die "Execute $sql \n$DBI::errstr";

      while((my $als_fk, my $signal) = $sth->fetchrow_array()){

        $all_data{$als_fk} .= "\t$signal";
  
      }

    }
                                                                                                               
    open(OUT, "> $ch{file_name}") || die "sub create_an_fi: cannot open $ch{file_name}: $!\n";
                                                                                                               
    my $rec_count = 0;
    my $uai = 1;
    if ($extract_type =~ m/human/i){

      $cond_label1 = $cond_label2; # set so we write to file_info below
      print OUT "$conds\n";
      $uai = 0;
  
    }
                                                                                                               
    # currently want to print out column headers
    # may change to write to db like conds
    print OUT "$cond_label2\n";

    foreach my $spot_identifier (keys(%all_data)){

      print OUT "$all_data{$spot_identifier}\n";
      $rec_count++;

    }

    close(OUT);
    chmod(0777, $ch{file_name});

    my $fi_pk = fi_update($dbh,
                          $us_fk,
                          $us_fk,
                          $ch{file_name},
                          $ch{fi_comments},
                          $conds,
                          $cond_label1,
                          undef,            # not associated with a node
                          $uai,             # this can be an input file
                          undef,            # ft_fk
                          432,              # permissions
                          $al_pk);          # chip type

    return  $fi_pk;

} # create_an_fi

sub check_tree_name
{
  my ($dbh, $us_fk, $treename) = @_;

  my $badname = 0;
  my $sql = "select tree_name from tree where tree_name = '$treename'";
  my $sth = $dbh->prepare($sql) || die "check_tree_name: prepare $sql\n$DBI::errstr\n";
  $sth->execute()  || die "check_tree_name: execute $sql\n$DBI::errstr\n";

  my $msg;
  while ((my $name) = $sth->fetchrow_array())
  {
    $badname = "NAME_MUST_BE_UNIQUE";
  }
  $sth->finish();

  if ($treename eq "")
  {
    $badname = "NAME_CANT_BE_BLANK";
  }

  return($badname);
}

sub get_default_nodes
{
  my ($dbh, $us_fk) = @_;
  my @nodes = ();

  my $sql = "select an_pk from analysis where an_name=? and version=
    (select max(version) from analysis where an_name=?)";
  my $sth = $dbh->prepare($sql) || die "get_default_nodes $sql\n$DBI::errstr\n";
  
  # current version of Quality Control
  $sth->execute("Quality Control", "Quality Control")
    || die "get_default_nodes execute qc\n$DBI::errstr\n";
  (my $temp) = $sth->fetchrow_array();
  push @nodes, $temp;
  # current version of Differential Discovery
  $sth->execute("Differential Discovery", "Differential Discovery")
    || die "get_default_nodes execute diffDisc\n$DBI::errstr\n";
  ($temp) = $sth->fetchrow_array();
  push @nodes, $temp;
  # current version of Filter
  $sth->execute("Filter", "Filter")
    || die "get_default_nodes execute filter\n$DBI::errstr\n";
  ($temp) = $sth->fetchrow_array();
  push @nodes, $temp;
  # current version of Cluster
  $sth->execute("Cluster", "Cluster")
    || die "get_default_nodes execute cluster\n$DBI::errstr\n";
  ($temp) = $sth->fetchrow_array();
  push @nodes, $temp;

  my $length = length(@nodes);
 
  return(@nodes);
}

sub create_default_an_tree
{
  my ($dbh, $us_fk, $chref, $fi_pk) = @_;

  my @nodes=get_default_nodes($dbh, $us_fk);

  $chref->{file_name} =~ /.*\/(.*)\.(.*)/;
  my $basename = $1;
  my $treename = "$1";
  my $badname = check_tree_name($dbh, $us_fk, $treename);
  my $tree_pk;
  if (! $badname)
  {
    my $current_node=shift(@nodes);
    ($tree_pk, my $parent_node) = insert_tree($dbh, $us_fk, $treename, $fi_pk, $current_node);
    while ($#nodes > -1)
    {
      $current_node= shift(@nodes);
      my $sth = getq("insert_tree_node", $dbh);
      $sth->execute($tree_pk, $parent_node, $current_node);
      my $node_pk = insert_security($dbh, $us_fk, $us_fk, 0);
      $parent_node=$node_pk;
      init_node($dbh, $node_pk, $current_node);
    }
    $dbh->commit();
  }
  return ($tree_pk);
}


##
##DELETE SUBS
##


## delete_an_cond
## 8-10-04  Steve Tropello
## Deletes specified an_cond; an_cond_am_links automatically dropped in DB
## Return null
sub delete_an_cond
{
    my $dbh = $_[0];
    my $an_cond_pk = $_[1];
                                                                                                          
    # Delete the analysis condition
    my $sql = "DELETE FROM an_cond WHERE an_cond_pk=$an_cond_pk";
    my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
    $sth->execute() || die "Execute $sql \n$DBI::errstr";
                                                                                                          
    delete_security($dbh, $an_cond_pk);
                                                                                                          
} #delete_an_cond


## delete_an_set
## 8-10-04  Steve Tropello
## Deletes specified an_set; an_set_cond_links automatically dropped in DB
## Return null
sub delete_an_set
{
    my $dbh = $_[0];
    my $an_set_pk = $_[1];
                                                                                                          
    #Delete the analysis set
    my $sql = "DELETE FROM an_set WHERE an_set_pk=$an_set_pk";
    my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
    $sth->execute() || die "Execute $sql \n$DBI::errstr";
                                                                                                          
    delete_security($dbh, $an_set_pk);
                                                                                                          
} #delete_an_set


## delete_an_cond_am_links
## 8-10-04  Steve Tropello
## Deletes all links in an_cond_am_link for a specified array of ams
## Return null
sub delete_an_cond_am_links
{
  my ($array_ref, $an_cond_fk, $dbh) = @_;
  my @am_pk_array = @{ $array_ref };
  my $am_pk;
                                                                                                          
  foreach $am_pk (@am_pk_array){
                                                                                                          
   my $sql = "DELETE from an_cond_am_link where am_fk=$am_pk and an_cond_fk=$an_cond_fk";
   $dbh->do($sql) || die "Do $sql \n$DBI::errstr";
                                                                                                          
  }
} #delete_an_cond_am_links


## delete_an_set_cond_links
## 8-10-04  Steve Tropello
## Deletes all links in an_set_cond_link for a specified array of an_conds
## Return null
sub delete_an_set_cond_links
{
                                                                                                          
                                                                                                          
  my ($array_ref, $an_set_pk,$dbh) = @_;
  my @an_cond_pk_array = @{ $array_ref };
  my $an_cond_pk;
                                                                                                          
  foreach $an_cond_pk (@an_cond_pk_array){
                                                                                                          
    my $sql = "DELETE from an_set_cond_link where an_cond_fk=$an_cond_pk and
      an_set_fk=$an_set_pk";
    $dbh->do($sql) || die "Do $sql \n$DBI::errstr";
                                                                                                          
  }
                                                                                                          
                                                                                                          
} #delete_an_cond_links



##
## GET SUBS
##

## get_an_cond
## 8-10-04  Steve Tropello
## Gets an_cond name, description and creation time for a specific an_cond_pk
## Return $an_cond_name, $an_cond_description, $an_cond_created
sub get_an_cond
{
  my ($dbh, $an_cond_pk) = @_;

  my $sql = "select * from an_cond where an_cond_pk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_cond_pk) || die "Execute $sql \n$DBI::errstr";

  my $chref = $sth->fetchrow_hashref();

  return ($chref->{an_cond_name}, $chref->{an_cond_desc}, $chref->{an_cond_created});

} #get_an_cond


## get_an_set
## 8-10-04  Steve Tropello
## Gets an_set name, description and creation time for a specific an_set_pk
## Return $an_set_name, $an_set_description, $an_set_created
sub get_an_set
{
  my ($dbh, $an_set_pk) = @_;

  my $sql = "select * from an_set where an_set_pk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_set_pk) || die "Execute $sql \n$DBI::errstr";

  my $chref = $sth->fetchrow_hashref();


  return ($chref->{an_set_name}, $chref->{an_set_desc}, $chref->{an_set_created});

} #get_an_set


## get_number_ams_in_an_cond
## 8-10-04  Steve Tropello
## Gets the number of ams linked to a specific an_cond_pk in an_cond_am_link
## Return $count
sub get_number_ams_in_an_cond
{

  my ($an_cond_pk, $dbh) = @_;

  my $sql = "select count(*) from an_cond_am_link where an_cond_fk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_cond_pk) || die "Execute $sql \n$DBI::errstr";
  my $count = $sth->fetchrow_array();

  return $count;

} #get_number_ams_in_an_cond


## get_number_an_conds_in_an_set
## 8-10-04  Steve Tropello
## Gets the number of an_conds linked to a specific an_set_pk in an_set_cond_link
## Return $count
sub get_number_an_conds_in_an_set
{
                                                                                                            
  my ($an_set_pk, $dbh) = @_;
                                                                                                            
  my $sql = "select count(*) from an_set_cond_link where an_set_fk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_set_pk) || die "Execute $sql \n$DBI::errstr";
  my $count = $sth->fetchrow_array();

  return $count;
                                                                                                            
} #get_number_an_conds_in_an_set


## get_study
## 8-10-04  Steve Tropello
## Gets study name and description for a specific sty_pk
## Return $study_name, $sty_comments
sub get_study
{
  my ($dbh, $sty_pk) = @_;

  my $sql = "select * from study where sty_pk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($sty_pk) || die "Execute $sql \n$DBI::errstr";

  my $chref = $sth->fetchrow_hashref();

  return ($chref->{study_name}, $chref->{sty_comments});

} #get_study


## get_users_group
## 8-10-04  Steve Tropello
## Gets user's default group
## Return $gs_pk
sub get_users_group
{

  my ($dbh, $us_fk, $login) = @_;

  my $sql = "select gs_pk from groupsec where gs_owner=? and gs_name=trim(?)";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($us_fk, $login) || die "Execute $sql \n$DBI::errstr";
  my $chref = $sth->fetchrow_hashref();

  return $chref->{gs_pk};

} #get_users_group


##
## INSERT SUBS
##


## insert_an_conds_into_an_set
## 8-10-04  Steve Tropello
## Inserts an array of an_conds into a specific an_set_pk (no duplicate inserts)
## Return null
sub insert_an_conds_into_an_set
{

  my ($an_set_pk, $key_array_ref, $dbh, $key_type) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;

  my $us_fk = get_us_fk($dbh, "add_am_to_an_cond.cgi");

  $sql = "select * from an_set_cond_link where an_set_fk=? and an_cond_fk=?";
  my $sth_check_link = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sql = "insert into an_set_cond_link (an_set_fk, an_cond_fk) values (?, ?)";
  my $sth_insert_link = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";

  my $set_chiptype = "";
  foreach $key_value (@key_array){

    # get the current chip type of the an_set
    $set_chiptype = getq_an_set_chiptype($dbh, $us_fk, $an_set_pk) if ($set_chiptype eq "");

      $sth_check_link->execute($an_set_pk, $key_value) || die "Execute $sql \n$DBI::errstr";

      if ($sth_check_link->rows() eq 0){
        # verify that the chiptype is correct
        my $cond_chiptype = getq_an_cond_chiptype($dbh, $us_fk, $key_value);
        if (($set_chiptype eq "") || ($cond_chiptype eq $set_chiptype))
        {
          $sth_insert_link->execute($an_set_pk, $key_value) || die "Execute $sql \n$DBI::errstr";
        }
        else
        {
          set_session_val($dbh, $us_fk, "message", "errmessage", 
            get_message("LAYOUT_MISMATCH"));
        }
      }

  }

} #insert_an_conds_into_an_set


## insert_criteria_into_an_cond
## 8-10-04  Steve Tropello
## Inserts criteria specified ams (via hybridization_name) into a specific an_cond_pk
## Return null
sub insert_criteria_into_an_cond
{
                                                                                                               
  my ($criteria_hashref, $chref, $dbh) = @_;
  my %criteria_hash = %$criteria_hashref;
  my %ch = %$chref;
  my %hybridization_name_hash;
  my @hybridization_name_array;
                                                                                                               
  %hybridization_name_hash = calculate_continuous_criteria(\%criteria_hash, \%ch, \%hybridization_name_hash);
  %hybridization_name_hash = calculate_categorical_criteria(\%criteria_hash, \%ch, \%hybridization_name_hash);
  @hybridization_name_array = merge_arrays(\%criteria_hash, \%hybridization_name_hash);
                                                                                                               
  insert_ams_into_an_cond($ch{an_cond_pk}, \@hybridization_name_array, $dbh, "hybridization_name");
                                                                                                               
}  #insert_criteria_into_an_cond


## insert_exp_conditions_into_an_set
## 8-10-04  Steve Tropello
## Inserts an array of exp_conditions into a specific an_set_pk (duplicates allowed via new an_conds)
## Return null
sub insert_exp_conditions_into_an_set
{

  my ($an_set_pk, $key_array_ref, $dbh) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;
  my $ec_pk;
  my $name;
  my $description;
  my $an_cond_pk;
  my @an_cond_array;

  my $us_fk = get_us_fk($dbh, "add_am_to_an_cond.cgi");
  my $login = doq($dbh, "get_login", $us_fk);
  my $gs_fk = get_users_group($dbh, $us_fk, $login);

  (my $fclause, my $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk );
  $sql = "select am_pk from arraymeasurement, sample, $fclause where $wclause and sample.ec_fk=? and sample.smp_pk=arraymeasurement.smp_fk";
  my $sth_am = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";

  ($fclause, $wclause) = read_where_clause("exp_condition", "ec_pk", $us_fk);
  $sql = "select ec_pk, name, description from exp_condition, $fclause where $wclause and exp_condition.ec_pk=?";
  my $sth_exp_condition = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";

  foreach $key_value (@key_array){

    $sth_exp_condition->execute($key_value) || die "Execute $sql \n$DBI::errstr";
    ($ec_pk, $name, $description) = $sth_exp_condition->fetchrow_array();
    $an_cond_pk = create_an_cond($dbh, $name, $description, $us_fk, $gs_fk);

    my $chref;
    my @am_array;
    $sth_am->execute($key_value) || die "Execute $sql \n$DBI::errstr";

    while($chref = $sth_am->fetchrow_hashref()){

      push @am_array, $chref->{am_pk};

    }

    insert_ams_into_an_cond($an_cond_pk, \@am_array, $dbh, "am_pk");
    push @an_cond_array, $an_cond_pk;

  }

    insert_an_conds_into_an_set($an_set_pk, \@an_cond_array, $dbh);

} #insert_exp_conditions_into_an_set


## insert_studies_into_an_set
## 8-10-04  Steve Tropello
## Inserts an array of studies into a specific an_set_pk (duplicate inserts allowed via new an_conds)
## Return null
sub insert_studies_into_an_set
{

  my ($an_set_pk, $key_array_ref, $dbh) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;
  my @exp_condition_array;

  my $us_fk = get_us_fk($dbh, "add_am_to_an_cond.cgi");
  (my $fclause, my $wclause) = read_where_clause("exp_condition", "ec_pk", $us_fk );
  $sql = "select ec_pk from exp_condition, study, $fclause where $wclause and exp_condition.sty_fk=study.sty_pk and exp_condition.sty_fk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";

  foreach $key_value (@key_array){

    $sth->execute($key_value) || die "Execute $sql \n$DBI::errstr";

    my $chref;
    while($chref = $sth->fetchrow_hashref()){

      push @exp_condition_array, $chref->{ec_pk};

    }

  }

    insert_exp_conditions_into_an_set($an_set_pk, \@exp_condition_array, $dbh);

} #insert_studies_into_an_set


## insert_criteria_an_conds_into_an_set
## 8-10-04  Steve Tropello
## Inserts specified conditions within criteria file into a specified an_set_pk (duplicate inserts allowed via new an_conds)
## Return null
sub insert_criteria_an_conds_into_an_set
{
                                                                                                                   
  my ($an_set_pk, $criteria_hash_ref, $dbh) = @_;
  my %criteria_hash = %$criteria_hash_ref;
  my @field_name_array = get_field_names(\%criteria_hash, "categorical");
  my $field_name;
  my @value_array;
  my $value;
                                                                                                                   
  my $us_fk = get_us_fk($dbh, "add_am_to_an_cond.cgi");
  my $login = doq($dbh, "get_login", $us_fk);
  my $gs_fk = get_users_group($dbh, $us_fk, $login);
                                                                                                                   
  foreach $field_name (@field_name_array){
                                                                                                                   
    if (lc($field_name) =~ m/::condition/){
                                                                                                                   
      @value_array = get_possible_values(\%criteria_hash, $field_name);
      my @an_cond_array;
                                                                                                                   
      foreach $value (@value_array){
                                                                                                                   
        my $an_cond_pk = create_an_cond($dbh, $value, $field_name, $us_fk, $gs_fk);
        my @hybridization_name_array = get_equal_hybridization_names(\%criteria_hash, $field_name, $value);
        insert_ams_into_an_cond($an_cond_pk, \@hybridization_name_array, $dbh, "hybridization_name");
        push @an_cond_array, $an_cond_pk;
                                                                                                                   
       }
                                                                                                                   
       insert_an_conds_into_an_set($an_set_pk, \@an_cond_array, $dbh);
                                                                                                                   
     }
                                                                                                                   
  }
                                                                                                                   
} #insert_criteria_an_conds_into_an_set



## insert_ams_into_an_cond
## 8-10-04  Steve Tropello
## Inserts an array of ams into a specific an_cond_pk (no duplicate am inserts)
## Return null
sub insert_ams_into_an_cond
{

  my ($an_cond_pk, $key_array_ref, $dbh, $key_type) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;
  my $us_fk = get_us_fk($dbh, "add_am_to_an_cond.cgi");
  (my $fclause, my $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk );


  if ($key_type eq "hybridization_name"){

    $sql = "select am_pk from arraymeasurement, $fclause where $wclause and hybridization_name=trim(?)";

  }
  else {

    $sql = "select am_pk from arraymeasurement, $fclause where $wclause and am_pk=?";

  }

  my $sth_get_am_pk = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sql = "select * from an_cond_am_link where an_cond_fk=? and am_fk=?";
  my $sth_check_link = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sql = "insert into an_cond_am_link (an_cond_fk, am_fk) values (?, ?)";
  my $sth_insert_link = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";

  my $cond_chiptype = "";
  foreach $key_value (@key_array){

    # get the current chip type of the condition
    $cond_chiptype = getq_an_cond_chiptype($dbh, $us_fk, $an_cond_pk) if ($cond_chiptype eq "");

    $sth_get_am_pk->execute($key_value) || die "Execute $sql \n$DBI::errstr";

    if ($sth_get_am_pk->rows() eq 1){

      my ($am_pk) = $sth_get_am_pk->fetchrow_array();

      $sth_check_link->execute($an_cond_pk, $am_pk) || die "Execute $sql \n$DBI::errstr";

      if ($sth_check_link->rows() eq 0){
        # verify that the chiptype is correct
        my $am_chiptype = getq_chiptype($dbh, $us_fk, $am_pk);
        if (($cond_chiptype eq "") || ($am_chiptype eq $cond_chiptype))
        {
          $sth_insert_link->execute($an_cond_pk, $am_pk) || die "Execute $sql \n$DBI::errstr";
        }
        else
        {
          set_session_val($dbh, $us_fk, "message", "errmessage", 
            get_message("LAYOUT_MISMATCH"));
        }
      }

    }

  }

} #insert_ams_into_an_cond


## insert_an_conds_into_an_cond
## 8-10-04  Steve Tropello
## Inserts an array of an_conds into a specific an_cond_pk (no duplicate am inserts)
## Return null
sub insert_an_conds_into_an_cond
{
                                                                                                                       
  my ($an_cond_pk, $key_array_ref, $dbh) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;
  my @am_array;

  my $us_fk = get_us_fk($dbh, "insert_am_to_an_cond.cgi");
  (my $fclause, my $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk );
  $sql = "select am_pk from arraymeasurement, an_cond_am_link, $fclause where $wclause and an_cond_am_link.an_cond_fk=? and an_cond_am_link.am_fk=arraymeasurement.am_pk";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";

  foreach $key_value (@key_array){
    $sth->execute($key_value) || die "Execute $sql \n$DBI::errstr";

    my $chref;
    while($chref = $sth->fetchrow_hashref()){
                                                                                                                       
      push @am_array, $chref->{am_pk};
                                                                                                                       
    }
                                                                                                                       
  }
                                                                                                                       
  insert_ams_into_an_cond($an_cond_pk, \@am_array, $dbh, "am_pk");
                                                                                                                       
} #insert_an_conds_into_an_cond


## insert_exp_conditions_into_an_cond
## 8-10-04  Steve Tropello
## Inserts an array of exp_conditions into a specific an_cond_pk (no duplicate am inserts)
## Return null
sub insert_exp_conditions_into_an_cond
{

  my ($an_cond_pk, $key_array_ref, $dbh) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;
  my @am_array;

  my $us_fk = get_us_fk($dbh, "insert_am_to_an_cond.cgi");
  (my $fclause, my $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk );
  $sql = "select am_pk from arraymeasurement, sample, $fclause where $wclause and sample.ec_fk=? and sample.smp_pk=arraymeasurement.smp_fk";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
                                                                                                                       
  foreach $key_value (@key_array){
                                                                                                                       
    $sth->execute($key_value) || die "Execute $sql \n$DBI::errstr";
                                                                                                                       
    my $chref;
    while($chref = $sth->fetchrow_hashref()){
                                                                                                                       
      push @am_array, $chref->{am_pk};
                                                                                                                       
    }
                                                                                                                       
  }
                                                                                                                       
  insert_ams_into_an_cond($an_cond_pk, \@am_array, $dbh, "am_pk");
                                                                                                                       
} #insert_exp_condition_into_an_cond


## insert_studies_into_an_cond
## 8-10-04  Steve Tropello
## Inserts an array of studies into a specific an_cond_pk (no duplicate am inserts)
## Return null
sub insert_studies_into_an_cond
{

  my ($an_cond_pk, $key_array_ref, $dbh) = @_;
  my @key_array = @{ $key_array_ref };
  my $key_value;
  my $sql;
  my @exp_condition_array;

  my $us_fk = get_us_fk($dbh, "insert_am_to_an_cond.cgi");
  (my $fclause, my $wclause) = read_where_clause("exp_condition", "ec_pk", $us_fk );
  $sql = "select ec_pk from exp_condition, study, $fclause where $wclause and exp_condition.sty_fk=study.sty_pk and exp_condition.sty_fk=?";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
                                                                                                                       
  foreach $key_value (@key_array){
                                                                                                                       
    $sth->execute($key_value) || die "Execute $sql \n$DBI::errstr";
                                                                                                                       
    my $chref;
    while($chref = $sth->fetchrow_hashref()){
                                                                                                                       
      push @exp_condition_array, $chref->{ec_pk};
                                                                                                                       
    }
                                                                                                                       
  }
                                                                                                                       
  insert_exp_conditions_into_an_cond($an_cond_pk, \@exp_condition_array, $dbh);
                                                                                                                       
} #insert_studies_into_an_cond


##
## UPDATE SUBS
##


## update_an_cond
## 8-10-04  Steve Tropello
## Updates specified name and description values for a specific an_cond
## Return null
sub update_an_cond
{
                                                                                                          
  my ($an_cond_pk, $an_cond_name, $an_cond_desc, $dbh) = @_;
                                                                                                          
  my $sql;
  if ($an_cond_name eq "")
  {
    $sql = "update an_cond set an_cond_desc=trim(?) where an_cond_pk=$an_cond_pk";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_cond_desc) || die "Execute $sql \n$DBI::errstr";
  }
  else
  {
    $sql = "update an_cond set an_cond_name=trim(?), an_cond_desc=trim(?) where an_cond_pk=$an_cond_pk";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute($an_cond_name, $an_cond_desc) || die "Execute $sql \n$DBI::errstr";
  }
                                                                                                          
} #update_an_cond


## update_an_set 
## 8-10-04  Steve Tropello
## Updates specified name and description values for a specific an_set
## Return null
sub update_an_set
{
                                                                                                          
  my ($an_set_pk, $an_set_name, $an_set_desc, $dbh) = @_;
                                                                                                          
  my $sql;
  if ($an_set_name eq "")
  {
     $sql = "update an_set set an_set_desc=trim(?) where an_set_pk=$an_set_pk";
     my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
     $sth->execute($an_set_desc) || die "Execute $sql \n$DBI::errstr";
  }
  else
  {
     $sql = "update an_set set an_set_name=trim(?), an_set_desc=trim(?) where an_set_pk=$an_set_pk";
     my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
     $sth->execute($an_set_name, $an_set_desc) || die "Execute $sql \n$DBI::errstr";
  }
} #update_an_set



##
## GET HTML SUBS
##


## get_select_groups_html
## 8-10-04  Steve Tropello
## Generates select box html of all groups for a us_fk
## Return $html_string
sub get_select_groups_html
{
    my $dbh = $_[0];
    my $us_fk = $_[1];
    my $login = $_[2];
    my $sth = getq("user_pi", $dbh);
    $sth->execute($us_fk,$us_fk) || die "Execute $sth \n$DBI::errstr";
    my $hr;
    my $html_string = "<select name=\"pi_info\">\n";

    while($hr = $sth->fetchrow_hashref())
    {
      if ($login eq $hr->{gs_name}){

        $html_string .= "<option selected value=\"$hr->{gs_owner},$hr->{gs_pk}\">$hr->{contact_fname} $hr->{contact_lname}/$hr->{gs_name}</option>\n";

      }

      else {

        $html_string .= "<option value=\"$hr->{gs_owner},$hr->{gs_pk}\">$hr->{contact_fname} $hr->{contact_lname}/$hr->{gs_name}</option>\n";

      }

    }

    $html_string .= "</select>\n";
    return $html_string;

} #get_select_groups_html


## get_an_cond_html
## 8-10-04  Steve Tropello
## Generates html of all readable an_conds to us_fk
## Return $html_string
sub get_an_cond_html
{

  my ($ch_ref, $dbh, $us_fk) = @_;
  my %ch = %$ch_ref;
  my $html_string;

  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=9>Analysis Conditions To Include</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=an_cond_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=an_cond_name::desc></td>\n";
  $html_string .= "<td>Description</td>\n";
  $html_string .= "<td>Created <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=an_cond_created::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=an_cond_created::desc></td>\n";
  $html_string .= "<td># of Hybridizations</td>\n";
  $html_string .= "<td>Chip Type<input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=chiptype::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=chiptype::desc></td>\n";
  $html_string .= "<td>Owner <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=login::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=login::desc></td>\n";
  $html_string .= "<td>Group <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=gs_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=gs_name::desc></td>\n";
  $html_string .= "<td>Edit</td>\n";
  $html_string .= "</tr>\n";

  ## Set default order value
  my $field = "an_cond_pk";
  my $order = "desc";

  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }

  # Show the user a list of analysis conditions that are read and write by the user.
  (my $fclause, my $wclause) = read_where_clause("an_cond", "an_cond_pk", $us_fk);
  my $sql = "select an_cond_pk, an_cond_name, an_cond_desc, an_cond_created, login, gs_name from an_cond, groupsec, usersec, $fclause where $wclause and ref_fk=an_cond_pk and groupref.gs_fk=gs_pk and gs_owner=us_pk order by $field $order";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";

  my $chref;
  my $print;
  while($chref = $sth->fetchrow_hashref())
  {

    $print = 0;

    if ($ch{an_set_pk} ne ""){

      if(!exist_an_set_cond_link($dbh, $ch{an_set_pk}, $chref->{an_cond_pk})){

        $print = 1;  #print if an_cond not in an_set
    
      }

    }
    else {

      if ($ch{an_cond_pk} ne $chref->{an_cond_pk}){

        $print = 1; #print if not an_cond editting

      }

    }

    if ($print){

      # format creation date of analysis condition
      $chref->{an_cond_created} = sql2date($chref->{an_cond_created});

      #create short description of 40 chars
      $chref->{an_cond_desc} = substr($chref->{an_cond_desc}, 0, 40);
      $chref->{an_cond_desc} .= "..." if (length($chref->{an_cond_desc}) > 39);

      $chref->{number_of_hybridizations} = get_number_ams_in_an_cond($chref->{an_cond_pk}, $dbh);
      $chref->{chiptype} = getq_an_cond_chiptype($dbh, $us_fk, $chref->{an_cond_pk});

      $html_string .= "<tr>\n";
      $html_string .= "<td><input type=checkbox name=an_cond_pks value=\"$chref->{an_cond_pk}\"></td>\n";
      $html_string .= "<td>$chref->{an_cond_name}</td>\n";
      $html_string .= "<td>$chref->{an_cond_desc}</td>\n";
      $html_string .= "<td>$chref->{an_cond_created}</td>\n";
      $html_string .= "<td>$chref->{number_of_hybridizations}</td>\n";
      $html_string .= "<td>$chref->{chiptype}</td>\n";
      $html_string .= "<td>$chref->{login}</td>\n";
      $html_string .= "<td>$chref->{gs_name}</td>\n";

      if (is_writable($dbh, "an_cond", "an_cond_pk", $chref->{an_cond_pk}, $us_fk)){

        $html_string .= "<td><input type=image border=0
          name=edit_an_cond_$chref->{an_cond_pk} value=\"$chref->{an_cond_pk}\" src=\"../graphics/pencil.gif\" width=25 height=25></td>\n";

      }
      else {

        $html_string .= "<td>----</td>\n";

      }

      $html_string .= "</tr>\n";

    }
  }

  $html_string .= "</table>\n";

  return $html_string;

} #get_an_cond_html


## get_an_set_html
## 8-10-04  Steve Tropello
## Generates html of all readable an_sets to us_fk
## Return $html_string
sub get_an_set_html
{

  my ($dbh, $us_fk, $ch_ref) = @_;
  my %ch = %$ch_ref;
  my $html_string;

  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=9>Analysis Sets</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=an_set_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=an_set_name::desc></td>\n";
  $html_string .= "<td>Description</td>\n";
  $html_string .= "<td>Created <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=an_set_created::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=an_set_created::desc></td>\n";
  $html_string .= "<td># of Conditions</td>\n";
  $html_string .= "<td>Chip Type <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=chiptype::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=chiptype::desc></td>\n";
  $html_string .= "<td>Owner <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=login::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=login::desc></td>\n";
  $html_string .= "<td>Group <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=gs_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=gs_name::desc></td>\n";
  $html_string .= "<td>Edit</td>\n";
  $html_string .= "</tr>\n";

  ## Set default order values
  my $field = "an_set_pk";
  my $order = "desc"; 

  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }

  # Show the user a list of analysis sets that are read and write by the user.
  (my $fclause, my $wclause) = read_where_clause("an_set", "an_set_pk", $us_fk);
  my $sql = "select an_set_pk, an_set_name, an_set_desc, an_set_created, login, gs_name from an_set, groupsec, usersec, $fclause where $wclause and ref_fk=an_set_pk and groupref.gs_fk=gs_pk and gs_owner=us_pk order by $field $order";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";

  my $chref;
  while($chref = $sth->fetchrow_hashref())
  {

    # format creation date of analysis set
    $chref->{an_set_created} = sql2date($chref->{an_set_created});

    #create short description of 40 chars
    $chref->{an_set_desc} = substr($chref->{an_set_desc}, 0, 40);
    $chref->{an_set_desc} .= "..." if (length($chref->{an_set_desc}) > 39);

    $chref->{number_of_an_conds} = get_number_an_conds_in_an_set($chref->{an_set_pk}, $dbh);
    $chref->{chiptype} = getq_an_set_chiptype($dbh, $us_fk, $chref->{an_set_pk});
    my $checked = "";
    if ($chref->{an_set_pk} == $ch{an_set_pk})
    {
      $checked = "checked";
    }

    if ($chref->{number_of_an_conds} > 1)
    {
      $html_string .= "<tr>\n";
      $html_string .= "<td><input type=radio name=an_set_pk" .
        " value=\"$chref->{an_set_pk}\" $checked></td>\n";
      $html_string .= "<td>$chref->{an_set_name}</td>\n";
      $html_string .= "<td>$chref->{an_set_desc}</td>\n";
      $html_string .= "<td>$chref->{an_set_created}</td>\n";
      $html_string .= "<td>$chref->{number_of_an_conds}</td>\n";
      $html_string .= "<td>$chref->{chiptype}</td>\n";
      $html_string .= "<td>$chref->{login}</td>\n";
      $html_string .= "<td>$chref->{gs_name}</td>\n";

      if (is_writable($dbh, "an_set", "an_set_pk", 
            $chref->{an_set_pk}, $us_fk))
      {
        $html_string .= "<td><input type=image border=0
          name=edit_an_set_$chref->{an_set_pk} " . 
          "value=\"$chref->{an_set_pk}\" src=\"../graphics/pencil.gif\" " .
          "width=25 height=25></td>\n";
      }
      else {

        $html_string .= "<td>----</td>\n";

      }

      $html_string .= "</tr>\n";
    }
  }

  $html_string .= "</table>\n";

  return $html_string;

} #get_an_set_html


## get_an_file_html
## Generates html of all valid analysis input files
## Return $html_string
sub get_an_file_html
{
  my ($dbh, $us_fk, $ch_ref) = @_;
  my %ch = %$ch_ref;
  my $html_string;
                                                                                                                       
  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=6>Analysis Input File</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>File Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=file_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=file_name::desc></td>\n";
  $html_string .= "<td>Condition Grouping <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=Condition_Grouping::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=Condition_Grouping::desc></td>\n";
  $html_string .= "<td>Condition Labels <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=Condition_Labels::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=Condition_Labels::desc></td>\n";
  $html_string .= "</tr>\n";
   

  my $field = "file_name";
  my $order = "desc";

  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }


  my $sql = "select fi_pk, file_name, conds, cond_labels, al_fk  from file_info,
     groupref, usersec, contact where us_fk=us_pk and con_fk=con_pk and
       ref_fk=fi_pk and use_as_input='t' and file_name like '%analysis_input%'";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";
  my $hr;
  while ($hr = $sth->fetchrow_hashref())
  {
      my $checked = "";
      if ($hr->{fi_pk} == $ch{fi_pk})
      {
        $checked = "checked";
      }


      $html_string .= "<tr>\n";
      $html_string .= "<td><input type=$ch{source_form_type} name=fi_pk
        value=\"$hr->{fi_pk}\" $checked></td>\n";
      $html_string .= "<td>$hr->{file_name}</td>\n";
      $html_string .= "<td>$hr->{conds}</td>\n";
      $html_string .= "<td>$hr->{cond_labels}</td>\n";
      $html_string .= "</tr>\n";
  }
  $html_string .= "</table>\n";

  return $html_string;
} 

## get_public_html
## Generates html of all public data
## Return $html_string
sub get_public_html
{
                                                                                                                       
  my ($dbh, $us_fk, $ch_ref) = @_;
  my %ch = %$ch_ref;
  my $html_string;
                                                                                                                       
  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=6>Public Data to Include</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>Published Study Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=miame_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=miame_name::desc></td>\n";
  $html_string .= "<td>Investigator <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=Investigator::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=Investigator::desc></td>\n";
  $html_string .= "</tr>\n";
   

  my $field = "miame_name";
  my $order = "desc";

  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }


  my $sql = "select miame_pk, miame_name, contact_fname, contact_lname from miame, groupref, usersec, contact where us_fk=us_pk and con_fk=con_pk and ref_fk=miame_pk";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";
  my $hr;
  while ($hr = $sth->fetchrow_hashref())
  {
      my (undef, $file_name, $conds, $cond_labels, $al_fk) =
          getq_miame_ana_fi_info($dbh, $us_fk, $hr->{miame_pk});

      my $checked = "";
      if ($hr->{miame_pk} == $ch{miame_pk})
      {
        $checked = "checked";
      }


      if ((-e $file_name) && ($conds) && ($cond_labels) && ($al_fk))
      {
        $hr->{investigator} = $hr->{contact_fname} . " " . 
          $hr->{contact_lname};
        $html_string .= "<tr>\n";
        $html_string .= "<td><input type=$ch{source_form_type} name=miame_pk
          value=\"$hr->{miame_pk}\" $checked></td>\n";
        $html_string .= "<td>$hr->{miame_name}</td>\n";
        $html_string .= "<td>$hr->{investigator}</td>\n";
        $html_string .= "</tr>\n";
      }
  }
  $html_string .= "</table>\n";

  return $html_string;
} #get_public_html


## get_study_html
## 8-10-04  Steve Tropello
## Generates html of all readable studies to us_fk
## Return $html_string
sub get_study_html
{

  my ($ch_ref, $dbh, $us_fk) = @_;
  my %ch = %$ch_ref;
  my $html_string;

  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=6>Studies To Include</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=name::desc></td>\n";
  $html_string .= "<td>Comments</td>\n";
  $html_string .= "<td>Owner <input type=image
    src=\"../graphics/sort_ascending.jpg\" name=order_by
    value=owner::asc> <input type=image
    src=\"../graphics/sort_descending.jpg\" name=order_by 
    value=owner::desc></td>\n";
  $html_string .= "<td>Group <input type=image
    src=\"../graphics/sort_ascending.jpg\" name=order_by value=group::asc> 
    <input type=image src=\"../graphics/sort_descending.jpg\" 
    name=order_by value=group::desc></td>\n";
  $html_string .= "</tr>\n";
   
  my @studies = GEOSS::Experiment::Study->new_list;
  if ($ch{order_by})
  {
    my ($field, $order_by) = split('::', $ch{order_by});
    warn "Field: $field Order_by: $order_by";
    # Schwartzain Transform (see perlfaq4) to avoid repeated db calls
    @studies = map { $_->[0] }
               sort { $a->[1] cmp $b->[1] } 
               map { [$_, 
                 $field eq "owner" ? $_->owner->name : 
                 $field eq "group" ? $_->group->name :
                 $_->name ] } @studies;
    @studies = reverse @studies if $order_by eq 'desc';
  }
  foreach my $study (@studies)
  {
      my $checked = ($study->{pk} == $ch{sty_pk}) ? "checked" : "";
      my @ec = $study->exp_conditions;
      if (($study->status eq "LOADED")  &&
          ( @ec > 1))
      {
        $html_string .= "<tr>\n";
        $html_string .= "<td><input type=$ch{source_form_type} name=sty_pk
          value=\"" . $study->pk . "\" $checked></td>\n";
        $html_string .= "<td>" . $study->name . "</td>\n";
        my $comments = (length($study->comments) > 39) ?
            substr($study->comments, 0, 40)  . "..." : $study->comments;
        $html_string .= "<td>" . $comments . "</td>\n";
        $html_string .= "<td>" . $study->owner->name . "</td>\n";
        $html_string .= "<td>" . $study->group->name . "</td>\n";
        $html_string .= "</tr>\n";
      }
  }
  $html_string .= "</table>\n";
  return $html_string;
} #get_study_html


## get_exp_condition_html
## 8-10-04  Steve Tropello
## Generates html of all readable exp_conditions to us_fk
## Return $html_string
sub get_exp_condition_html
{

  my ($ch_ref, $dbh, $us_fk) = @_;
  my %ch = %$ch_ref;
  my $html_string;

  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=6>Experimental Conditions To Include</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=name::desc></td>\n";
  $html_string .= "<td>Description</td>\n";
  $html_string .= "<td>Related Study <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=study_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=study_name::desc></td>\n";
  $html_string .= "<td>Owner <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=login::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=login::desc></td>\n";
  $html_string .= "<td>Group <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=gs_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=gs_name::desc></td>\n";
  $html_string .= "</tr>\n";

  ## Set default order values
  my $field = "ec_pk";
  my $order = "desc";

  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }

  # Show the user a list of experimental conditions that are read and write by the user.
  (my $fclause, my $wclause) = read_where_clause("exp_condition", "ec_pk", $us_fk);
  my $sql = "select distinct ec_pk, name, exp_condition.description,
     study_name, login, gs_name from exp_condition, study, sample,
     arraymeasurement, groupsec, usersec, $fclause where $wclause and
       study.sty_pk=exp_condition.sty_fk and ref_fk=ec_pk and
       groupref.gs_fk=gs_pk and gs_owner=us_pk and sty_pk=sty_fk and
       smp_pk=smp_fk and ec_pk = ec_fk and is_loaded = 't' order by $field $order";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";

  my $chref;
  while($chref = $sth->fetchrow_hashref())
  {

      #create short description
      $chref->{description} = substr($chref->{description}, 0, 40);
      $chref->{description} .= "..." if (length($chref->{description}) > 39);

      $html_string .= "<tr>\n";
      $html_string .= "<td><input type=checkbox name=ec_pk value=\"$chref->{ec_pk}\"></td>\n";
      $html_string .= "<td>$chref->{name}</td>\n";
      $html_string .= "<td>$chref->{description}</td>\n";
      $html_string .= "<td>$chref->{study_name}</td>\n";
      $html_string .= "<td>$chref->{login}</td>\n";
      $html_string .= "<td>$chref->{gs_name}</td>\n";
      $html_string .= "</tr>\n";

  }

  $html_string .= "</table>\n";

  return $html_string;

} #get_exp_condition_html


## get_am_html
## 8-10-04  Steve Tropello
## Generates html of all readable ams to us_fk
## Return $html_string
sub get_am_html
{

  my ($ch_ref, $dbh, $us_fk) = @_;
  my %ch = %$ch_ref;
  my $html_string;

  $html_string .= "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">\n";
  $html_string .= "<tr><td colspan=6>Hybridizations To Include</td></tr>\n";
  $html_string .= "<tr valign=\"top\">\n";
  $html_string .= "<td width=40>Add</td>\n";
  $html_string .= "<td>Name <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=hybridization_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=hybridization_name::desc></td>\n";
  $html_string .= "<td>Sample <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=smp_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=smp_name::desc></td>\n";
  $html_string .= "<td>Owner <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=login::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=login::desc></td>\n";
  $html_string .= "<td>Group <input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=gs_name::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=gs_name::desc></td>\n";
  $html_string .= "<td>Chip Type<input type=image src=\"../graphics/sort_ascending.jpg\" name=order_by value=chiptype::asc> <input type=image src=\"../graphics/sort_descending.jpg\" name=order_by value=chiptype::desc></td>\n";
  $html_string .= "</tr>\n";

  ## Set default order values
  my $field = "am_pk";
  my $order = "desc";

  if ($ch{order_by} ne ""){

    ($field, $order) = split('::', $ch{order_by});

  }

  # Show the user a list of hybridizations that are read and write by the user.
  (my $fclause, my $wclause) = read_where_clause("arraymeasurement", "am_pk", $us_fk);
  my $sql = "select am_pk, hybridization_name, login, gs_name from arraymeasurement, groupsec, usersec, $fclause where $wclause and ref_fk=am_pk and groupref.gs_fk=gs_pk and gs_owner=us_pk and is_loaded = 't' and date_loaded is not NULL order by $field $order";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";

  my $chref;
  while($chref = $sth->fetchrow_hashref())
  {
    # sample name must be selected separately, as uploaded hybridzations
    # won't have one, but should be included in the results
    my $sql2 = "select smp_name from sample, arraymeasurement where smp_fk = smp_pk and am_pk='$chref->{am_pk}'";
    my $sth2 = $dbh->prepare($sql2) || die "Prepare $sql2 \n$DBI::errstr";
    $sth2->execute() || die "Execute $sql2 \n$DBI::errstr";
    (my $smp_name) = $sth2->fetchrow_array();
    $chref->{chiptype} = getq_chiptype($dbh, $us_fk, $chref->{am_pk});

    if(!exist_an_cond_am_link($dbh, $ch{an_cond_pk}, $chref->{am_pk})){

      $html_string .= "<tr>\n";
      $html_string .= "<td><input type=checkbox name=am_pk value=\"$chref->{am_pk}\"></td>\n";
      $html_string .= "<td>$chref->{hybridization_name}</td>\n";
      $html_string .= "<td>$smp_name</td>\n";
      $html_string .= "<td>$chref->{login}</td>\n";
      $html_string .= "<td>$chref->{gs_name}</td>\n";
      $html_string .= "<td>$chref->{chiptype}</td>\n";
      $html_string .= "</tr>\n";

    }

  }

  $html_string .= "</table>\n";

  return $html_string;

} #get_am_html


## get_criteria_file_html
## 8-10-04  Steve Tropello
## Generates html of all readable criteria files to us_fk in directory "criteria"; permits one file selection
## Return $html_string
sub get_criteria_file_html
{

  my ($dbh, $us_fk, $chref) = @_;
  my %ch = %$chref;
  my $prefix = "$USER_DATA_DIR/"; # yes, it has the trailing /

  my $html_string .= "*Select Criteria File (owner: file name) \n";
  $html_string = "<select name=\"criteria_file_fk\">\n";
  $html_string .= "<option value=\"\">------</option>\n";

  (my $fclause, my $wclause) = read_where_clause("file_info", "fi_pk", $us_fk);
  my $sql = "select fi_pk, file_name from file_info, $fclause where $wclause and file_name LIKE '\%/Upload/criteria/%\' order by file_name";
  my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth->execute() || die "Execute $sql \n$DBI::errstr";
  my %fhash;
  #
  # Add a \t after final / so that file names sort by
  # directory and then file.
  #
  while((my $fi_pk, my $file_name) = $sth->fetchrow_array())
  {
    $file_name =~ s/$prefix(.*)/$1/;
    $file_name =~ s/(.*)\//$1\/\t/;
    $fhash{"$file_name"} = $fi_pk;
  }
  foreach my $key (sort( {uc($a)  cmp  uc($b)} keys(%fhash)))
  {
    my $file_name = $key;
    $file_name =~ s/\t//; # remove the \t we put in above.
    my $fi_pk = $fhash{$key};
    (my $temp1,
     my $temp2,
     my $contact_name,
     my $temp3) = doq($dbh, "who_owns", $fi_pk);
    if ($fi_pk == $ch{criteria_file_fk}){
      $html_string .= "<option value=\"$fi_pk\" SELECTED>$contact_name: $file_name</option>\n";
    }
    else{
      $html_string .= "<option value=\"$fi_pk\">$contact_name: $file_name</option>\n";
    }
  }

  $html_string .= "</select>\n";

} #get_criteria_file_html


##
## SQL Functions
##


## exist_an_cond_am_link
## 8-10-04  Steve Tropello
## Checks if am (am_pk) is in an_cond (an_cond_pk)
## Return 0 (no link) or 1 (link exists)
sub exist_an_cond_am_link
{
                                                                                                                   
  my ($dbh, $an_cond_pk, $am_pk) = @_;
                                                                                                                   
  my $sql = "select * from an_cond_am_link where an_cond_fk=? and am_fk=?";
  my $sth_link = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
  $sth_link->execute($an_cond_pk, $am_pk) || die "Execute $sql \n$DBI::errstr";
                                                                                                                   
  if ($sth_link->rows() > 0){
                                                                                                                   
    return 1;
                                                                                                                   
  }
                                                                                                                   
  return 0;
                                                                                                                   
} #exist_an_cond_am_link


## exist_an_set_cond_link
## 8-10-04  Steve Tropello
## Checks if an_cond (an_cond_pk) is in an_set (an_set_pk)
## Return 0 (no link) or 1 (link exists)
sub exist_an_set_cond_link
{

  my ($dbh, $an_set_pk, $an_cond_pk) = @_;

  my $sql = "select * from an_set_cond_link where an_set_fk=? and an_cond_fk=?";
  my $sth_link = $dbh->prepare($sql)  || die "Prepare $sql \n$DBI::errstr";
  $sth_link->execute($an_set_pk, $an_cond_pk) || die "Execute $sql \n$DBI::errstr";

  if ($sth_link->rows() > 0){

    return 1;

  }

  return 0;

} #exist_an_set_cond_link


##
## GET HTML SUBS FOR CRITERIA FILE
##


## get_criteria_html
## 8-10-04  Steve Tropello
## Gets html for criteria selection
## Return $html_string
sub get_criteria_html
{

  my ($hashref) = @_;
  my %criteria_hash = %$hashref;
  my $html_string;
  my $continuous_string = get_continuous_parameters_html(\%criteria_hash);
  my $categorical_string = get_categorical_parameters_html(\%criteria_hash);

  $html_string = "<table border=1>\n";
  $html_string .= "<tr>\n";
  $html_string .= "<td>Continuous Parameters</td>\n";
  $html_string .= "<td>Categorical Parameters</td>\n";
  $html_string .= "</tr>\n";
  $html_string .= "<tr>\n";
  $html_string .= "<td valign=top>\n";
  $html_string .= $continuous_string;
  $html_string .= "</td>\n";
  $html_string .= "<td valign=top>\n";
  $html_string .= $categorical_string;
  $html_string .= "</tr>\n";
  $html_string .= "</table>\n";

  return $html_string;

} #get_criteria_html


## get_continuous_parameters_html
## 8-10-04  Steve Tropello
## Gets html for criteria selection on continuous parameters
## Return $html_string
sub get_continuous_parameters_html
{
  my ($hash_ref) = @_;
  my %criteria_hash = %$hash_ref;
  my @hybridization_name_array = keys (%criteria_hash);
  my @continuous_field_name_array;
  my $hybridization_name;
  my $field_name;
  my $html_string;
  my $type;
  my $min;
  my $max;
  my $font_size_logic = 1;
  my $font_size_text = 2;

  foreach $field_name (keys %{$criteria_hash{$hybridization_name_array[0]}}){
    if (lc($field_name) =~ m/continuous/){
      push(@continuous_field_name_array, $field_name);
    }
  }

  foreach $field_name (@continuous_field_name_array){

    $min = get_min_value(\%criteria_hash, $field_name);
    $max = get_max_value(\%criteria_hash, $field_name);

    $field_name = substr($field_name, 0, index($field_name, '::'));
    $html_string .= "<table>\n";
    $html_string .= "<tr><td>\n";
    $html_string .= "<table>\n";
    $html_string .= "<tr><td><font size=$font_size_text>\n";
    $html_string .= "$field_name ($min - $max)\n";
    $html_string .= "</td></tr>\n";
    $html_string .= "<tr><td><font size=$font_size_logic>\n";
    $html_string .= "<input type=\"radio\" name=\"$field_name" . "::logic\" value=\"and\" CHECKED>AND\n  ";
    $html_string .= "<input type=\"radio\" name=\"$field_name" . "::logic\" value=\"or\">OR\n";
    $html_string .= "</td></tr>\n";
    $html_string .= "</table>\n";
    $html_string .= "</td><td><font size=$font_size_text>\n";
    $html_string .= select_operators("$field_name" . "::case");
    $html_string .= "<input name=\"$field_name" . "::value\" type=text size=6></font>\n";
    $html_string .= "</td></tr>\n";
    $html_string .= "</table>\n";

  }

  return $html_string;

} #get_continuous_parameters_html


## get_categorical_parameters_html
## 8-10-04  Steve Tropello
## Gets html for criteria selection on categorical parameters
## Return $html_string
sub get_categorical_parameters_html
{                                                                                                                 my ($hash_ref) = @_;
  my %criteria_hash = %$hash_ref;
  my @hybridization_name_array = keys (%criteria_hash);
  my @categorical_field_name_array;
  my @categorical_values_array;
  my $hybridization_name;
  my $field_name;
  my $html_string;
  my $type;
  my $font_size_logic = 1;
  my $font_size_text = 2;

  foreach $field_name (keys %{$criteria_hash{$hybridization_name_array[0]}}){
    if (lc($field_name) =~ m/categorical/){
      push(@categorical_field_name_array, $field_name);
    }
  }

  foreach $field_name (@categorical_field_name_array){

    @categorical_values_array = get_possible_values(\%criteria_hash, $field_name);                                  
    $field_name = substr($field_name, 0, index($field_name, '::'));
    $html_string .= "<table>\n";
    $html_string .= "<tr><td>\n";
    $html_string .= "<table>\n";
    $html_string .= "<tr><td><font size=$font_size_text>\n";
    $html_string .= "$field_name \n";
    $html_string .= "</td></tr>\n";
    $html_string .= "<tr><td><font size=$font_size_logic>\n";
    $html_string .= "<input type=\"radio\" name=\"$field_name" . "::logic\" value=\"and\" CHECKED>AND \n";
    $html_string .= "<input type=\"radio\" name=\"$field_name" .  "::logic\" value=\"or\">OR\n";
    $html_string .= "</td></tr>\n";
    $html_string .= "</table>\n";
    $html_string .= "</td>\n";
    $html_string .= "<td><font size=$font_size_text>\n";

    my $array_length = get_select_size(@categorical_values_array);

    $html_string .= "<select name=\"$field_name" . "::values\" multiple size=$array_length>\n";

    foreach my $value (@categorical_values_array){
      $html_string .= "<option value=\"$value\">$value</option>\n";
    }

    $html_string .= "</select>\n";
    $html_string .= "</td></tr>\n";
    $html_string .= "</table>\n";

  }

  return $html_string;

} #get_categorical_parameters_html


##
## SUBS FOR CRITERIA_HASH 
##


## calculate_categorical_criteria
## 8-10-04  Steve Tropello
## For each categorical field, adds an array of ams to %hybridization_name_hash that fulfill user logic
## Return %hybridization_name_hash (keyed by $field_name)
sub calculate_categorical_criteria
{
                                                                                                               
  my ($criteria_hashref, $chref, $hybridization_hashref) = @_;
  my %criteria_hash = %$criteria_hashref;
  my %ch = %$chref;
  my %hybridization_name_hash = %$hybridization_hashref;
  my @field_name_array = get_field_names(\%criteria_hash, "categorical");
  my $field_name;
  my @form_values;
  my $hash_value;
  my $hybridization_name;
  my $ch_field;
  my $value;
                                                                                                               
  foreach $field_name (@field_name_array){
                                                                                                               
     @form_values = split (/\0/, $ch{substr($field_name, 0, index($field_name, '::')) . "::values"});
                                                                                                               
     foreach $value (@form_values){
      foreach $hybridization_name (keys %criteria_hash){

        $hash_value = $criteria_hash{$hybridization_name}{$field_name};
                                                                                                               
        if (check_logic($value, $hash_value, "=")){
                                                                                                               
          push( @{ $hybridization_name_hash{$field_name . "::" . $ch{substr($field_name, 0, index($field_name, '::')) . "::logic" }} }, $hybridization_name);
                                                                                                               
        }
                                                                                                               
      }
                                                                                                               
    }
  }
                                                                                                               
  return %hybridization_name_hash;
                                                                                                               
} # calculate_categorical_criteria


## calculate_continuous_criteria
## 8-10-04  Steve Tropello
## For each continuous field, adds an array of ams to %hybridization_name_hash that fulfill user logic
## Return %hybridization_name_hash (keyed by $field_name)
sub calculate_continuous_criteria
{
                                                                                                               
  my ($criteria_hashref, $chref, $hybridization_hashref) = @_;
  my %criteria_hash = %$criteria_hashref;
  my %ch = %$chref;
  my %hybridization_name_hash = %$hybridization_hashref;
  my @field_name_array = get_field_names(\%criteria_hash, "continuous");
  my $field_name;
  my $form_value;
  my $hash_value;
  my $hybridization_name;
  my $ch_field;
                                                                                                               
  foreach $field_name (@field_name_array){
                                                                                                               
    $form_value = $ch{substr($field_name, 0, index($field_name, '::')) . "::value"};
                                                                                                               
    if ($form_value =~ m/[0-9]/ ){
                                                                                                               
      ## Create blank array if continuous value entered in form (for cases where no elements in array)
      @{ $hybridization_name_hash{$field_name . "::" . $ch{substr($field_name, 0, index($field_name, '::')) . "::logic" }} } = ();
                                                                                                               
      foreach $hybridization_name (keys %criteria_hash){
                                                                                                               
        $hash_value = $criteria_hash{$hybridization_name}{$field_name};
                                                                                                               
        if ($hash_value =~ m/[0-9]/){
                                                                                                               
          if (check_logic($form_value, $hash_value, $ch{substr($field_name, 0, index($field_name, '::')) . "::case"})){
                                                                                                               
            push( @{ $hybridization_name_hash{$field_name . "::" . $ch{substr($field_name, 0, index($field_name, '::')) . "::logic" }} }, $hybridization_name);
                                                                                                               
          }
                                                                                                               
        }
                                                                                                               
      }
                                                                                                               
    }
                                                                                                               
  }
  return %hybridization_name_hash;
                                                                                                               
} # calculate_continuous_criteria


## get_all_hybridization_names
## 8-10-04  Steve Tropello
## Gets all hybridization name keys for a criteria_hash
## Return @hybridization_names
sub get_all_hybridization_names
{

  my ($criteria_hashref) = @_;
  my %criteria_hash = %$criteria_hashref;
  my @hybridization_name_array;
  my $field;

  foreach $field (keys %criteria_hash){

    push @hybridization_name_array, $field;

  }

  return @hybridization_name_array;

}


## get_equal_hybridization_names
## 8-10-04  Steve Tropello
## Gets all hybridization name keys that have a specified criteria_hash field value
## Return @hybridization_names
sub get_equal_hybridization_names
{

  my ($criteria_hash_ref, $field_name, $value) = @_;
  my %criteria_hash = %$criteria_hash_ref;
  my @hybridization_name_array;
  my $hybridization_name;

  foreach $hybridization_name (keys %criteria_hash){

    if ($criteria_hash{$hybridization_name}{$field_name} eq $value){

      push @hybridization_name_array, $hybridization_name; 

    }

  }
  
  return @hybridization_name_array;

} #get_equal_hybridization_names


## get_field_names
## 8-10-04  Steve Tropello
## Gets all field keys of specified type (categorical or continuous) from a criteria_hash
## Return @field_names
sub get_field_names
{

  my ($hash_ref, $field_type) = @_;
  my %criteria_hash = %$hash_ref;
  my @hybridization_name_array = keys (%criteria_hash);
  my @field_name_array;
  my $field_name;

  foreach $field_name (keys %{$criteria_hash{$hybridization_name_array[0]}}){
    if (lc($field_name) =~ m/::$field_type/){
      push(@field_name_array, $field_name);
    }
  }

  return @field_name_array;

} #get_field_names



## get_min_value
## 8-10-04  Steve Tropello
## Gets minimum field value of all hybridization keys in a criteria hash
## Return minimum continuous value
sub get_min_value
{

  my ($criteria_hash_ref, $field_name) = @_;
  my %criteria_hash = %$criteria_hash_ref;
  my $hybridization_name;
  my $min;
  my $order = 0;

  foreach $hybridization_name (keys %criteria_hash){
    if ($order == 0){

      if($criteria_hash{$hybridization_name}{$field_name} =~ m/[0-9]/){

        $min = $criteria_hash{$hybridization_name}{$field_name};
        $order++;

      }

    }

    if($criteria_hash{$hybridization_name}{$field_name} =~ m/[0-9]/){

      if ($criteria_hash{$hybridization_name}{$field_name} < $min){

        $min = $criteria_hash{$hybridization_name}{$field_name};

      }

    }

  }

  return $min;

} #get_min_value


## get_max_value
## 8-10-04  Steve Tropello
## Gets maximum field value of all hybridization keys in a criteria hash
## Return maximum continuous value
sub get_max_value
{

  my ($criteria_hash_ref, $field_name) = @_;
  my %criteria_hash = %$criteria_hash_ref;
  my $hybridization_name;
  my $max;
  my $order = 0;

  foreach $hybridization_name (keys %criteria_hash){

    if ($order == 0){

      if($criteria_hash{$hybridization_name}{$field_name} =~ m/[0-9]/){

        $max = $criteria_hash{$hybridization_name}{$field_name};
        $order++;

      }

    }

    if($criteria_hash{$hybridization_name}{$field_name} =~ m/[0-9]/){

      if ($criteria_hash{$hybridization_name}{$field_name} > $max){

        $max = $criteria_hash{$hybridization_name}{$field_name};

      }

    } 

  }

  return $max;

} ##get_max_value


## get_possible_values
## 8-10-04  Steve Tropello
## Gets distinct possible string values of a specified field for all hybridization keys in a criteria hash
## Return @values
sub get_possible_values
{

  my ($criteria_hash_ref, $field_name) = @_;
  my %criteria_hash = %$criteria_hash_ref;
  my $hybridization_name;
  my @values_array;

  foreach $hybridization_name (keys %criteria_hash){
    if (!in_array($criteria_hash{$hybridization_name}{$field_name}, @values_array)){
      push(@values_array, $criteria_hash{$hybridization_name}{$field_name});
    }
  }

  return @values_array;

} ##get_possible_values


## get_select_size
## 8-10-04  Steve Tropello
## Gets size of array up to a value of 5; value used to set multiple select box height
## Return size number
sub get_select_size
{

  my (@array) = @_;
  my $size = @array;

  if ($size < 5){
    return $size;
  }
  else{
    return 5;
  }

} #get_select_size


## merge_arrays
## 8-10-04  Steve Tropello
## Creates case array (and & or) and logically joins the arrays 
## Return @ams for insertion into an an_cond
sub merge_arrays
{
                                                                                                               
  my ($criteria_hashref, $hybridization_name_hashref) = @_;
  my %criteria_hash = %$criteria_hashref;
  my %hybridization_name_hash = %$hybridization_name_hashref;
  my $field_key;
  my @and_array = get_all_hybridization_names(\%criteria_hash);
  my @or_array = ();
  my $use_and = 0;
                                                                                                               
                                                                                                               
  foreach $field_key (keys %hybridization_name_hash){
                                                                                                               
    if ($field_key =~ m/::and/){
      $use_and = 1;                                                                   @and_array = merge_array_and(\@{$hybridization_name_hash{$field_key}}, \@and_array);
    }
                                                                                                               
    if ($field_key =~ m/::or/){
      @or_array = merge_array_or(\@{$hybridization_name_hash{$field_key}}, \@or_array);
    }
                                                                                                               
  }
                                                                                                               
# and_array is defaulted to all hybridizations.  If we have no 'and' 
# criteria, then we would use all of them, which we don't want, so only
# use and_array if we have performed at least one merge_array_and
  @and_array = () if ($use_and == 0);
  return merge_array_or(\@and_array, \@or_array);
                                                                                                               
} #merge_arrays

1;
