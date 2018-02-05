package main;
use strict;

sub load_miame_data
{
  my ($dbh, $us_fk, $miame_pk, $chref) = @_;
 
  (my $fclause, my $wclause) = read_where_clause("miame", "miame_pk", $us_fk);
  my $sth = $dbh->prepare("select * from miame, $fclause where " .
	"miame_pk=$miame_pk and $wclause");
  $sth->execute();
  %$chref = %{$sth->fetchrow_hashref()};
}

# returns true if the value is a field in the miame table
# currently hardcoded - could potentially be a check on the db
sub isField
{
  my $field = shift;

  if (($field eq "sty_fk") ||
      ($field eq "miame_name") ||
      ($field eq "miame_description") ||
      ($field eq "miame_type_fk") ||
      ($field eq "display_type_fk") ||
      ($field eq "publish_date") ||
      ($field eq "start_compile_date") ||
      ($field eq "ed_type") ||
      ($field eq "ed_design") ||
      ($field eq "ed_factors") ||
      ($field eq "ed_num_hybrids") ||
      ($field eq "ed_reference") ||
      ($field eq "ed_qc_steps") ||
      ($field eq "ed_urls") ||
      ($field eq "smp_origin") ||
      ($field eq "smp_manipulation") ||
      ($field eq "smp_labeling") ||
      ($field eq "smp_spikes") ||
      ($field eq "hybrid_procedures") ||
      ($field eq "hw_sw_info") ||
      ($field eq "sw_type") ||
      ($field eq "sw_measurements_prod") ||
      ($field eq "sw_measurements_used") ||
      ($field eq "hw_sw_params") ||
      ($field eq "sw_data_manipulation") ||
      ($field eq "ad_design") ||
      ($field eq "ad_spot") ||
      ($field eq "ad_specs") ||
      ($field eq "ad_location_id") ||
      ($field eq "ad_reporter_type") ||
      ($field eq "ad_manufacturer") ||
      ($field eq "ad_reporter_source") ||
      ($field eq "ad_reporter_prep") ||
      ($field eq "ad_spotting_protocols") ||
      ($field eq "ad_prehybrid_treatment"))
  {
     return 1;
  }
  else
  { 
     return 0;
  }
}

sub delete_miame_data
{
  my ($dbh, $miame_pk) = @_;
  my $sql = "delete from miame where miame_pk = '$miame_pk'"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  $dbh->commit();
}

sub save_miame_data
{
  my ($dbh, $us_fk, $miame_pk, $chref) = @_;
  
  # if you can retrieve a record based on miame_pk, then do an update
  # otherwise do an insert
 
  # if ed_num_hybrids is '', we need to undef so that we don't get 
  # pg_atoi: zero-length string error

  if ($chref->{ed_num_hybrids} !~ /[0-9]+/)
  {
     delete $chref->{ed_num_hybrids};
  }

  my $sth;
  my $update = "update miame set ";
  my $fields = "(";
  my $values = "values (";
  my $key;
  foreach $key (keys %$chref)
  {
	if (isField($key))
 	{
	  my $val = $dbh->quote($chref->{$key});
          if ($key eq "miame_name")
          {
            $val = format_miame_name($val);
          }
          if (!(($key eq "sty_fk") && ($chref->{sty_fk} eq "")))
          {
	    $update .= "$key = $val ,";
            # strip illegal url characters
	    $fields .= "$key,";
	    $values .= "$val,";
          }
 	}         
  }
  chop($fields); #remove trailing comma
  chop($values); #remove trailing comma
  $fields .= ") ";
  $values .= ") ";
  chop($update); #remove trailing comma
  $update .= " where miame_pk = $miame_pk";


  if (defined $miame_pk)
  {
     $sth = $dbh->prepare($update);
     $sth->execute();
  }
  else
  {
    if ((exists ($chref->{sty_fk}) ) && ($chref->{sty_fk} ne "")
        && ($chref->{sty_fk} != 0))
    {
	$sth=getq("select_groupref", $dbh);
        $sth->execute($chref->{sty_fk});
        ($chref->{owner_us_pk}, $chref->{owner_gs_pk}) = 
   	  $sth->fetchrow_array();
	$sth->finish; 
    }
    else
    {
      ($chref->{owner_us_pk}, $chref->{owner_gs_pk}) = 
        split(',',$chref->{pi_info});
    }
    $sth = $dbh->prepare("insert into miame $fields $values");
    $sth->execute();
    my $miame_pk = insert_security($dbh, $chref->{owner_us_pk}, 
      $chref->{owner_gs_pk}, 0660);
    $chref->{miame_pk} = $miame_pk;
  }

  $dbh->commit();
}


sub format_miame_name
{
  my $name = shift;
  $name =~ tr/ %#\/\\+~&?=;></_/;
  return $name;
}
1;
