package main;

use strict;
use CGI;

require 'geoss_session_lib';

sub make_report
{
  my ($dbh, $us_fk, $chref, $define_fn, $data_fn) = @_;

  #build report
  my ($columns_ref) = &$define_fn($dbh, $us_fk);
  my @data = &$data_fn($dbh, $us_fk, $columns_ref, $chref);
  sort_report_data($dbh, $us_fk, $chref->{submit}, $columns_ref, \@data);
  my $allhtml = generate_report_html("../curtools/view_reports1.html",
     \@data, $columns_ref);

  # format return html page
  my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};

  $allhtml =~ s/{(.*?)}/$ch{$1}/g;

  # make sure appropriate values are selected for checkboxes and select boxes
  foreach my $column (@$columns_ref)
  {
    my $fixvals = $column->{fixvalues};
    foreach my $fv_ref (@$fixvals)
    {
      my $name = "$fv_ref->{name}" . $column->{name};
      $allhtml = fixvalue($allhtml, $name, $ch{$name}, $fv_ref->{type});
    }
    if ($column->{searchable})
    {
      my $name = "use_" . $column->{name};
      $allhtml = fixvalue($allhtml, $name, $ch{$name}, "checkbox");
    }
  }

  return($allhtml);
}

sub fixvalue
{
   my ($allhtml, $name, $val, $type) = @_;

   if ($type eq "select")
   {
     $allhtml = fixselect($name, $val, $allhtml);
   } elsif (($type eq "checkbox") || ($type eq "radio"))
   {
     $allhtml = fixradiocheck($name, $val, "checkbox", $allhtml);
   }
   return($allhtml);
}

sub get_columns_val
{
  my ($dbh, $us_fk, $columns_ref, $val) = @_;

  my @values = ();
  foreach my $column (@$columns_ref)
  {
    if (exists($column->{"$val"}))
    {
      push @values, $column->{"$val"};
    }
    else
    {
      push @values, "";
    }
  }
  return (@values);
}


sub sort_report_data
{
  my ($dbh, $us_fk, $sort, $columns_ref, $dataref) = @_;
  my @headings = get_columns_val($dbh, $us_fk, $columns_ref, "display_name");
  my @col_names = get_columns_val($dbh, $us_fk, $columns_ref, "name");
  my @headings_type = get_columns_val($dbh, $us_fk, $columns_ref, "column_type");

  if ($sort)
  {
    my $i = 0;
    my $sort_field;
    my $sort_type;
    foreach my $col (@col_names)
    {
      $sort_field = $col if ($headings[$i] eq "$sort");
      $sort_type = $headings_type[$i] if ($headings[$i] eq "$sort");
      $i++;
    }
    my $reverse = 0;
    my $valuesref = get_session_val($dbh, $us_fk, "sort", "$sort_field");
    if (defined $$valuesref[1])
    {
      $reverse = $$valuesref[1]; 
    }
    else
    {
      set_session_val($dbh, $us_fk, "sort", "$sort_field", 1);
    }

    if ($sort_type eq "integer")
    {
	    if ($reverse)
      {
        @$dataref = sort { $b->{$sort_field} <=>  $a->{$sort_field}} @$dataref;
      }
	    else
      {
        @$dataref = sort { $a->{$sort_field} <=>  $b->{$sort_field}} @$dataref;
      }
    }
    elsif ($sort_type eq "boolean")
    {
	    if ($reverse)
      {
        @$dataref = sort {$b->{$sort_field} cmp  $a->{$sort_field}} @$dataref;
      }
	    else
      {
        @$dataref = sort {$a->{$sort_field} cmp  $b->{$sort_field}} @$dataref;
      }
    }
	  elsif ($sort_type eq "string")
    {
      if ($reverse)
      {
        @$dataref = sort { $b->{$sort_field} cmp  $a->{$sort_field}} @$dataref;
      }
	    else
	    {
        @$dataref = sort { $a->{$sort_field} cmp  $b->{$sort_field}} @$dataref;
      }
    }
	  elsif ($sort_type eq "linked_string")
    {
      if ($reverse)
      {
        @$dataref = sort { just_txt($b->{$sort_field}) cmp
          just_txt($a->{$sort_field}) } @$dataref;
      }
	    else
	    {
        @$dataref = sort { just_txt($a->{$sort_field}) cmp
              just_txt($b->{$sort_field})} @$dataref;
      }
    }
    elsif ($sort_type eq "money")
    {
	    if ($reverse)
      {
        @$dataref = sort{just_num($b->{$sort_field}) <=> 
          just_num($a->{$sort_field})} @$dataref;
      }
	    else
      {
        @$dataref = sort { just_num($a->{$sort_field}) <=> 
          just_num($b->{$sort_field})} @$dataref;
      }
    }
    elsif ($sort_type eq "date")
    {
	    if ($reverse)
      {
        @$dataref = sort { date_to_int($b->{$sort_field}) <=>  
          date_to_int($a->{$sort_field})} @$dataref;
      }
	    else
      {
        @$dataref = sort { date_to_int($a->{$sort_field}) <=>  
          date_to_int($b->{$sort_field})} @$dataref;
      }
    }
    else
    {
      die "Unrecognized sort type $sort_type in view_reports1.cgi\n";
    }
  } 
}

sub generate_report_html
{
   my ($htmlfile, $dataref, $columns_ref, $chref) = @_;

   my ($allhtml, $loop_template, $loop_tween, $loop_template2, 
       $loop_template3, $loop_template4) = readtemplate($htmlfile, 
         "/site/webtools/header.html", "/site/webtools/footer.html");

   foreach my $column (@$columns_ref)
   {
        # Header Row
	      my $loop_instance3 = $loop_template3;
        if ($column->{display_name} eq "")
        {
          $loop_instance3 =~ s/{header_html}/$column->{display_name}/g;
        }
        else
        {
          my $button_html = qq!<input type="submit" name="submit"
            value="$column->{display_name}">!;
          $loop_instance3 =~ s/{header_html}/$button_html/g;
        }
        $allhtml =~ s/<loop_here3>/$loop_instance3<loop_here3>/s;

	      my $loop_instance4 = $loop_template4;
        my $search_html = "";
        $search_html .= $column->{button} if ($column->{button});
        if ($column->{searchable})
        {
          if (keys(%$column))
          {
            $search_html .= qq!<input type="checkbox"
              name="use_$column->{name}" value="1">!;
            $search_html .= $column->{search_operator} if
              ($column->{search_operator});
            $search_html .= $column->{search_input} if ($column->{search_input});
          }
        }
        $loop_instance4 =~ s/{search_html}/$search_html/g;
        $allhtml =~ s/<loop_here4>/$loop_instance4<loop_here4>/s;
   }
   $allhtml =~ s/<loop_here3>//;
   $allhtml =~ s/<loop_here4>//;
   while (my $data_ar = shift(@$dataref))
   {
      my $loop_instance = $loop_template;
      foreach my $column (@$columns_ref)
      {
	      my $loop_instance2 = $loop_template2;
        $loop_instance2 =~ s/{field}/$data_ar->{$column->{name}}/g;
        $loop_instance =~ s/<loop_here2>/$loop_instance2<loop_here2>/s;
      }
      $loop_instance =~ s/<loop_here2>//;
      $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
    }

    $allhtml =~ s/{loop_here}//g;

    return($allhtml);
}

sub date_to_int
{
  my $date_str = shift;

  if ($date_str eq "n/a")
  {
    $date_str = "";
  }
  else
  {
    # input date is in form MM-DD-YY (as per Alyson's request)
    # if we format YYMMDD then we can do direct numberical comparison
    $date_str =~ /(.*)-(.*)-(.*)/;
    my $mon = $1;
    my $day = $2;
    my $year = $3;
    return "${3}${1}${2}";
  }
}

# used for text with an html link around it
sub just_txt
{
  my $str = shift;
  my  $just_txt = $str;
  $just_txt = $1 if ($str =~ /href=.*\>(.*)\<\/a\>/);
  return $just_txt;
}

sub just_num
{
  my $str = shift;
  my @str = split(//,$str);
  my $just_num = "";
  foreach (@str)
  {
    $just_num .= $_ if ($_ =~ /[\d\.]/);
  }
  return $just_num;
}

sub transform_date
{
  my $in = shift;
  if (defined $in)
  {
    $in =~ /^..(..)-(..-..)/;
    return "${2}-$1";
  }
  else
  {
    return "n/a";
  }
}

sub draw_org_reports
{
    my ($dbh, $us_fk, $chref) = @_;

    $chref->{htmltitle} = "Order Summary";
    $chref->{help} = set_help_url($dbh, "special_center_view_reports");
    $chref->{htmldescription} = "";
    $chref->{formaction} = "org_reports.cgi";
    $chref->{hidden} = qq!<input type=hidden name="org_pk"
      value="$chref->{org_pk}">!;
    my $allhtml = make_report($dbh, $us_fk, $chref, 
        \&define_or_columns, \&get_or_data);

    print "Content-type: text/html\n\n";
    print "$allhtml\n";

    $dbh->disconnect;
    exit();
}

sub define_or_columns
{
  my ($dbh, $us_fk) = @_;
  my @report_columns = (
      { 
        "display_name" => "Order Number",
        "column_type" => "string",
        "name" => "ord_num",
      },
      { 
        "display_name" => "Is Approved",
        "column_type" => "boolean",
        "name" => "is_approved",
      },
      { 
        "display_name" => "Approval Comments",
        "column_type" => "string",
        "name" => "approval_comments",
      },
      { 
        "display_name" => "Status",
        "column_type" => "string",
        "name" => "status",
      },
      { 
        "display_name" => "Study",
        "column_type" => "string",
        "name" => "study",
      },
      { 
        "display_name" => "Study Comments",
        "column_type" => "string",
        "name" => "study_comments",
      },
      { 
        "display_name" => "PI Name",
        "column_type" => "string",
        "name" => "pi_name",
      },
    );
  return(\@report_columns);
}

sub get_or_data
{
  my ($dbh, $us_fk, $columns_ref, $chref) = @_;
  # array of references to arrays (2D array) - each referenced array
  # corresponds to one row of output report
  my $sort = $chref->{"submit"};
  my $org_pk = $chref->{"org_pk"};
  my @data = ();

  my $sql = "select oi_pk, order_number, is_approved, approval_date, approval_comments, study_name, sty_comments, contact_lname, contact_fname, contact_phone, contact_email from order_info, organization, groupref, sample, exp_condition, study, contact where con_pk=groupref.us_fk and org_pk=org_fk and ref_fk=oi_pk and oi_fk=oi_pk and ec_fk=ec_pk and sty_fk=sty_pk and org_pk=$org_pk group by oi_pk, org_fk, order_number, is_approved, approval_comments, study_name, sty_comments, contact_lname, contact_fname, contact_phone, contact_email, approval_date";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my @data = ();
  while (my $ref = $sth->fetchrow_hashref())
  {
       $ref->{ord_num} =  "<a href=\"org_approve.cgi?order_number=$ref->{order_number}\">$ref->{order_number}</a>";

       if ($ref->{is_approved})
       {
         $ref->{is_approved} =  $ref->{approval_date};
       }
       else
       {
         $ref->{is_approved} =  "No";
       }

       $ref->{status} =  get_order_status($dbh, $us_fk,$ref->{oi_pk});
       # retrieve messages set by get_order_status
       get_session_val($dbh, $us_fk, "message","errmessage");

       $ref->{pi_name} =  $ref->{contact_fname} . " " . $ref->{contact_lname};

       push @data, $ref;
    }
    return(@data);
}
1;
