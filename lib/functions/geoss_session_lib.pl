package main;
use strict;

use CGI::Cookie;

use CGI;
use DBI;
use IO::File;
use MIME::Base64;
use Carp;
use POSIX;
use File::Copy;
use File::Basename;
use GEOSS::Database;
use GEOSS::Session;
use GEOSS::Experiment::Arraymeasurement;

my $dbname = 'geoss'; 
$::ptime = time();
require 'geoss_sql_lib';
require 'geoss_analysis_tree_lib';
require 'geoss_analysis_lib';
require 'geoss_message_lib';

sub get_message
{
  my @msgs = split(/m/, shift(@_));
  my $message_str = "";

  my $msgnum;
  foreach $msgnum (@msgs)
  {  
    my $msh_hash = messages($msgnum, @_);
    $message_str .= 
      "<font color=\"$msh_hash->{color}\">$msh_hash->{text}<p></font>"; 
  }
  return($message_str);
}

sub set_return_message
{
  my ($dbh, $us_fk, $type, $key, $msgnum, @params) = @_;
  my $ret_string = "";
  if ($us_fk ne "command")
  {
    set_session_val($dbh, $us_fk, $type, $key, get_message(
      $msgnum, @params));
  }
  $ret_string .= get_message_text($msgnum, @params);
  return ($ret_string);
}

sub get_message_text
{
  my @msgs = split(/m/, shift(@_));
  my $msg_str = "";
  my $msgnum;
  foreach $msgnum (@msgs)
  {
    my $msh_hash = messages($msgnum, @_);
    $msh_hash->{text} =~ s/<.*>//g;
    $msg_str .= "$msh_hash->{text}\n";
  }
  return($msg_str);
}

sub duplicate_hn
{
  my ($dbh, $us_fk, $oi_pk) = @_;

  (my $fclause, my $wclause)= write_where_clause("order_info", "oi_pk", 
      $us_fk );
  my $sql = "select abbrev_name, name, smp_name, sty_pk, study_name from 
    study, order_info, sample, exp_condition, $fclause where $wclause and 
    oi_pk='$oi_pk' and sty_pk = sty_fk and ec_pk = ec_fk and oi_fk=oi_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my @dup_array = ();
  my %dup_keys = ();
  my %dup_hash = ();
  my $hr;
  while ($hr = $sth->fetchrow_hashref())
  {
    my $key_name = $hr->{abbrev_name} = lc($hr->{abbrev_name});
    if ((exists $dup_hash{$key_name})  &&
        ($dup_hash{$key_name}->{study_name} ne $hr->{study_name}))
    {
      push @dup_array, $dup_hash{$key_name};
      $dup_keys{$key_name} = 1;
    }
    $dup_hash{$key_name} = $hr;
  }

  # we need to add final instances of duplicates to the dup_array
  my @add = ();
  my $key_name;
  foreach $key_name (keys(%dup_keys))
  {
    my $elem = $dup_hash{$key_name};
    push @add, $elem;
  }
  push @dup_array, @add; 
  return (\@dup_array);
}

sub user_pi
{
  my $us_fk = shift;
  $us_fk = GEOSS::Session->user->pk if (! $us_fk);
  my $sth = getq("user_pi", $dbh);
  $sth->execute($us_fk,$us_fk);
  my $hr;
  my $results = "<select name=\"pi_info\">\n";
  while($hr = $sth->fetchrow_hashref())
  {
    $results .= "<option value=\"$hr->{gs_owner},$hr->{gs_pk}\">" .
      "$hr->{contact_fname} $hr->{contact_lname}/$hr->{gs_name}</option>\n";
  }
  $results .= "</select>\n";
  return $results;
}

sub oi_form
{
  my $dbh = $_[0];
  my $result;
  my $sth = getq("oi_pk_number_all", $dbh);
  $sth->execute();
  $result="<a href=\"insert_order_curator1.cgi\">Create a new order</a><br>\n";
  $result .= qq#<a href="assign_order_number.cgi">#
    . qq#Assign an Order Number</a><br>\n#;
  $result .= qq#<a href ="view_reports.cgi">View Reports<a><br>\n#;
  $result .= qq#<a href="view_brief_curator.cgi"># .
    qq#Brief View Of All Array Orders</a><br>\n#;
  $result .= qq#<br>\n<form action="show1_curator.cgi" # .
    qq# method="post">\nOrder number, PI name (PI group)<br>\n<select # .
    qq# name="oi_pk">\n#;
  my $rows=$sth->rows();

  while( (my $oi_pk, my $order_number, my $pi_name, my $pi_group) = 
      $sth->fetchrow_array())
  {
    $result .= "<option value=\"$oi_pk\">$order_number, $pi_name " .
      "($pi_group)</option>\n";
  }
  $result .= "</select>\n<input type=\"submit\" name=\"submit\" " .
    "value=\"Get One Array Order\"></form>\n";
  return $result;
}

sub sample_info
{
  (my $dbh, my $us_fk, my $oi_pk) = @_;
  my $message;
    
  (my $fclause, my $wclause) = read_where_clause("sample", "smp_pk", $us_fk );
  my $sql = "select smp_pk, smp_name, exp_condition.name, study.study_name 
    from sample,exp_condition,study,$fclause where study.sty_pk=
    exp_condition.sty_fk and exp_condition.ec_pk=sample.ec_fk and 
    oi_fk=$oi_pk and $wclause order by smp_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my $scc_sth = getq("sample_chip_check", $dbh);

  my $hyb_sql = "select count(am_pk) from arraymeasurement where smp_fk=?";
  my $hyb_sth = $dbh->prepare($hyb_sql);

  verify_order($dbh, $us_fk, $oi_pk);

  my $rec;
  my $results;
  my $xx = 0;
  my $hyb_check;
  $results = "<table border=\"1\" width=\"100%\" cellpadding=\"3\" " .
    "cellspacing=\"0\">\n";
  $results .= "<tr><td>&nbsp;</td>" .
    "<td valign=\"top\"><div align=\"center\">Study name</div></td>" .
    "<td valign=\"top\"><div align=\"center\">Protocol name</div></td>" .
    "<td valign=\"top\"><div align=\"center\">Sample name</div></td>" .
    "<td valign=\"top\"><div align=\"center\">Number of hybridizations" .
    "</div></td></tr>\n";
  
  while($rec = $sth->fetchrow_hashref())
  {
    $scc_sth->execute($rec->{smp_pk});
    ($hyb_check) = $scc_sth->fetchrow_array();
    if ($hyb_check > 0) 
    {
      my $msg = get_message("FIELD_MANDATORY", "Chip Type");
      set_session_val($dbh, $us_fk, "message", "errmessage", $msg); 
    }
  
    $hyb_sth->execute($rec->{smp_pk});
    ($rec->{number_of_hybridizations}) = $hyb_sth->fetchrow_array();
    $xx++; # we want a one's based counting number in the line below, so increment here.
    $results .= "<tr><td valign=\"top\">$xx</td>" .
      "<td valign=\"top\">" . 
      "<div align=\"center\">$rec->{study_name}&nbsp;</div></td>" .
      "<td valign=\"top\">" .
      "<div align=\"center\">$rec->{name}&nbsp;</div></td>" .
      "<td valign=\"top\">" .
      "<div align=\"center\">$rec->{smp_name}&nbsp;</div></td>" .
      "<td valign=\"top\">" .
      "<div align=\"center\">$rec->{number_of_hybridizations}&nbsp;</div></td>".
      "</tr>\n";
  }
  $results .= "</table>\n";
  return ($results, $xx);
}

sub select_operators
{
  my ($field_name) = @_;
  $field_name = "select_operator" if (!$field_name);
  
  my $html = "<select name=\"$field_name\">
                <option value=\"=\">=</option>
                <option value=\"!=\">!=</option>
                <option value=\"<\"><</option>
                <option value=\">\">></option>
                <option value=\"<=\"><=</option>
                <option value=\">=\">>=</option>
             </select>\n";
  return($html);
}

sub select_my_trees
{
  my ($dbh, $us_fk, $field_name) = @_;
    
  $field_name = "select_tree" if (!$field_name);
  my $sth = getq("select_tree", $dbh, $us_fk);
  $sth->execute();
  my $sel = "<select name=\"$field_name\">\n";
  $sel .= "<option value=\"0\">None</option>\n";
  while((my $tree_name, my $tree_pk) = $sth->fetchrow_array())
  {
    $sel .= "<option value=\"$tree_pk\">$tree_name</option>\n";
  }
  $sel .= "</select>\n";
  return $sel;
}

sub select_disease
{
  my ($dbh, $field_name, $unset) = @_;
    
  $field_name = "select_disease" if (!$field_name);
  my $sth = getq("select_dis_name", $dbh);
  $sth->execute();
  my $sel = "<select name=\"$field_name\">\n";
  $sel .= "<option value=\"0\">$unset</option>\n" if ($unset);
  while((my $dis_pk, my $dis_name) = $sth->fetchrow_array())
  {
    $sel .= "<option value=\"$dis_pk\">$dis_name</option>\n";
  }
  $sel .= "</select>\n";
  return $sel;
}

sub select_gs_name
{
  my ($dbh, $us_fk) = @_;
    
  my $sth = getq("select_gs_name", $dbh, $us_fk);
  $sth->execute();
  my $sel = "<select name=\"select_gs_name\">\n";
  while((my $gs_pk, my $gs_name) = $sth->fetchrow_array())
  {
    $sel .= "<option value=\"$gs_pk\">$gs_name</option>\n";
  }
  $sel .= "</select>\n";
  return $sel;
}

sub verify_study
{
  my ($dbh, $us_fk, $us_fk_other, $sty_pk, $which_message, $study_name) = @_;

  (my $fclause, my $wclause) = read_where_clause("study", "sty_pk", 
      $us_fk_other );
  my $sql_sn = "select study_name from study,$fclause where $wclause 
    and study_name ilike ? and sty_pk<>?";
  my $sth_sn = $dbh->prepare($sql_sn);
  $sth_sn->execute($study_name, $sty_pk);
  if ($sth_sn->rows() > 0)
  {
    my $msg =  $which_message ."m";
    $msg = get_message($which_message);
    set_session_val($dbh, $us_fk, "message", "errmessage", $msg); 
  }
}

sub select_exp_with_default
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $field_name = $_[2];
  my $default_sty_fk = $_[3];
  my $cur_ec_pk = $_[4];

  # Get all the ec_pk's I can read.

  my $sth;
  $sth = getq("select_exp", $dbh, $us_fk);
  $sth->execute();
  my $ec_pk;
  my $name;
  my $sty_fk;
  my $study_name;
  my $select = "<select name=\"$field_name\">\n";
  $select .= "<option value=\"0\">Study: Exp. Condition</option>\n";
  while(($ec_pk, $name, $sty_fk, $study_name) = $sth->fetchrow_array())
  {
    if (($sty_fk == $default_sty_fk) || ($ec_pk == $cur_ec_pk) ||
        (! $default_sty_fk))
    {
      $select .= "<option value=\"$ec_pk\">$study_name: $name</option>\n";
    }
  }
  $select .= "</select>\n";
  return $select;
}

#
# Default selected item needs a "" value. 
#
sub select_exp
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $field_name = $_[2];
  my $is_loaded = $_[3];

  if (! $field_name)
  {
    $field_name = "ec_fk";
  }

  my $sth;
  if ($is_loaded eq "loaded")
  { 
    $sth = getq("select_exp_loaded", $dbh, $us_fk);
  }
  else
  {
    $sth = getq("select_exp", $dbh, $us_fk);
  }
  $sth->execute();
  my $ec_pk;
  my $name;
  my $sty_fk;
  my $study_name;
  my $select = "<select name=\"$field_name\">\n";
  $select .= "<option value=\"0\">Study: Exp. Condition</option>\n";
  while(($ec_pk, $name, $sty_fk, $study_name) = $sth->fetchrow_array())
  {
    $select .= "<option value=\"$ec_pk\">$study_name: $name</option>\n";
  }
  $select .= "</select>\n";
  return $select;
}

sub select_studies
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $field_name = $_[2];
  my $is_loaded = $_[3];

  if (! $field_name)
  {
    $field_name = "sty_pk";
  }

  my $sth;
  my $sty_pk;
  my $study_name;
  my $study_pk;
  my $comment;
  my $select = "<select name=\"$field_name\">\n";
  $select .= "<option value=\"0\">Study: Comments</option>\n";
  if ($is_loaded eq "loaded")
  { 
    $sth = getq("studies_i_can_read_loaded", $dbh, $us_fk);
    $sth->execute();
    my %studies_valid;
    my %studies_data;
    while(($study_name, $sty_pk, $comment, $is_loaded) = $sth->fetchrow_array())
    {
      $studies_data{$study_name} = ["$study_name", $sty_pk,"$comment"];
      if (exists $studies_valid{$study_name})
      {
        if ($is_loaded == 0)
        {
          $studies_valid{$study_name} = $is_loaded;
        }
      }
      else 
      {
        $studies_valid{$study_name} = $is_loaded;
      }
    }
    my $elem;
    foreach $elem (keys(%studies_valid))
    {
      delete $studies_data{$elem}  if ($studies_valid{$elem} == 0);
    }
    my @studies = ();
    foreach $elem (values(%studies_data))
    {
      push @studies, $elem;
    }
    my @sorted_studies = sort { $a->[0] cmp $b->[0] } @studies; 
    foreach $elem (@sorted_studies)
    {
      # trunc the comment so it isn't too long
      $comment = substr($comment, 0, 60);
      $select.="<option value=\"$elem->[1]\">$elem->[0]: $elem->[2]</option>\n";
    }
  }
  else
  {
    $sth = getq("studies_i_can_read", $dbh, $us_fk);
    $sth->execute();
    while(($study_name, $sty_pk, $comment) = $sth->fetchrow_array())
    {
      # trunc the comment so it isn't too long
      $comment = substr($comment, 0, 60);
      $select .= "<option value=\"$sty_pk\">$study_name: $comment</option>\n";
    }
  }
  $select .= "</select>\n";
  return $select;
}


sub select_users_to_disable
{
  my $dbh = $_[0];
  my $us_fk = $_[1];

  my $sth = getq("select_users_to_disable", $dbh);
  $sth->execute();

  my $select = "<select name=\"disable_user\">\n";
  while(my ($us_pk, $login, $fname, $lname) = $sth->fetchrow_array())
  {
    if ($us_pk != $us_fk)
    {
      $select .= "<option value=\"$login\">$login: $fname $lname" .
        "</option>\n";
    }
  }
  $select .= "</select>\n";
  return $select;
}

sub select_users_to_enable
{
  my $dbh = $_[0];
  my $us_fk = $_[1];

  my $sth = getq("select_users_to_enable", $dbh);
  $sth->execute();

  my $select = "<select name=\"enable_user\">\n";
  while(my ($us_pk, $login, $fname, $lname) = $sth->fetchrow_array())
  {
    if ($us_pk != $us_fk)
    {
      $select .= "<option value=\"$login\">$login: $fname $lname" .
        "</option>\n";
    }
  }
  $select .= "</select>\n";
  return $select;
}

# if you pass in a us_fk, then you will get all organizations of 
# which us_fk is a member.
# if you do not pass in us_fk, you will get all organizations
sub select_org
{
  my ($dbh, $us_fk, $field_name) = @_;
  $field_name = "select_org" if (! $field_name);

  my $select = "<select name=\"$field_name\">\n";
  $select .= "<option value=\"NULL\">None</option>\n";
    
  my $sth;
  if ($us_fk)
  {
    $sth = getq("get_orgs_by_user", $dbh, $us_fk);
  }
  else
  {
    $sth = getq("select_all_organizations", $dbh);
  }
  $sth->execute();

  my $hr;
  while($hr = $sth->fetchrow_hashref())
  {
   $select .= "<option value=\"$hr->{org_pk}\">$hr->{org_name}</option>\n";
  }
  $select .= "</select>\n";
  return $select;
}

sub display_user_type
{
  my $type = shift;
  my $display = "";
  $display = "Public User" if ($type eq "public");
  $display = "Member User" if ($type eq "experiment_set_provider");
  $display = "Array Center Staff" if ($type eq "curator");
  $display = "Administrator" if ($type eq "administrator");
  return ($display);
}

sub select_type
{
  my $types = shift;
  my @types = ();

  if ($types eq "all")
  {
    @types = ("public", "experiment_set_provider", "curator", "administrator");
  }
  else
  {
    @types = @$types;
  }

  my $select_type = "<select name=\"type\">\n";
  foreach (@types)
  {
    my $display = display_user_type($_);
    $select_type .= "<option value=\"$_\">$display</option>\n";
  }
  $select_type .= "</select>\n";
  return $select_type;
}

sub select_pi_login
{
  my ($dbh, $us_fk) = @_;

  my $str = select_users($dbh, $us_fk, "user_login");
  $str =~ s/user_login">/pi_login"><option value="own">This user is their own PI<\/option>/;
  return $str;
}

sub select_remove_orgs
{
  my $dbh = $_[0];
  my $us_fk = $_[1];

  my $sth = getq("select_remove_orgs", $dbh);
  $sth->execute();

  my $select = "<select name=\"remove_org\">\n";
  while(my ($org_name) = $sth->fetchrow_array())
  {
    $select .= "<option value=\"$org_name\">$org_name</option>\n";
  }
  $select .= "</select>\n";
  return $select;
}

sub select_remove_users
{
  my $dbh = $_[0];
  my $us_fk = $_[1];

  my $sth = getq("select_remove_user", $dbh);
  $sth->execute();

  my $select = "<select name=\"remove_user\">\n";
  while(my ($us_pk, $login, $fname, $lname) = $sth->fetchrow_array())
  {
    if ($us_pk != $us_fk)
    {
      $select .= "<option value=\"$login\">$login: $fname $lname</option>\n";
    }
  }
  $select .= "</select>\n";
  return $select;
}

sub select_users
{
  my ($dbh, $us_fk, $field_name, $login_user) = @_;

  if (! $field_name)
  {
    $field_name = "user_login";
  }

  my $login_user_fk = doq($dbh, "get_us_pk", $login_user) 
    if (defined $login_user);
  my $sth = getq("select_$field_name", $dbh, $login_user_fk);
  $sth->execute();

  my $ec_pk;
  my $name;
  my $sty_fk;
  my $study_name;
  my $select = "<select name=\"$field_name\">\n";
  while(my ($login, $fname, $lname) = $sth->fetchrow_array())
  {
    $select .= "<option value=\"$login\">$login: $fname $lname</option>\n";
  }
  $select .= "</select>\n";
    
  return $select;
}

sub select_exp_types
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $field_name = $_[2];

  if (! $field_name)
  {
    $field_name = "miame_type_pk";
  }

  my $sth = getq("select_miame_types", $dbh);
  $sth->execute();
  my $miame_type_pk;
  my $miame_type_name;
  my $select = "<select name=\"$field_name\">\n";
  while(($miame_type_pk, $miame_type_name) = $sth->fetchrow_array())
  {
    $select .= "<option value=\"$miame_type_pk\">$miame_type_name</option>\n";
  }
  $select .= "</select>\n";
    
  return $select;
}

sub verify_hyb
{
  my ($dbh, $us_fk, $am_pk) = @_;
  my $message; 

  my $sth = getq("hyb_info", $dbh);
  $sth->execute($am_pk);
  my $rh = $sth->fetchrow_hashref();
  if (!$rh->{al_fk})
  {
    my $msg = get_message("FIELD_MANDATORY", "Chip Type");
    set_session_val($dbh, $us_fk, "message", "errmessage", $msg); 
  }
}

sub verify_order_completeness
{
  my ($dbh, $us_fk, $oi_pk) = @_;
  my $complete = 1;

  # verify that the samples are complete
  $complete = verify_order($dbh, $us_fk, $oi_pk);
  #verify that the order has at least one sample
  my $sth = getq("select_sample_by_oi_fk", $dbh, $us_fk);
  $sth->execute($oi_pk);
  my $smp_fk;
  my $num_samples = 0;
  while (($smp_fk) = $sth->fetchrow_array())
  {
    $num_samples++;
    my $sth2 = getq("select_am_pk_by_smp_fk", $dbh, $us_fk);
    $sth2->execute($smp_fk);
    my $num_am = 0;
    my $am_pk;
    while (($am_pk) = $sth2->fetchrow_array())
    {
      verify_hyb($dbh, $us_fk, $am_pk);
      $num_am++; 
    } 
    if ($num_am == 0)
    {
      set_return_message($dbh, $us_fk, "message", "errmessage", 
        "INCOMPLETE_ORDER_SAMPLE_NEEDS_HYB");
      $complete = 0;
    }
  }

  if ($num_samples == 0)
  {
    set_return_message($dbh, $us_fk, "message", "errmessage",
        "INCOMPLETE_ORDER_NEEDS_SAMPLE");
    $complete = 0;
  }
  return($complete);
}

sub verify_order
{
  my ($dbh, $us_fk, $oi_pk) = @_;
  my $complete = 1;
  my $sth = getq("order_ec_check", $dbh);
  $sth->execute($oi_pk);
  (my $bad_count) = $sth->fetchrow_array();
  if ($bad_count)
  {
    my $s = set_return_message($dbh, $us_fk, "message", "errmessage",
      "FIELD_MANDATORY", "Exp. Condition"); 
    $complete = 0;
  }
  return $complete;
}

sub verify_exp
{
  my ($dbh, $us_fk, $sty_pk, $which_message, $test_name, $test_abbrev) = @_;
  my $sql_name = "select name from exp_condition where sty_fk=? and 
    (name ilike ? or abbrev_name ilike ?)";
  my $sth_name = $dbh->prepare($sql_name);
  $sth_name->execute($sty_pk, $test_name, $test_abbrev);
  my $rows = $sth_name->rows();
  $sth_name->finish();

  if ($rows > 1)
  {
    my $msg = $which_message . "m";
    $msg = get_message("$msg");
      set_session_val($dbh, $us_fk, "message", "errmessage", $msg); 
  }
  return "";
}

sub parse_rpt
{
  my $rpt_name = $_[0];
  my $all = readfile($rpt_name);
  my %regex;
  my %ch;
  $regex{scale_factor} =  '\(SF\):\s+(.*?)\s+';
  $regex{background} = 'Background:\s+Avg:\s+(.*?)\s+';
  $regex{noise} = 'Noise:\s+Avg:\s+(.*?)\s+';
  $regex{percent_present} = 'Number Present:\s+\d+\s+(.*?)\%';
  $regex{biob_3_detection} = 'BIOB\s+\S+\s+(.)';
  $regex{biob_5_detection} = 'BIOB\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.)';
  my @controls = ('DROS-ACTIN',
                  'DROS-GAPDH',
                  'DROS-EIF-4A',
                  'B-ACTINMUR/M12481',
                  'GAPDHMUR/M32599', 
                  'RAT_GAPDH',
                  'RAT_BETA-ACTIN',
                  'HUMGAPDH/M33197',
                  'HSAC07/X00351',
                  'YFL039C',
                  'YER148W',
                  'YER022W');
    
  foreach my $key (keys(%regex))
  {
    if ($all =~ m/$regex{$key}/)
    {
      $ch{$key} = $1;
    }
  }
  foreach my $cont (@controls)
  {
    if ($all =~ m/$cont\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+/s)
    {
      $ch{$cont} = $1;
      #
      # Put a list of control keys into one of the hash elements.
      #
      push(@{$ch{control_list}}, $cont);
    }
  }
  return %ch;
}

sub parse_all_ch_to_samples
{
  my ($dbh, $us_fk, $chref) = @_;
  my @samples = ();
  my %override = ();
  while (my ($key, $value) = each(%$chref))
  {
    if ($key =~ /^([A-Za-z_0-9]+)_(!newfk_\d+)$/)
    {
      my $field=$1; 
      my $smp_pk = $2;
      $override{$smp_pk}->{$field} = $value; 
    }
  }
  foreach (keys(%override))
  {
    push @samples, $_;
  }
}

sub set_session_record
{
  my ($dbh, $us_fk, $type, $chref) = @_;
 
  while (my ($key, $value) = each (%$chref))
  { 
    set_session_val($dbh, $us_fk, "$type",
      "${key}_$chref->{$type}", $value);
  }
}


#
# called from edit_sample2.cgi, insert_sample.cgi and insert_am.cgi
#
# 2003-02-20 Tom: removed extra arg [2] that was $group. 
# Must have been a partial edit.
#
# 2003-03-03 Tom: In the last version I called insert_hybs() with 4 args in one
# location, and didn't fix the others. Two of those args were not used, so 
# now we're down to 2 args, and I've fixed all the other calls, and added 
# a prototype.
#
sub insert_hyb($$)
{
  my ($dbh, $smp_pk, $al_fk, $am_comments) = @_;
  my $sql;
  my $sth;

  #
  # Get the es_fk and submission date.
  # type and description are always the same for Affy data.
  # release_date is always some bogus value in the distant past. We're ignoring this.
  # hybridization name is different for each hybridization.
  #
  # We are securing arraymeasurement, so call insert_security();
  #
  my $submission_date = `date`; 
  chomp($submission_date);
  $submission_date = date2sql($submission_date);

  (my $owner_us_fk, my $owner_gs_fk, undef, my $permissions) = 
    doq($dbh, "who_owns", $smp_pk);

  $sth = getq("insert_am", $dbh);
  #
  # Just insert a mostly blank record into quality_control.
  # 
  # Finally, create the arraymeasurement record, and secure it.
  $dbh->quote($am_comments);
  $sth->execute('derived_other',    # type
                'Affymetrix data',  # description 
                '1970-01-01 01:01:01-04', # release_date
                $submission_date,   # submission_date
                $smp_pk,            # smp_fk
                'als',    # instance_code is the same for all affy data
                $al_fk,        # fk for arraylayout
                $am_comments        # user_supplied comments
  ) ;
  # hybs have same permissions as the sample which is same as the order
  insert_security($dbh, $owner_us_fk, $owner_gs_fk, $permissions);
  $sth->finish();
  $dbh->commit();
}

# update_hn and build_hn are both for
# creating hybridization names, and updating the hyb names associated with a
# list of samples
#
sub update_hn
{
  my ($smps) = @_;

  #
  # Read the db since the hyb names my not be correct.
  # Recreated the names, and write the new names back to the db.
  #
  return if (! $smps);

  my $sql = "select am_pk,smp_pk,ec_pk,abbrev_name from 
    arraymeasurement,sample,exp_condition where smp_pk in ($smps)
    and sample.smp_pk=arraymeasurement.smp_fk and sample.ec_fk=
    exp_condition.ec_pk order by smp_pk,am_pk";

  my $sql2 = "select order_number from order_info, sample where oi_pk=oi_fk
    and smp_pk=? order by smp_pk";

  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $xx = 0;
  my @sarr;
  while(($sarr[$xx][0], $sarr[$xx][1], $sarr[$xx][2], $sarr[$xx][3]) 
      = $sth->fetchrow_array())
  {
    my $sth2 = $dbh->prepare($sql2);
    $sth2->execute($sarr[$xx][1]);
    ($sarr[$xx][4]) = $sth2->fetchrow_array();
    $xx++;
  }
  $sth->finish();

  my %hybnames = build_hn(\@sarr);

  my $ret;
  for($xx=0; $xx<$#sarr; $xx++)
  {
    my $am_pk = $sarr[$xx][0];
    if ($hybnames{$am_pk})
    {
      if (getq_count_am_pk_by_hyb_name_by_study($hybnames{$am_pk}, $am_pk))
      {
        $ret = GEOSS::Session->set_return_message("errmessage",
            "ERROR_VIEW_ORDER_BAD_CONFIG");
      }
      else
      {
        my $am = GEOSS::Experiment::Arraymeasurement->new(pk => $am_pk);
        if ($am->is_loaded)
        {
          warn "Generated name $hybnames{$am_pk} for $am does not match"
            if ($hybnames{$am_pk} ne $am->name);
        }
        else
        {
          $sql = "update arraymeasurement set hybridization_name=
            trim('$hybnames{$am_pk}') where am_pk=$am_pk";
          $dbh->do($sql);
        }
      }
    }
  }

  return($ret);
}

sub number_to_character_sequence
{
  my $n = shift;
  my $b = scalar(@_);
  my $r;
  while($n > 0) {
    $n--;
    $r = $_[$n % $b] . $r;
    $n = int($n / $b);
  }
  return $r;
}

sub number_to_letter_sequence
{
  my $n = shift;
  return number_to_character_sequence($n, 'A'..'Z');
}

sub build_hn
{
  my @sarr = @{$_[0]}; # 2D array
  my $sc = '_';
  my $xx;
  my $yy;
  my $last_smp_pk = -1;
  my %letter;
  my %number;
  my %hybnames;
  #
  # This depends on smp_pk being sorted.
  #
  my $am_pk;
  my $smp_pk;
  my $ec_pk;
  for($xx=0; $xx<=$#sarr; $xx++)
  {
    $am_pk = $sarr[$xx][0];
    $smp_pk = $sarr[$xx][1];
    $ec_pk = $sarr[$xx][2];
    #
    # This should work for both, and isn't dependent on
    # the same number records being consecutive.
    # This still needs the records in the same order every time
    # for consistent naming.
    #
    if (! exists($number{$am_pk}))
    {
      $number{$am_pk} = 1;
      my $number_count = 2;
      for($yy=$xx+1; $yy<=$#sarr; $yy++)
      {
        if ($smp_pk == $sarr[$yy][1])
        {
          $number{$sarr[$yy][0]} = $number_count;
          $number_count++;
        }
      }
    }
    if (! exists($letter{$am_pk}))
    {
      my $letter_count = 0;
      # $letter{$am_pk} = $letter_count; # we'll += "A" later
      for($yy=$xx; $yy<=$#sarr; $yy++)
      {
        if (($ec_pk == $sarr[$yy][2]) && ($smp_pk != $sarr[$yy][1]))
        {
          $smp_pk = $sarr[$yy][1]; # most recent previous value
          $letter_count++;
        }
        if ($ec_pk == $sarr[$yy][2])
        {
          $letter{$sarr[$yy][0]} = $letter_count;
        }
      }
    }
    if ($sarr[$xx][3])
    {
      if ($sarr[$xx][4])
      {
        $hybnames{$am_pk} = sprintf("%s$sc%s$sc%s$sc%d",
            $sarr[$xx][4],
            $sarr[$xx][3],
            number_to_letter_sequence($letter{$am_pk}+1),
            $number{$am_pk});
      }
      else
      {
        $hybnames{$am_pk} = sprintf("%s$sc%s$sc%d",
            $sarr[$xx][3],
            number_to_letter_sequence($letter{$am_pk}+1),
            $number{$am_pk});
      }
    }
  }
  my $flag;
  for($xx=0; $xx<=$#sarr; $xx++)
  {
    $flag = 1;
    if ($hybnames{$sarr[$xx][0]})
    {
      if ($hybnames{$sarr[$xx][0]} =~ m/(.*$sc[A-Z]+$sc)1$/)
      {
        my $match = $1;
        for($yy=$xx+1; $yy<=$#sarr; $yy++)
        {
          if ($hybnames{$sarr[$yy][0]} =~ m/${match}2$/)
          {
            $flag = 0; # we matched a -2, so don't delete
          }
        }
        if ($flag == 1)
        {
          chop($hybnames{$sarr[$xx][0]});
          chop($hybnames{$sarr[$xx][0]});
        }
      }
    }
  }
  return %hybnames;
}

sub get_config_entry
{
  my ($dbh, $name) = @_;
  my $sth = getq("get_config_entry", $dbh, $name);
  $sth->execute();
  my ($value) = $sth->fetchrow_array();
  return($value);
}

sub get_all_config_entries
{
  my $dbh = shift;

  my $sth = getq("get_all_config_entries", $dbh);
  $sth->execute();
  my $config = $sth->fetchrow_hashref();

  return $config;
}

#
# Security related.
# Get an owner us_fk and the owner's login when the ref_fk is known.
# ref_fk is always the _pk of a secured record.
#
sub get_owner
{
  my $dbh = $_[0];
  my $ref_fk = $_[1];
  my $sql = "select us_fk from groupref where ref_fk=$ref_fk";
  ((my $us_fk) = $dbh->selectrow_array($sql));
  
  $sql = "select login from usersec where us_pk=$us_fk";
  ((my $login) = $dbh->selectrow_array($sql));

  return ($us_fk, $login);
}

#
# Security related.
# Get an owner gs_fk and the group name when the ref_fk is known.
# ref_fk is always the _pk of a secured record.
#
sub get_group
{
  my $dbh = $_[0];
  my $ref_fk = $_[1];
  my $sql = "select gs_fk from groupref where ref_fk=$ref_fk";
  ((my $gs_fk) = $dbh->selectrow_array($sql));
    
  $sql = "select gs_name from groupsec where gs_pk=$gs_fk";
  ((my $gs_name) = $dbh->selectrow_array($sql));

  return ($gs_fk, $gs_name);
}

#
# fi_update() Does both insert and update for file_info.
#
# Just like most Linux systems, where uid==gid, GEOSS us_pk==gs_pk. In GEOSS is it easy to
# get the us_pk (us_fk) with get_us_fk() which you can find elsewhere in session_lib. Normally, 
# fi_update() is called with us_fk for both user and group foreign keys.
# 
# $file_name is the full path to the file
# To get the full name where the file name is $fn
# $fn = "$USER_DATA_DIR/$login/$fn";
# 
# Comments are passed in from the UI
# conds and cond_labels passed in from elsewhere too.
#
sub fi_update($$$$$$$$$$$$)
{
  my ($dbh, $us_fk, $gs_fk, $file_name, $fi_comments, $conds, $cond_labels,
      $node_fk, $uai, $ft_fk, $permissions, $al_fk) = @_;
  my $fi_pk; 

  if (-e $file_name)
  {
    my $sth = getq("select_fi", $dbh);
    $sth->execute($file_name);

    my $md5 = `md5sum "$file_name"`;
    $md5 =~ s/(.*?) .*/$1/s;

    my @stats = stat($file_name);
    my $last_modified = $stats[9];

    #
    # Yikes. Is > 1 really valid?
    # 
    if ($sth->rows() >= 1)
    {
      ($fi_pk) = $sth->fetchrow_array();
      doq($dbh, "update_fi", $fi_comments, $md5, $conds, $cond_labels,
          $node_fk, $ft_fk, $last_modified, $fi_pk, $al_fk);
    }
    else
    {
      doq($dbh, "insert_fi", $file_name, $fi_comments, $md5, $conds,
          $cond_labels, $node_fk, $ft_fk, $last_modified, $al_fk);
        
      $fi_pk = insert_security($dbh, $us_fk, $gs_fk, $permissions);
      # $uai should be '1'::bool or '0'::bool i.e. $uai = "'1'::bool";
      # For now, we'll use a little hack. If $uai is "1" or "0" we'll fix it,
      # else we leave it alone.
      if (defined $uai)
      {
        if ($uai eq "0" || $uai eq "1")
        {
          $uai = "'$uai'::bool";
        }
        my $stm= "update file_info set use_as_input =$uai where fi_pk = $fi_pk";
        $sth=$dbh->prepare($stm);
        $sth->execute();
      }
    }
    # commit() either case for (-e $file_name)
    $dbh->commit();
  }
  else
  {
    write_log("File $file_name doesn't exist--can't add");
    $fi_pk = -1;
  }
  return $fi_pk;
}

#
# This should work for any secured record
# 
sub chown_sanity_check
{
  my $dbh = $_[0];
  my $ref_fk = $_[1];
  my $new_owner = $_[2];
  my $new_group = $_[3];
  my $new_permissions = $_[4];
  my $sql;
  my $sth;
  # get current owner and group
  # get new owner and group
  # is new owner a PI of current owner?
  # is new owner a member of current owner's group?
  # are current group and new owner's groups identical?
  # are the new permissions different?
  # what users will have read access that didn't used to?
  # what users will have write access that didn't used to?
}

#
# This is order specific since it needs to know about samples.
# This does no sanity checking, so it is quite powerful.
#
sub chown_order
{
  my $dbh = $_[0];
  my $oi_pk = $_[1];
  my $new_owner = $_[2];
  my $new_group = $_[3];
  my $new_permissions = $_[4];

  # extra credit: check for count of records matching $oi_pk == 1

  # update order
  my $groupref_sth = getq("update_security_curator", $dbh);
  $groupref_sth->execute($new_owner, $new_group, $new_permissions, $oi_pk);

  # update samples
  my $smp_sth = getq("select_sample_by_oi_fk", $dbh);
  $smp_sth->execute($oi_pk);
  while ((my $smp_pk) = $smp_sth->fetchrow_array())
  {
    $groupref_sth->execute($new_owner, $new_group, $new_permissions, $smp_pk);
  }
}


# uga, but a (admin) isn't actually used, so it can be zero.
# 3 bits per field just like Unix. I'm keeping the x bit so that our
# system is identical to Unix, but we'll never use x.
#
# Read the values for each position in columns. For example, the first column is
# 256 decimal and is 400 octal.
#
# 216 318 421
# 524 26
# 68
#
# 421 421 421
# 000 000
# 000
# rwx rwx rwx
#
# lock_order() 
# Remove write permissions from study, exp_condition, order_info, sample.
# The table arraymeasurement should never have write permissions (curators use their 
# special powers to import data.)
#
sub lock_order
{
  my $dbh = $_[0];
  my $oi_pk = $_[1];
  my $unlock = $_[2];
  my $sql;
  my $sth;
  my $priv_mask = 0440; # 288; #0440 ug read-only. decimal 288
  if ($unlock == 1)
  {
    # Unlocked orders are reset to  value in old_permissions,
    # if it exists
    my ($old_privs) = $dbh->selectrow_array("select old_permissions 
      from groupref, order_info where oi_pk = ref_fk and oi_pk = $oi_pk");
    if ($old_privs)
    {
      # we need to convert the actual privs to a mask
      # we get a decimal value from the db, we convert to octal
      $priv_mask = $old_privs;
    }
    else
    {
      $priv_mask = 0640; # 416 decimal octal 0640 rw- r-- ---  u+rw,g+r
    }
  }
  $sth = getq("select_sample_by_oi_fk", $dbh);
  $sth->execute($oi_pk);
  while ((my $smp_pk) = $sth->fetchrow_array())
  {
    #
    # we aren't going to lock the study
    #  rather, we will lock each experimental condition
    # associated with a sample that is part of this order
    #
    {
      my $study_sql = "select ec_pk from exp_condition,sample where 
        exp_condition.ec_pk=sample.ec_fk and sample.smp_pk=$smp_pk";
      my $study_sth = $dbh->prepare($study_sql);
      $study_sth->execute();
      if ($study_sth->rows() > 0)
      {
        (my $ec_pk) = $study_sth->fetchrow_array();
        lock_exp_cond($dbh, $ec_pk, $unlock);
        #lock_study($dbh, $sty_pk, $unlock);
      }
      $study_sth->finish();
    }
    my $am_sth = getq("select_am_pk", $dbh);
    $am_sth->execute($smp_pk);
    while((my $am_pk) = $am_sth->fetchrow_array())
    {
      if ($unlock == 1)
      {
        or_perms($dbh, $am_pk, $priv_mask);
      }
      else
      {
        and_perms($dbh, $am_pk, $priv_mask);
      }
    }
    if ($unlock == 1)
    {
      or_perms($dbh, $smp_pk, $priv_mask);
    }
    else
    {
      and_perms($dbh, $smp_pk, $priv_mask);
    }
  }
  $sth->finish();
  # order_info
  if ($unlock == 1)
  {
    or_perms($dbh, $oi_pk, $priv_mask);
  }
  else
  {
    and_perms($dbh, $oi_pk, $priv_mask);
  }
  if ($unlock == 1)
  {
    doq_unlock_order($dbh, $oi_pk);
  }
  else
  {
    doq_lock_order($dbh, $oi_pk);
  }
}

sub lock_exp_cond
{
  my $dbh = $_[0];
  my $ec_pk = $_[1];
  my $unlock = $_[2];
  my $priv_mask = 0440; # 288; #\440 uga read-only. decimal 288
  if ($unlock == 1)
  {
    # Unlocked ecs are reset to  value in old_permissions,
    # if it exists
    my ($old_privs) = $dbh->selectrow_array("select old_permissions 
      from groupref, exp_condition where ec_pk = ref_fk and ec_pk = $ec_pk");
    if ($old_privs)
    {
      # we need to convert the actual privs to a mask
      # we get a decimal value from the db, we convert to octal
      $priv_mask = $old_privs;
    }
    else
    {
      $priv_mask = 0640; # 416 decimal octal 0640 rw- r-- ---  u+rw,g+r
    }
    #    write_log("unlocking ec_pk $ec_pk with priv $priv_mask");
    or_perms($dbh, $ec_pk, $priv_mask);
  }
  else
  {
    #write_log("locking ec_pk $ec_pk with priv $priv_mask");
    and_perms($dbh, $ec_pk, $priv_mask);
  }
}

sub set_perms
{
  my $dbh = $_[0];
  my $pk = $_[1];
  my $mask = $_[2];
  my $sql = "update groupref set permissions=$mask where ref_fk=$pk";
  $dbh->do($sql);
}

sub and_perms
{
  my $dbh = $_[0];
  my $pk = $_[1];
  my $sql = "update groupref set old_permissions=permissions where ref_fk=$pk";
  $dbh->do($sql);
  my $mask = $_[2];
  $sql = "update groupref set permissions=(permissions&$mask) where ref_fk=$pk";
  $dbh->do($sql);
}

sub or_perms
{
  my $dbh = $_[0];
  my $pk = $_[1];
  my $mask = $_[2];
  my $sql = "update groupref set old_permissions=permissions where ref_fk=$pk";
  $dbh->do($sql);
  $sql = "update groupref set permissions=(permissions|$mask) where ref_fk=$pk";
  $dbh->do($sql);
}

#
# Don't worry about quality_control records.
# Samples/arraymeasurements are locked from changes including deletion long before
# quality_control records are created.
# 
# jul 19 2002 Tom says: What?? I wrote the comment above, and it is basically true, but
# then why did I write code to delete QC records? Perhaps we need a sanity check where
# none of this stuff will delete if there is data present and/or records are locked.
# 
# These functions form a tree. Deleting the 'parent' will take care
# of related records in other tables.
#
# 2003-02-24 Tom: There is no sanity checking here. The calling
# code needs to make sure orders, arraymeasurement records, etc.
# are not using this study
#

sub delete_study
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $sty_pk = $_[2];

  # Remove disease study link before removing study
  $dbh->do("delete from disease_study_link where sty_fk=$sty_pk");
  #
  # Get rid of exp_condition records before
  # deleting the study.
  #
  my $sth = getq("all_study_ec_pk", $dbh);
  $sth->execute($sty_pk);
  while((my $ec_pk) = $sth->fetchrow_array())
  {
    delete_exp_condition($dbh, $us_fk, $ec_pk);
  }
  $sth->finish();

  # now delete the study record
  $sth = getq("delete_study", $dbh);
  $sth->execute($sty_pk);
  delete_security($dbh, $sty_pk);
}

#
# No sanity check. Calling code has to be smart.
# 
sub delete_exp_condition
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $ec_pk = $_[2];

  # first delete all samples associated with the exp_condition
  my $ec_ref = get_ec_info($dbh, $us_fk, $ec_pk);
  my $smp_ref = $ec_ref->{smp_array_ref};
  my @smp_array = @$smp_ref;
  foreach $smp_ref(@smp_array)
  {
    delete_sample($dbh, $smp_ref->{smp_pk});
  }
  my $sth = getq("delete_exp_condition", $dbh);
  $sth->execute($ec_pk);
  delete_security($dbh, $ec_pk);
}

sub delete_order_info
{
  my $dbh = $_[0];
  my $oi_pk = $_[1];

  delete_billing($dbh, $oi_pk);
  delete_sample($dbh, undef, $oi_pk); # second param is smp_pk is undefined

  my $sth = getq("delete_order_info", $dbh);
  $sth->execute($oi_pk);
  delete_security($dbh, $oi_pk);
}

sub delete_billing
{
  my $dbh = $_[0];
  my $oi_fk = $_[1];
  my $sql;

  $sql = "delete from billing where oi_fk=$oi_fk";
  $dbh->do($sql);
}

# 
# Dual mode sub can be called ($dbh, $smp_pk, undef) or ($dbh, undef, $oi_fk)
# It is important to use undef since $smp_pk and $oi_fk are tested with defined()
# 
sub delete_sample
{
  my $dbh = $_[0];
  my $smp_pk = $_[1];
  my $oi_fk = $_[2];
  my $sth_ds = getq("delete_sample", $dbh);

  if (defined($smp_pk))
  {
    delete_arraymeasurement($dbh, undef, $smp_pk);
    $sth_ds->execute($smp_pk);
    delete_security($dbh, $smp_pk);
  }
  elsif (defined($oi_fk))
  {
    my $sth_oi = getq("select_sample_by_oi_fk", $dbh);
    $sth_oi->execute($oi_fk);
    #
    # Check for one or more rows. An order or sample could have zero 
    # hybridizations.
    # 
    if ($sth_oi->rows() > 0)
    {
      while(($smp_pk) = $sth_oi->fetchrow_array())
      {
        delete_arraymeasurement($dbh, undef, $smp_pk);
        $sth_ds->execute($smp_pk);
        delete_security($dbh, $smp_pk);
      }
    }
  }
}

# 
# Dual mode sub can be called ($dbh, $am_pk, undef) or ($dbh, undef, $smp_fk)
# It is important to use undef since $am_pk and $smp_pk are tested with defined()
# 
# Also deletes the related quality_control record
#
sub delete_arraymeasurement
{
  my $dbh = $_[0];
  my $am_pk = $_[1];
  my $smp_fk = $_[2];

  if (defined($am_pk))
  {
    my $sth_select_qc_fk = getq("select_qc_fk_by_am_pk", $dbh);
    $sth_select_qc_fk->execute($am_pk);
    (my $qc_fk) = $sth_select_qc_fk->fetchrow_array();
        
    my $sth_delete_quality_control = getq("delete_quality_control", $dbh);
    $sth_delete_quality_control->execute($qc_fk);
        
    my $sth = getq("delete_arraymeasurement", $dbh);
    $sth->execute($am_pk);
    delete_security($dbh, $am_pk);
  }
  elsif (defined($smp_fk))
  {
    #
    # Rather than doing a sub-select to delete the QC records, use a while loop.
    # It is more code, but the SQL is very simple.
    # Each sample can have multiple hybridizations e.g. multiple 
    # arraymeasurement records.
    # There is only one QC record per hybridization.
    #
    my $sth = getq("select_qc_fk_by_smp_fk", $dbh);
    $sth->execute($smp_fk);
    while((my $qc_fk) = $sth->fetchrow_array())
    {
      my $sth_qc = getq("delete_quality_control", $dbh);
      $sth_qc->execute($qc_fk);
    }
    my @am_pk_list = doq($dbh, "am_pk_list_where_smp_fk", $smp_fk);
    foreach my $am_pk (@am_pk_list)
    {
      delete_security($dbh, $am_pk);
    }
    $sth = getq("delete_arraymeasurement_by_smp_fk", $dbh);
    $sth->execute($smp_fk);
  }
}

sub tag_to_value
{
  my $type = $_[0];
  my $name = $_[1];
  my $all_lines = $_[2];
  my $orig_tag;
  my $new_tag;
  my $regex;
  if ($type eq "input")
  {
    $regex = "(<input.*?>)";
  }
  elsif ( $type eq "textarea")
  {
    $regex = "(<textarea.*?<\/textarea>)";
  }
  elsif ($type eq "select")
  {
    $regex = "(<select.*?\/select>)";
  }
  # Find the right type tab
  while ($all_lines =~ m/$regex/isg)
  {
    $orig_tag = $1;
    # Does this tag have the right name?
    if ($orig_tag =~ m/name.*?\"$name\"/is)
    {
      if ($orig_tag =~ m/({.*?})/)
      {
        $new_tag = $1;
      }
      else
      {
        $new_tag = "{$name}";
      }
      $all_lines =~ s/\Q$orig_tag\E/$new_tag/s;
      return $all_lines;
    }
  }
  #
  # Ick. Normal return is from inside the while() 
  # Nothing happened, so return the original input unchanged.
  #
  return $all_lines;
}

#
# HTML fix functions.
# Slightly modified from the blast pan versions to take the HTML
# as an arg, and return a string (instead of using a global)
# 

#
# fix radio and checkboxes
# returns string fixed_html = fixradiocheck(string name attribute,
#                                          string value attribute,
#                                          string "checkbox" | "radio",
#                                          string the_html_to_fix )
#
sub fixradiocheck
{
  my $find_name = $_[0];
  my $checked_value = $_[1];
  my $type = $_[2]; # checkbox or radio ?
  my $all_lines = $_[3];
  
  my $curr_tag;
  my @old_tag;
  my @new_tag;
  my $curr_name;
    
  while($all_lines =~ m/(<input type=\"$type\".*?>)/igs )
  {
    $curr_tag = $1;

    # if this doesn't match our name, just skip to the next
    if ($curr_tag !~ m/\"$find_name\"/igs)
    {
      next;
    }
  
    push(@old_tag,$curr_tag);

    #uncheck
    $curr_tag =~ s/(<input.*?)checked(.*?)>/$1 $2>/is;

    # if our value, re-check it
    if ($curr_tag =~ m/\"$checked_value\"/i)
    {
      $curr_tag =~ s/(<input.*?)>/$1 checked>/is;
    }
    push(@new_tag,$curr_tag);
  }
  foreach my $old (@old_tag)
  {
    my $new = shift(@new_tag);
    $all_lines =~ s/$old/$new/is;
  }
  return $all_lines;
}

#
# returns string fixed_html = fixselect(string HTML attriute "name",
#                                       string HTML attribute "value",
#                                       string the_html_to_fix);
#
sub fixselect
{
  my $select = $_[0]; # i.e. <select name = "$select">
  my $option = $_[1]; # i.e. <option value="$option" ... </option>
  my $all_lines = $_[2];
  my $curr_select;
  my $curr_name;
  my @select_arr;
  my $xx = 0;

  while($all_lines =~ m/(<select.*?\/select\>)/igs )
  {
    $curr_select = $1;
    $curr_select  =~ m/name.*?\"(.*?)\"/is;
    $curr_name = $1;

    if ($select =~ m/$curr_name/is)
    {
      last;
    }
  }
  
  #
  # Do and s// operations on $all_lines after the while() has completed.
  # It also works to push $curr_select into an array, and
  # separate out the process into two loops.
  #
  if ($select =~ m/$curr_name/is)
  {
    #
    # remove any existing 'selected' and add the correct one.
    # <option value="xyz" selected>xyz</option>
    # <option value="xyz" >xyz</option>
    # <option value="xyz">xyz</option>
    # Actually, the regexp grabs text starting with the first occurance
    # of '<option' all the way to 'selected'. Ditto wih the replacement.
    #
    $all_lines =~ s/\Q$curr_select\E/{curr_select}/is;
    $curr_select =~ s/(<option.*?)selected(.*?)>/$1 $2>/is;
    $curr_select =~ s/(<option.*?)(\"\Q$option\E\").*?>/$1$2 selected>/is;
    $all_lines =~ s/{curr_select}/$curr_select/is;
  }
  return $all_lines;
}

sub is_pi
{
  my $dbh = $_[0];
  my $login = $_[1];

  if (doq($dbh, "is_pi", $login) > 0)
  {
    return 1;
  }
  return 0;
}

# if no org_pk is passed in, returns whether us_fk is curator of any 
# organization.  if org_pk is passed in, returns whether us_fk is a 
# curator of that organizatin
sub is_org_curator
{
  my $dbh=$_[0];
  my $us_fk = $_[1];
  my $org_pk = $_[2];
  my $org_curator = 0;

  my $sth = getq("is_org_curator", $dbh, $us_fk, $org_pk);
  $sth->execute();
  while (my ($cur) = $sth->fetchrow_array())
  {
    $org_curator = 1 if ($cur == 1);
  } 
  return ($org_curator);
}

sub is_curator
{
  my $dbh=$_[0];
  my $us_fk = $_[1];
  (my $type) = $dbh->selectrow_array("select type from contact where 
      con_pk=$us_fk");
  
  return ($type =~ m/curator/);
}

sub is_administrator
{
  my $dbh=$_[0];
  my $us_fk = $_[1];
  (my $type) = $dbh->selectrow_array("select type from contact where 
      con_pk=$us_fk");
  
  return ($type =~ m/administrator/);
}

sub is_public
{
  my $dbh=$_[0];
  my $us_fk = $_[1];
  (my $type) = $dbh->selectrow_array("select type from contact where 
      con_pk=$us_fk");
  
  return ($type =~ m/public/) ;
}

# Pass in a valid database handle.
# get_us_fk() - this is the new routine for getting a us_fk.  We request 
# cookies from the browser to determine users identity.  If there are no 
# cookies, we redirect to the login page.  If there are cookies, we check 
# the session db to make sure that they haven't expired (we don't depend 
# on the cookie expiration, we keep a local copy of when we want the cookie
# to expire).  If the cookie is valid, we return the us_fk associated with
# the session id in the cookie.  Also, we update the cookie and the expire
# time, so that we effectively have an inactivity logout.
#If the cookie is not valid, we request login.
# 
# 
sub get_us_fk
{
  # ignore passed-in dbh, since we update the expiration time
  # and commit on the handle
  my $dbh = $ses_dbh;
  my $page = $_[1];
  
  if (!defined($dbh))
  {
    write_log("dbh undefined in get_us_fk");
    exit();
  }

  my $us_fk = -1;
  my %cookies = fetch CGI::Cookie;
  my @keys = keys(%cookies);
  foreach (keys %cookies)
  {
    my $wwwhost = get_config_entry($dbh, "wwwhost");
    my $cookie_name = $wwwhost . $COOKIE_NAME;
    if ($cookies{$_}->name() eq $cookie_name) 
    {
      my $sessionid = $cookies{$_}->value();
      $dbh->quote($sessionid);
      my $sql= "select session_pk, us_fk, expiration from session 
        where session_id='$sessionid'";   
      my ($sess_pk, $us_fk_temp, $expire) = $dbh->selectrow_array($sql);
      my $now = time();
      my $type;

      if ($expire < $now)
      { 
        $us_fk_temp = -1;
      } 
      else
      {
        # update cookie and expire time
        # expire the cookie

        $cookies{$_}->expires('now');
        print "Set-Cookie: $cookies{$_}\n";
        my $name;
         
        my $sth = getq("get_user_type", $dbh, $us_fk_temp);
        $sth->execute();
        ($type) = $sth->fetchrow_array();
        $sth->finish(); 

        my $expire = get_expire($dbh, $sessionid, $cookie_name,
            $type);
        my $sql = "update session set expiration = '$expire' where 
          session_id = '$sessionid'";
        $dbh->do($sql);
        $dbh->commit();
        $us_fk = $us_fk_temp;
      }
    }
  }

  if ((defined $us_fk) && ($us_fk != -1))
  {
    my $login;
    $login = doq($dbh, "get_login", $us_fk);
    $ENV{REMOTE_USER} = $login; 
    return $us_fk; 
  }

  # if we don't have a valid login, return the login page
  my $url = index_url($dbh, "webtools");
  $url .= "/login.cgi";
  $url .= "?page=$page";
  print "Location: $url\n\n";  
  $ENV{REMOTE_USER} = ""; 
  return -1;
}

# val is the random session_id
sub get_expire
{
  my ($dbh,$val,$name, $type) = @_;

  if ($type eq "curator")
  {
    $type = "inact_logout_curator";
  } elsif ($type eq "administrator")
  {
    $type = "inact_logout_administrator";
  } else
  {
    $type = "inact_logout_general";
  }

  # may wish to sanity check the logout value 
  my $inactivity = get_config_entry($dbh, $type);
  if ((!defined $inactivity) || ($inactivity < 1) || ($inactivity > 10080)) 
  {
    $inactivity = "15";
  }
  my $logout = "+" . $inactivity . "m";
  # tells the cookie to expire after a $inactivity minutes
  my $cookie = new CGI::Cookie(-name=>"$name", -value=>$val,
    -expires=>$logout);
  print "Set-Cookie: $cookie\n";
   
  # inactivity is in minutes.  We need to return it in seconds,
  # added to time() which returns seconds since epoch
  return( time() + 60 * $inactivity );
}

# This routine returns true if there is a message for the current user in 
# the key_value table
sub is_value
{
  my ($dbh, $us_fk, $type, $key) = @_;

  my ($sid, $sess_fk) = get_sess_id($dbh, $us_fk) if ($type ne 'global');
  my $sql="select count(*) from key_value where 1=1 ";
  $sql .= " and session_fk='$sess_fk'" if ($type ne 'global');
  $sql .= " and type = '$type'" if ($type ne "");
  $sql .= " and key='$key'" if ($key ne "");
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my ($count) = $sth->fetchrow_array();
  $sth->finish();
  return ($count); 
}

sub get_sess_id
{
  my ($dbh, $us_fk) = @_;
  my $sid = ""; my $sess_fk;
  my $sql= "select session_pk, session_id, expiration from session where us_fk='$us_fk'";   
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my ($sess_fk_temp, $sid_temp, $expire) = $sth->fetchrow_array())
  {
     my $now = time();

     if ($expire > $now)
     {
        $sid = $sid_temp;
        $sess_fk = $sess_fk_temp;
     }
  } 
  die ("No session id in get_sess_id for us_fk:$us_fk") if ($sid eq "");
  return ($sid, $sess_fk);
}

# This will return all values from the key_value table of type "type" for
# the current user.  Values are returned in an array. The first element is
# a key and the next one is the value for that key.  I did not return a 
# hash, as there may be multiple records with the same key (most 
# notably message).  Returned values are deleted from the key_value table.
#
# duplicate messages are erased before return
#
sub get_session_val
{
  my ($dbh, $us_fk, $type, $key) = @_;

  my ($sid, $sess_fk) = get_sess_id($dbh, $us_fk) if ($type ne 'global');
  my $sql="select key, value from key_value where 1=1";
  $sql .= " and session_fk='$sess_fk'" if ($type ne 'global');
  $sql .= " and type = '$type'" if ($type ne "");
  $sql .= " and key='$key'" if ($key ne "");
  my $sth = $dbh->prepare($sql) ; 
  $sth->execute(); 
  my @values;
  my %messages = ();

  while (my ($key, $value) = $sth->fetchrow_array())
  {
    if ($type eq "message")
    {
      if (!defined $messages{$value})
      {
        $messages{$value} = 1;
        push @values, $key, $value; 
      }
    }
    else
    {
      push @values, $key, $value; 
    }
  }
  
  $sql="delete from key_value where 1=1 "; 
  $sql .= " and session_fk='$sess_fk'" if ($type ne 'global');
  $sql .= " and type = '$type'" if ($type ne "");
  $sql .= " and key='$key'" if ($key ne "");
  $dbh->do($sql);
  $dbh->commit();
  return (\@values); 
}

# Current type values are:
#  errmessage - a message containing an error
#  goodmessage - a message containing a confirmation
#  warnmessage  - a message containing a warning
#  extract - information of values for file extract
#  global - global values not assoc. with a specific session,
#           like yearoflastrollover
#  newkv - sequence number for keyvalue records, used for adding
#           new exp_conds to a study before they are committed
#  pi_user - the user being modified for "Manage PIs and Users"

sub set_session_val
{
  my ($dbh, $us_fk, $type, $key, $value) = @_;

  my ($sid, $sess_pk) = get_sess_id($dbh, $us_fk) if ($type !~ /global/);

  $type = $dbh->quote($type);
  $key = $dbh->quote($key);
  $value = $dbh->quote($value);

  my $sql;
  if ($type !~ /global/)
  {
     $sql= "insert into key_value (session_fk, type, key, value) values " .
           "($sess_pk,$type,$key,$value)";
  }
  else
  {
    $sql= "insert into key_value (type, key, value) values " .
          "($type,$key,$value)";
  }
  $dbh->do($sql);
  $dbh->commit();
}

sub get_stored_messages
{
  my ($dbh, $us_fk) = @_;
  my $messagestr = "";
  if ($us_fk ne "command")
  {
    my $messageref = get_session_val($dbh, $us_fk, "message", "");
    foreach (@$messageref)
    {
      next if ($_ =~ /^(err|warn|good)message$/);
      $messagestr .= $_;
    }
    return ($messagestr);
  }
}

sub get_all_subs_vals
{
  my ($dbh, $us_fk, $chref) = @_;
  my %ch = %$chref;
  my $confref = get_all_config_entries($dbh);
  @ch{keys %$confref} = values %$confref;
  $ch{geoss_dir} = $GEOSS_DIR; $ch{version} = $VERSION;
  $ch{message} .= get_stored_messages($dbh, $us_fk);
  $ch{footer_login} = doq($dbh, "get_login", $us_fk);
  my $sth = getq("get_user_type", $dbh, $us_fk);
  $sth->execute();
  ($ch{footer_type}) = $sth->fetchrow_array();
  $ch{footer_type} = "Array Center Staff" if ($ch{footer_type} eq "curator");
  $ch{footer_type} = "Public" if ($ch{footer_type} eq "public");
  $ch{footer_type} = "Administrator" if ($ch{footer_type} eq "administrator");
  $ch{footer_type} = "Member User" 
    if ($ch{footer_type} eq "experiment_set_provider");

  $sth->finish(); 
  my $url = index_url($dbh);

  # strip the last dir, which is admintools, webtools, or public_data
  $url =~ /(.*)\/.*/;
  my $web_index = "$1/webtools";
  my $admin_index = "$1/admintools";
  my $org_index = "$1/orgtools";
  my $cur_index = "$1/curtools";

  $ch{member_home} = $web_index;
  $ch{logout_url} = "$web_index/logout.cgi";
  if (is_administrator($dbh, $us_fk))
  {
    $url = index_url($dbh);
    $ch{admin_home} = "<a href=\"$admin_index\">Admin Home</a>&nbsp;";
    $ch{org_home} = "<a href=\"$org_index\">Center Home</a>&nbsp;";
  }
  if ((is_curator($dbh, $us_fk)) && get_config_entry($dbh, "array_center"))
  {
    $url = index_url($dbh);
    $ch{cur_home} = "<a href=\"$cur_index\">Array Center Staff Home</a>&nbsp;";
  }
  if ((is_org_curator($dbh, $us_fk)) && get_config_entry($dbh, "array_center"))
  {
    $url = index_url($dbh);
    $ch{org_home} = "<a href=\"$org_index\">Center Home</a>&nbsp;";
  }
  if ((defined $ch{linkurl1}) && (defined $ch{linktext1}))
  {
    $ch{link1} = "<a href=\"$ch{linkurl1}\">$ch{linktext1}</a>&nbsp;"; 
  }
  return (\%ch);
}

sub set_help_url
{
  my ($dbh, $basename, $anchor) = @_;
  $basename = "index" if (! $basename);
  my $temp = index_url($dbh);
  $temp =~ /(.*)\/.+/;
  $basename = $1 . "/webdoc/EN/html/" . $basename . ".html";
  $basename .= "#$anchor" if ($anchor);

  return($basename);
}

# can be used for files that don't need readtemplate
# combines getting all stored messages and getting the configuration information
# with reading the input file and substituting
sub get_allhtml
{
  my ($dbh, $us_fk, $htmlfile, $headerfile, $footerfile, $chref) = @_;
  my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};
  my $allhtml = readfile($htmlfile, $headerfile, $footerfile);

  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  return $allhtml;
}

sub new_connection {
  use GEOSS::Database;
  return $dbh;
}

#
# (my $from_clause, my $where_clause) = read_where_clause(string table, string primary_key_field_name, integer userid) 
#
# If owner or group read permissions are true, a record is readable.
# The where clause that we return includes surrounding ()
# since the calling code almost always does something like
# "select * from table,$from_clause where table_pk=1 and $where_clause";
#
# jul 29 2002 Tom
# Check permissions by masking with the read bit for user read and group read.
#
sub read_where_clause
{
  my $table = $_[0];
  my $pkey = $_[1];
  my $userid = $_[2];

  my $from = "groupref, grouplink";

  my $where = "(groupref.ref_fk=$table.$pkey and
    ((grouplink.us_fk=$userid and
     groupref.us_fk=grouplink.us_fk and
     grouplink.gs_fk=groupref.gs_fk and
     (groupref.permissions&256)>0) or 

    (groupref.gs_fk=grouplink.gs_fk and
     grouplink.us_fk=$userid and
     (groupref.permissions&32)>0 )))"; 

  return ($from, $where);
}

#
# (my $from_clause, my $where_clause) = write_where_clause(string $table, string $primary_key_field_name, integer $userid);
#
# select all records that $userid is allowed to write
# The where clause returned includes enclosing () since the
# calling code almost always does something like
# "select * from table,$from_clause where table_pk=1 and $where_clause";
#
# jul 29 2002 Tom
# Fix owner is user to include 128 (user write bit) set,
# and owner group contains user to include 16 (group write bit) set.
# Note that we don't have world readable in the Unix sense, and plan to manage that with groups.
#
sub write_where_clause
{
  my $table = $_[0];
  my $pkey = $_[1];
  my $userid = $_[2];
    
  chomp ($table);
  chomp ($pkey);
  chomp ($userid);
  my $from = "groupref, grouplink";
    
  # was grouplink.gs_fk=grouplink.us_fk
  my $where = "(groupref.ref_fk=$table.$pkey and ((groupref.us_fk=$userid 
    and groupref.us_fk=grouplink.us_fk and grouplink.gs_fk=groupref.gs_fk 
    and (groupref.permissions&128)>0) or (groupref.gs_fk=grouplink.gs_fk 
    and grouplink.us_fk=$userid and (groupref.permissions&16)>0 )))";

  return ($from, $where);
}

sub is_writable
{
  (my $dbh, my $table, my $pkey, my $pk_value, my $us_fk) = @_;

  my $where_clause;
  my $from_clause;
  ($from_clause, $where_clause) = write_where_clause($table, $pkey, $us_fk);
  my $sql = "select count($pkey) from $table, $from_clause 
    where $pkey=$pk_value and $where_clause";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  ((my $row_count) = $sth->fetchrow_array());
  $sth->finish();

  if ($row_count == 1)
  {
    return 1;
  }
  else
  {
    if ($row_count == 0)
    {
      write_log("security violation (?) rows returned: $row_count sql: $sql");
      #die "Returned zero rows, but 1 row was expected\n";
      return 0;
    }
    elsif ($row_count > 1)
    {
      write_log("security violation (?) rows returned: $row_count sql: $sql");
      die "Returned $row_count rows, but 1 row was expected\n";
    }
    write_log("security violation (?) rows returned: $row_count sql: $sql");
    die "Returned $row_count rows, 1 row was expected $pkey $pk_value\n$sql\n";
    return 0;
  }
}

sub delete_security
{
  my $dbh = $_[0];
  my $which_pk = $_[1];
  my $sth = getq("check_write_permissions", $dbh);
  $sth->execute($which_pk);
  if ($sth->rows() == 1)
  {
    $sth->finish();
    $sth = getq("delete_groupref", $dbh);
    $sth->execute($which_pk);
  }
  else
  {
    write_log(
     "Encountered permission problem from groupref where ref_fk = $which_pk");
    die "Encountered permission problem from groupref where ref_fk = $which_pk";
  }
}

sub insert_security
{
  my $dbh = $_[0];
  my $userid = $_[1];
  my $groupid = $_[2];
  my $permissions = $_[3];

  #
  # last_pk_seq uses currval, which assumes that nextval has been called 
  # in this session
  #
  my $pk = doq($dbh, "last_pk_seq"); # see sql_lib
  if ($permissions == 0)
  {
    $permissions = 416; # octal \640 rw- r-- ---  u+rw,g+r
  }
  my $sth = getq("insert_security", $dbh);
  $sth->execute($userid, $groupid, $permissions, $pk);
  return $pk;
}

sub index_url
{
  my ($dbh, $dir) = @_;
  my $protocol = "http";
  if (exists($ENV{HTTPS}))
  {
    $protocol = "https";
  }
  my $url;
  if ($dir)
  {
    # we want the url for a specific directory, as opposed to
    # the one we are in
    $url = "$protocol://" ;
    $url .= get_config_entry($dbh, "wwwhost");
    $url .= get_config_entry($dbh, "additional_path");
    $url .=  "/" . $dir; 
  }
  else
  {
    $url = "$protocol://$ENV{HTTP_HOST}$ENV{REQUEST_URI}";
    # 
    # Fix this to return the base URL, and understand ~userid URLs
    # Return the URL without the final file name, and without the trailing /
    # 
    if ($url =~ m/\/~/)
    {
      $url =~ s/(.*\/~.*)\/.*/$1/;
    }
    else
    {
      $url =~ s/(.*)\/.*/$1/;
    }
  } 
  return $url;
}

sub sql2date
{
  my $sqldate = $_[0];
  my $zz = "00";

  #
  # Someone's date code isn't quite following some standard. Unix 'date'
  # wants timezone spec to be a full 4 digits, including trailing zeros.
  # SQL uses two digit time zones, and shoves them up against the seconds
  # field. For example: 2002-05-13 15:29:41-04
  # 
  # If the timezone spec is only 2 digits, then add a leading space and trailing zeros.
  # Transform to this:  2002-05-13 15:29:41 -0400
  #

  $sqldate =~ s/-(..)$/ -$1$zz/;

  my $nicedate = `date --date="$sqldate" +"%Y-%m-%d"`;
  chomp($nicedate);
  return $nicedate;
}

sub date2sql
{
  my $datestr = $_[0];
  #
  # The unix date function does odd things with -04, although it 
  # works fine with -0400. Just remove the trailing timezone offset.
  #
  # At the unix command line compare:
  # date --date="apr 29, 2002 00:00:00"
  # date --date="apr 29, 2002 00:00:00-0400"
  # date --date="apr 29, 2002 00:00:00-04"
  # The last gives an incorrect time of 20:04:00.
  #
  $datestr =~ s/:\d\d\-04$//;

  # We used to use --iso-8601=seconds but that required using a regex 
  # to fix the T in the middle of the output.
  # Instead, just give SQL what it wants. The man page for date says 
  # that %z is an RFC-822 style numeric timezone, and is a non-standard 
  # extension. I've used it even though Postgres currently parses normal 
  # time zones (e.g. EDT).
  my $sqldate = `date --date="$datestr" +"%Y-%m-%d %H:%M:%S %z"`;
  chomp($sqldate);
  return $sqldate;
}        


#
# Make the database reflect the set of checkboxes returned from the web form.
# Delete any records that are no longer checked, but exist in the db.
# Insert things that are checked but don't exist in the db.
# The other two cases require no change (exists and checked, doesn't exist 
# and isn't checked)
#
sub update_grouplink
{
  my $dbh = $_[0];
  my $gs_pk = $_[1];
  my %glhash = %{$_[2]};
  my $key;
  my $value;
  my %dbhash;
  my $sql;
  my $debug; 

  my $sth = $dbh->prepare("select us_fk,gs_fk from grouplink where 
      gs_fk=$gs_pk");
  $sth->execute();

  while(($key, $value) = $sth->fetchrow_array())
  {
    $dbhash{$key} = $value;
  }
  $sth->finish();

  foreach $key (keys(%dbhash))
  {
    if (! exists($glhash{$key}))
    {
      # it is in the db, but not returned from the web form, delete from the db.
      $sql = "delete from grouplink where us_fk=$key and gs_fk=$gs_pk";
      $dbh->do($sql);
    }
  }
  foreach my $key (keys(%glhash))
  {
    if (! exists($dbhash{$key}))
    {
      # returned from the web form, but is not in the db, insert into the db.
      $sql = "insert into grouplink (us_fk, gs_fk) values ($key, $gs_pk)";
      $dbh->do($sql);
    }
  }
}

sub email_generic
{
  my ($dbh, $e_file, $inforef) = @_;
  my %info = %$inforef;
  my $wwwhost = get_config_entry($dbh, "wwwhost");

  if ($wwwhost eq "")
  {
    $info{nextURL}  = "Contact your administrator for your login url\n";
  }
  else
  {
    $info{nextURL}  = "http://$wwwhost" . 
    get_config_entry($dbh, "additional_path");
  }
  $info{fromMail} = get_config_entry($dbh, "admin_email");;
  $info{ccMail}   = get_config_entry($dbh, "alt_curator_email");

  my $email = readfile("$e_file");
   
  $email =~ s/{(.*?)}/$info{$1}/g;

  my $sendmail;
  foreach ("/usr/sbin", "/usr/lib")
  {
    if (-x "$_/sendmail")
    {
      $sendmail = $_ . "/sendmail";
    }
  }
  if ($sendmail)
  {   
    open (MAIL, "| $sendmail -t -oi")  || warn "Unable to open |
      $sendmail: $!";
    print MAIL "$email\n"  || warn "Unable to print to MAIL";
    close MAIL || warn "Unable to close MAIL: $!";
  }
  else
  {
    warn "Unable to send email due to failure to locate sendmail";
  }
}

sub exists_email
{
  my $email = $_[0];
  my $temp = <<EOS;
Warning: The email: $email already exists in our contact database.\n
EOS
  return $temp;
}

sub pw_generate
{
  my (@passset, $rnd_passwd, $randum_num);
        
  # Since 1 ~= l and 0 =~ O, don't generate passwords with them.
  # This will just confuse people using ugly fonts.
  #
  @passset = ('a'..'k', 'm'..'z', 'A'..'N', 'P'..'Z', '2'..'9');
  $rnd_passwd = "";
  my $i;
  for ($i = 0; $i < 8; $i++) {
    $randum_num = int(rand($#passset + 1));
    $rnd_passwd .= $passset[$randum_num];
  }
  return $rnd_passwd;
}

sub pw_encrypt
{
  my ($login, $password) = @_;
  my $salt=substr($login,0,2);
  return crypt($password,$salt);
}

sub valid_email_check
{
  my ($email) = @_;
  return(1);
}

sub invalid_password
{
  my ($dbh, $us_fk, $password) = @_;
  my $ret_string;
  if ((! ($password =~ m/(\S*)/ && $password eq $1)) ||
      (length($password) < 6))
  {
    $ret_string .= set_return_message($dbh, $us_fk, "message", "errmessage",
        "INVALID_PASSWORD");
  }
  return ($ret_string);
}

# verify_acct_generic should be called prior to calling this function
#
# values for the new account are passed in via the acctref hash
# calling functions can pass in as little as login, pi_login, type
# password, confirm_password or all the fields in contact
# Note that if us_fk is set to "command", we assume that we are 
# being called from a command line utility and return messages
# as a string instead of setting values in the session.
sub create_acct_generic 
{
  my ($dbh, $us_fk, $acctref) = @_;

  my $sql;
  my $sth;
  my $create = "true";
  my $ret_string = "";
 
  my ($type, $organization, $contact_fname, $contact_lname, 
      $contact_phone, $contact_email, $department, $building, 
      $room_number, $cancer_center_member, $org_phone, $org_email, 
      $org_mail_address, $org_toll_free_phone, $org_fax, $url, 
      $credentials, $login, $password, $confirm_password, $pi_login) = "";


  $type = $acctref->{type};
  $login = $acctref->{login};
  $pi_login = $acctref->{pi_login};
  $password = $acctref->{password};
  $confirm_password = $acctref->{confirm_password};
  $organization = $acctref->{organization};
  $contact_fname = $acctref->{contact_fname};
  $contact_lname = $acctref->{contact_lname};
  $contact_phone = $acctref->{contact_phone};
  $contact_email = $acctref->{contact_email};
  $department = $acctref->{department};
  $building = $acctref->{building};
  $room_number = $acctref->{room_number};
  $org_phone = $acctref->{org_phone};
  $org_email = $acctref->{org_email};
  $org_mail_address = $acctref->{org_mail_address};
  $org_toll_free_phone = $acctref->{org_toll_free_phone};
  $org_fax = $acctref->{org_fax};
  $credentials = $acctref->{credentials};

  my $epasswd = &pw_encrypt($login, $password);
  my $success = doq($dbh, "insert_contact", $type, $organization, 
      $contact_fname,
      $contact_lname, $contact_phone, $contact_email, $department, 
      $building, $room_number, $org_phone, $org_email,
      $org_mail_address, $org_toll_free_phone, $org_fax, $url, 
      $credentials); 
  if ($success)
  {
    $@ =~ /(ERROR.*)/;
    my $msg = $1;
    $dbh->rollback();
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
      "ERROR_POSTGRES", $msg);
  }
  else
  {
    my $fk = doq($dbh, "last_guc");
    doq($dbh, "insert_usersec", $fk, $fk, $login, $epasswd);
    doq($dbh, "insert_groupsec", $fk, $fk, $login);

    my $add_cur = get_config_entry($dbh, "add_curator_to_groups");
    # add self to the group
    doq($dbh, "insert_grouplink", $fk, $fk);
      
    # assign the PI
    my $pi_us_pk = doq($dbh, "get_us_pk", $pi_login);
    doq($dbh, "insert_pi_key", $fk, $pi_us_pk); 
      
    if ($add_cur)
    {
      # add all curators to the group
      # get all curators
      my $cur_sth = getq("get_all_us_pks_by_type", $dbh, "curator");
      $cur_sth->execute();
      while (my ($cur_pk) = $cur_sth->fetchrow_array())
      {
        doq($dbh, "insert_grouplink", $cur_pk, $fk) if ($fk != $cur_pk);
      }

      if ($type eq "curator") 
      {
        # get all groups (will include the one we just selected)
        my $group_sth = getq("get_all_gs_pks", $dbh);
        $group_sth->execute();
        # add the new curator to all groups
        while (my ($cur_gs_pk) = $group_sth->fetchrow_array())
        {
          doq($dbh, "insert_grouplink", $fk, $cur_gs_pk) if ($fk !=
            $cur_gs_pk);
        }
      } 
    }
 
  
    # if the user we are inserting isn't the pi, then put the user
    # into the pis group
        
    if ($pi_us_pk != $fk)
    {
      if (! (($type eq "curator") && ($add_cur)))
      {
        doq($dbh, "insert_grouplink", $fk, $pi_us_pk);
      }
    } 
          
    # add the user to all organizations that they are part of
    # get the organizations
    my $sth=getq("select_all_organizations", $dbh);
    $sth->execute();
    my $hr;
    while($hr = $sth->fetchrow_hashref())
    {
      my $org_name = $hr->{org_name};
      if ((exists $acctref->{$org_name}) &&
          ($acctref->{$org_name} ne "No"))
      {
        my $curator = 'f';
        $curator = 't' if ($acctref->{$org_name} eq "Curator");
        doq_insert_org_usersec_link($dbh, {"org_fk", $hr->{org_pk}, 
          "us_fk", $fk, "curator", $curator});
      }

    }

    # add the user to group "public" if they are not already a part of it
    my $sql = "select count(*) from usersec where login = 'public'";
    $sth = $dbh->prepare($sql);
    $sth->execute();
    my $count = $sth->fetchrow_array();
    if ($count == 1) 
    {
      my $public_fk = doq($dbh, "get_us_pk", "public");
      if ($public_fk > 0)
      {
        my $sql = "select count(*) from grouplink where us_fk=$fk and
          gs_fk=$public_fk";
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        my $count = $sth->fetchrow_array();
        if ($count == 0)
        {
          doq($dbh, "insert_grouplink", $fk, $public_fk);
        }
      }
    }
    else
    {
      warn "New user not inserted into the 'public' group due to an
        inability to determine the us_pk for the 'public' user"
        if (($login ne "public") && ($login ne "admin")); 
    }

    # Create the user's file repository directory.
    # The permissions setting for Perl's mkdir command 
    # depends on the umask, which defaulted to 022.
    # Setting 770 turned into 750. The Linux mkdir ignores the umask.

    umask(0002);
    mkdir("$USER_DATA_DIR/$login", 0770);
    `chgrp $WEB_USER $USER_DATA_DIR/$login`;

    #
    # aug 15 2002 Tom: For security, don't send the passwords in email
    #
    my ($pi_login, $pi_gs_name, $pi_fname, $pi_lname, $pi_phone, $pi_email) =
       doq($dbh, "user_info", $pi_us_pk, $pi_us_pk);
    
    if ($contact_email)
    {
      my $email_file;
      if ($type eq "public")
      {
        $email_file = "$WEB_DIR/site/req_account_pub_email.txt";
      }
      else
      {
        $email_file = "$WEB_DIR/site/webtools/admin_email.txt";
      }
      email_generic($dbh, $email_file, { 
          "name" => "$contact_fname $contact_lname", 
          "email" => "$contact_email",
          "login" => "$login",
          "pi_name" => "$pi_fname $pi_lname",
          "password" => $password, 
          "days" => get_config_entry($dbh, "days_to_confirm")
        } );
    }
    if ($pi_email && ($pi_login ne $login))
    {
      my $email_file = "$WEB_DIR/site/curtools/pi_email.txt";
      email_generic($dbh, $email_file, {
        "name" => "$contact_fname $contact_lname", 
        "email" => "$pi_email",
        "login" => "$login",
        "pi_name" => "$pi_fname $pi_lname",
      });
    }
    $dbh->commit();
    $ret_string .= set_return_message($dbh, $us_fk, "message", "errmessage", 
      "SUCCESS_ADD_USER", "$login");
  }
  return $ret_string;
} 

sub set_session_val_or_str
{
  my ($dbh, $us_fk, $message, $messtype, $msgnum, $param) = @_;
  return (set_return_message($dbh, $us_fk, "message", 
      "errmessage", $msgnum, "$param"));
}

# interface should be "command" if this function is being called 
# from the command line, otherwise it should be ""
sub change_password_generic
{
  my ($dbh, $caller_us_fk, $caller_password, $change_us_fk,
       $new_password, $confirm_password, $caller_type, $change_type,
       $interface) = @_;
  my $change = "true";
  my $ret_string = "";

  $interface = $caller_us_fk if ($interface ne "command");
  $caller_password = substr($caller_password, 0, 30);
  $new_password = substr($new_password, 0, 30);
  $confirm_password = substr($confirm_password, 0, 30);

  if ((! $new_password) || (! $confirm_password))
  {
    $ret_string .= set_session_val_or_str($dbh, $interface, "message",
      "errmessage", "INVALID_PASSWORD");
    $change = "false";
  }

  if ($new_password ne $confirm_password)
  {
    $ret_string .= set_session_val_or_str($dbh, $interface, "message",
      "errmessage", "ERROR_PASSWORD_MISMATCH");
    $change = "false";
  }

  if (length($new_password) < 6)
  {
    $ret_string .= set_session_val_or_str($dbh, $interface, "message",
      "errmessage", "INVALID_PASSWORD");
    $change = "false";
  }

  my $change_login = doq_get_login($dbh, $change_us_fk);
  my $caller_login = doq_get_login($dbh, $caller_us_fk);

  my $crypt_pass = pw_encrypt($caller_login, $caller_password);
  my $curr_crypt_password = doq_get_pw($dbh, $caller_us_fk, $caller_us_fk);

  if ($caller_type ne "admin_")
  {
    if ($crypt_pass ne $curr_crypt_password)
    {
     $ret_string .= set_session_val_or_str($dbh, $interface, "message",
        "errmessage", "ERROR_INVALID_LOGIN");
     $change = "false";
    }
  }
  
  if (($caller_type ne "admin_") && ($change_login ne $caller_login))
  {
     $ret_string .= set_session_val_or_str($dbh, $interface, "message",
        "errmessage", "INVALID_PERMS");
     $change = "false";
  }

  if ($change eq "true")
  {
    # change the password
    my $crypt_new_pass = pw_encrypt($change_login, $new_password);
    my $change_old_pass = doq_get_pw($dbh, $caller_us_fk, $change_us_fk);
    doq_set_pw($dbh, $change_us_fk, $crypt_new_pass, $change_old_pass);
    $ret_string .= set_session_val_or_str($dbh, $interface, "message",
        "goodmessage", "SUCCESS_CHANGE_PASSWORD", $change_login);
    $dbh->commit();
  }

  $change = $ret_string if ($interface eq "command");
  return $change;
}

sub readtemplate
{
  my $allhtml = readfile(@_);
  my $loop_template;
  my $loop_template2;
  my $loop_tween;
  my $loop_template3;
  my $loop_template4;
  if ($allhtml =~ s/<loop4>(.*)<\/loop4>/<loop_here4>/s)
  {
    $loop_template4 = $1;
  }
  if ($allhtml =~ s/<loop3>(.*)<\/loop3>/<loop_here3>/s)
  {
    $loop_template3 = $1;
  }
  if ($allhtml =~ s/<loop2>(.*)<\/loop2>/<loop_here2>/s)
  {
    $loop_template2 = $1;
  }
  if ($allhtml =~ s/<loop>(.*)<\/loop>/<loop_here>/s)
  {
    $loop_template = $1;
  }
  if ($loop_template =~ s/<tween>(.*?)<\/tween>//s)
  {
    $loop_tween = $1;
  }
  return ($allhtml, $loop_template, $loop_tween, $loop_template2,
    $loop_template3, $loop_template4);
}

# This routine will read in a file (typically an html one).
# It will iprepend/append the specified header and footer files.  Pass an empty
# string or null if header/footer added to file is not desired.
sub readfile
{
  my ($infile, $headerfile, $footerfile) = @_;
  my $temp;
  my $header = "";
  my $footer = "";
  #
  # 2003-01-10 Tom:
  # It is possible that someone will ask us to open a file with a leading space.
  # That requires separate args for the < and for the file name. I did a test to confirm
  # this solution. It also works for files with trailing space.
  # 
  # open(IN, "<", "$_[0]");
  # Keep the old style, until the next version so that we don't have to retest everything.
  # 
  my @stat_array = stat($infile);
  if ($#stat_array < 7)
  {
    die "File $_[0] not found\n";
  }
  open(IN, "< $infile");
  sysread(IN, $temp, $stat_array[7]) ||
  die "Couldn't open $temp: $!";
  close(IN);
  my $path = $WEB_DIR;  
  if ((defined $headerfile) || ($headerfile ne ""))
  {
    @stat_array = stat("$path/$headerfile");
    if ($#stat_array < 7)
    {
      die "File $path/$headerfile not found\n";
    }
    open(IN, "$path/$headerfile") || 
    die "Couldn't open $path/$headerfile: $!";
    sysread(IN, $header, $stat_array[7]);
    close(IN);
  }
  if ((defined $footerfile) || ($footerfile ne ""))
  {
    @stat_array = stat("$path/$footerfile");
    if ($#stat_array < 7)
    {
      die "File $footerfile not found\n";
    }
    open(IN, "$path/$footerfile") ||
    die "Couldn't open $path/$footerfile: $!";
    sysread(IN, $footer, $stat_array[7]);
    close(IN);
  }
  $temp =  $header . $temp . $footer;
  return $temp;
}

#
# If we have a user, and that user has a GEOSS file area, write the error 
# file there.
# Otherwise just write errors to the current directory.
#
sub write_log
{
  my $time = time();
  my $et = $time - $::ptime;
  $::ptime = $time;

  my $fn;
  if (exists($ENV{REMOTE_USER})  && (-d "$USER_DATA_DIR/$ENV{REMOTE_USER}"))
  {
    $fn = "$USER_DATA_DIR/$ENV{REMOTE_USER}/error.txt";
  }
  else
  {
    $fn = "error.txt";
  }

  open(LOG_OUT, ">> $fn") || die "$ENV{REMOTE_USER} cannot open log $fn: $!\n";
  print LOG_OUT "$et $time $_[0]\n";
  close(LOG_OUT);
  chmod(0660, $fn);
}

sub get_file_hash
{
  my ($dbh, $us_fk, $hyb_name, $override_path) = @_;

  my $success = "";

  my %files = ();
  $hyb_name = lc($hyb_name);
  (my $order_number, my $abbrev_name, my $letter, my $number) = 
    split("_", $hyb_name);

  my $cl_safe_cdp;
  if (! $override_path)
  {
    $cl_safe_cdp = get_config_entry($dbh, "chip_data_path");
  }
  else 
  {
    $cl_safe_cdp = $override_path;
  }
  $cl_safe_cdp =~ s/ /\ /g;
  
  my $ext;
  my $path;
  foreach $ext ("txt", "dtt", "cab", "cel","dat","chp","exp","rpt")
  {
    my @flist;
    if (($ext ne "cab") && ($ext ne "dtt"))
    {
      @flist = `find "$cl_safe_cdp" -iname "${hyb_name}.${ext}"`;
      if ($?)
      {
        warn "Error in find \"$cl_safe_cdp\" -iname \"${hyb_name}.${ext}\"";
      } 
    }
    else
    {
      if ($path)
      {
        @flist = `find "$path" -iname "*$order_number*.${ext}"`;
        if ($?)
        {
          warn "Error in find \"$path\" -iname \"*$order_number*.${ext}\"";
        }
      }
    }
    # there may be multiple cab files
    if (($#flist > 0) && ($ext ne "cab") && ($ext ne "dtt"))
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DATA_LOAD_DUPLICATES", "$flist[0]");
    }
    elsif (($#flist <0) && ($ext eq "txt") )
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DATA_LOAD_NO_DATA_FILE", "${hyb_name}.${ext}", $path);
    }
    elsif ($#flist == 0)
    {
      my $fname = $flist[0];
      chomp($fname);
      $files{$ext} = $fname;
      if ($ext eq "txt")
      {
        $fname =~ /(.*)\/(.*)txt/;
        $path = $1;
      }
    }
    elsif ($#flist >0)
    {
      my $f;
      chomp(@flist);
      my $ctr = 1;
      foreach $f (@flist)
      {
        my $key = $ext . $ctr;
        $files{$key} = $f; 
        $ctr++;
      }
    }
  } 
  return(\%files, $success);
}

sub calcIsolations
{
  my ($dbh, $us_fk, $oi_pk) = @_;
  
  my $sql = "select sample_type from sample, order_info, exp_condition where ec_fk = ec_pk and oi_fk = oi_pk and oi_pk = $oi_pk";
  my $sth = $dbh->prepare($sql) ;
  $sth->execute();
  
  my $isolations = 0;
  my $num_samples = 0;
  while (my ($smp_type) = $sth->fetchrow_array())
  {
    $isolations++ if ($smp_type ne "Total RNA");
    $num_samples++;
  }

  return ($isolations, $num_samples);
}

sub addHelp
{
  my $allhtml = shift;

  $allhtml =~ s!</title>!</title> <script src="utility.txt"></script> <script src="popup.txt"></script> <style> .popupLink { COLOR: black; outline: none } .popup { POSITION: absolute; VISIBILITY: hidden; BACKGROUND-COLOR: yellow; LAYER -BACKGROUND-COLOR: yellow; width: 200; BORDER-LEFT: 1px solid black; BORDER-TOP: 1px solid black; BORDER-BOTTOM: 3px solid black; BORDER-RIGHT: 3px solid black; PADDING: 3px; z-index: 10 } </STYLE>!; 
 return ($allhtml);
}

sub get_kv_num
{
  my $pk = shift;
  $pk =~ /!newkv_(\d+)$/;
  return $1;
}

sub drawExtractionInfo()
{
  my ($dbh, $htmlfile, $chref, $condsref, $us_fk, $debug) = @_;

  my %ch = %$chref;
  my @conditions = getDisplayInfo($dbh, $condsref);
  write_log("Conditions: @conditions");

  $ch{message} = get_message($ch{message});
  $ch{exp_select1_cond} = select_exp($dbh, $us_fk, "paste_ec_fk1", "loaded");
  $ch{exp_select1} = select_studies($dbh, $us_fk, "paste_std_fk1", "loaded");
  $ch{currConditions} = qq#<select name="currConds">#;
  foreach (@conditions)
  {
    my %c=%$_;
    my $cond = $c{label};
    $ch{currConditions}.=qq#<option name="$cond" value="$cond">$cond</option">#
  }
  $ch{currConditions} .= qq#</select>#;
  my $sth = getq("hybs_readable_plus", $dbh, $us_fk); # getq() is in sql_lib
  $sth->execute();
  my $e_hr;
  $ch{exclList} = "<select name=\"hybrids\" >\n";
  while($e_hr = $sth->fetchrow_hashref())
  {
    (my $data_count) = doq($dbh, "am_used_by_ams", $e_hr->{am_pk});
    if (! $data_count)
    {
      next;
    }
    my $name = $e_hr->{study_name} . " : " . 
      $e_hr->{smp_name} . " : " . $e_hr->{hybridization_name};
    my $value = $e_hr->{am_pk} . ":" . $e_hr->{hybridization_name};
    $ch{exclList} .= "<option value=\"$value\">$name</option>";
  }
  $ch{exclList} .= "</select>";

  (my $allhtml,my $loop_template) = readtemplate("$htmlfile", 
    "/site/webtools/header.html", "/site/webtools/footer.html"); 
  my $condhash ;
  while($condhash = pop(@conditions))
  {
    my $loop_instance = $loop_template; 
    my @val = @{$condhash->{hybrids}};
    my $label = $condhash->{label};
    my $notes = $condhash->{notes}; 
    $loop_instance = qq#<tr valign="top">#;
    $loop_instance .=qq#<a name="__$label">#;
    $loop_instance .= qq#Condition Label:# .
      qq# &nbsp; $label <br># .
      qq#Condition Notes: &nbsp; $notes <br># .
      qq#<input type="submit" name="delete_cond" # .
      qq#value="Remove $label Condition"><br># .
      qq#<br>Hybridizations include:  &nbsp; &nbsp; &nbsp; # ;
      # hybridization table
    $loop_instance .= qq#<table width="760" border="1" cellpadding=1 # ;
    $loop_instance .= qq# cellspacing="0"> <tr><th>&nbsp;</th><th># .
      qq#Sample Name</th><th>Internal Name # ;
    $loop_instance .= qq#</th><th>Layout</th><th>Hybridization Comments# .
      qq#</th><th>Owner # ;
    $loop_instance .= qq#</th></tr># ;
    foreach my $elem (@val)
    {
      my $int_name = $elem->{int_name};
      $loop_instance .= qq#<tr><td><input type="checkbox" # .
      qq# name="removehyb_$int_name" value="$int_name "></td>#;
      $loop_instance .= qq#<td># . $elem->{smp_name} . qq#</td># ;
      $loop_instance .= qq#<td># . $int_name . qq#</td># ;
      $loop_instance .= qq#<td># . $elem->{layout} . qq#</td># ;
      $loop_instance .= qq#<td># . $elem->{comments} . qq#</td># ;
      $loop_instance .= qq#<td># . $elem->{owner} . qq#</td></tr># ;
    }
    $loop_instance .= qq#</table># .
      qq#<input type="submit" name="delete_hyb_$label" # .
      qq#value="Remove Checked Hybridizations"><br></tr># ;
    $loop_instance .= qq#<table width="760" border="0" cellpadding=1 #.
      qq#cellspacing=0><tr bgcolor=# .
      "\"#2222FF\">" .
      qq#<td>&nbsp;</td><td>&nbsp;</td></tr></table>#;
    $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
  }
  #
  # We need to fix any checkboxes and select statements.
  # Both of these subs only fix matching form tags, and leave everything else
  # alone, so they should be safe to use on the entire completed web page.
  #
  foreach my $key (keys(%ch))
  {
    $allhtml = fixradiocheck($key, $ch{$key}, "checkbox", $allhtml);
    $allhtml = fixselect($key, $ch{$key}, $allhtml);
  }

  $allhtml =~ s/<loop_here>//;         # remove lingering template loop tag
  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

  $allhtml =~ s/{(.*?)}/$e_hr->{$1}$ch{$1}/g; 
  $allhtml =~ s/{debug}/$debug/;

  print "Content-type: text/html\n\n";
  print "$allhtml\n";
} # drawExtractionInfo

sub getDisplayInfo
{
  my ($dbh, $condsref) = @_;

  my $ctr = -1;
  my @new;
  foreach my $cond (@$condsref)
  {
    my %ec_cond;
    #get the notes for the experimental condition
    $ec_cond{label} = $cond->{label};
    $ec_cond{notes} = $cond->{notes}; 
    my $hyb;
    my @hybrids = ();
    foreach $hyb (@{$cond->{hybrids}})
    {
      $ctr++;
      #get the extra info to display
      my %elem;
      my $sth = getq("get_hyb_info_extract", $dbh);
      $sth->execute($hyb);
      my ($layout, $am_comments, $smp_name, $contact_lname, $contact_fname) =
        $sth->fetchrow_array();

      $elem{owner} = $contact_fname . " " . $contact_lname;
      $elem{smp_name} = $smp_name;
      $elem{layout} = $layout;
      $elem{comments} = $am_comments; 
      $elem{int_name} = $hyb;      
      push @hybrids, \%elem; 
    }  
    $ec_cond{hybrids} = \@hybrids; 
    push @new, \%ec_cond;
  } 
  return (@new);
}

sub getCondIdx
{
  my ($label, $condsref) = @_;
  my $idx = -1;
  
  foreach my $elem (@$condsref)
  {
    $idx++;
    return($idx) if ($elem->{label} eq $label);
  }
}

sub pasteExperiment
{
  my ($dbh, $us_fk, $condsref, $sty_pk) = @_;
  
  my $sth = getq("all_study_ec_pk", $dbh);
  $sth->execute($sty_pk);

  my $anchor;
  while ((my $ec_pk) = $sth->fetchrow_array())
  {
    $anchor = pasteCondition($dbh, $us_fk, $condsref, $ec_pk);
  }
  return($anchor);
} #pasteExperiment

sub pasteCondition
{
  my ($dbh, $us_fk, $condsref, $ec_pk) = @_;
  
  my %new;
  my @am_pks = ();
  my @hybs = ();
  
  # this returns name, am_pk, and hybridization_name
  my $sth = getq("hybs_readable_for_condition", $dbh, $us_fk); #args $ec_pk
  $sth->execute($ec_pk);

  my $e_hr;
  while($e_hr = $sth->fetchrow_hashref())
  {
    # don't add to the available list if data isn't loaded
    (my $data_count) = doq($dbh, "am_used_by_ams", $e_hr->{am_pk});
    next if (! $data_count);

    $new{sty_fk} = $e_hr->{sty_fk};
    $new{ec_pk} = $e_hr->{ec_pk};
    
    $new{notes}=$e_hr->{notes};
    $new{cond_name}=$e_hr->{name};
    $new{study_name}=$e_hr->{study_name};
    $new{label}= $e_hr->{study_name} . ":" . $e_hr->{name};
    push @am_pks, $e_hr->{am_pk};
    push @hybs, $e_hr->{hybridization_name};
  }
  $new{hybrids}=\@hybs;
  $new{am_pk} = \@am_pks;
  unshift @$condsref, \%new;
  write_log("Anchor is " . $new{label});
  return("#__" . $new{label});
} #pasteCondition

sub pasteHybrids
{
  my ($dbh, $us_fk, $condsref, $cond, $value) = @_; 

  my $ctr = -1;
  my $elem;
  my ($am_pk,$hybrid) = split(/:/,$value,2);
  foreach $elem (@$condsref)
  {
    $ctr++;
    if ($elem->{label} eq $cond)
    {
      write_log("Attempting to push $cond at $ctr");
      push @{$$condsref[$ctr]->{hybrids}}, $hybrid;
      push @{$$condsref[$ctr]->{am_pk}}, $am_pk;
    }
  }
  return("#__" . $cond);
} #pasteHybrids


sub build_ana_hash
{
  my ($dbh) = shift;
  my @conds = @_;
  my %result = ();
  my $elemref;

  foreach $elemref (@conds)
  {
    my $key = $elemref->{ec_pk};
    my @vals =  @{$elemref->{am_pk}};
    my @vals_loaded = ();

    if ($key > 0)
    {
      my $val;
      foreach $val (@vals)
      {
        # we can only analyze data that is loaded
        if (doq($dbh, "am_used_by_ams", $val))
        {
          push @vals_loaded, $val;
        }
      }
      if ($#vals_loaded >=0)
      {
        $result{$key} = \@vals_loaded;
      }
    }
  }
  return %result; 
}

sub write_data_file
{
  my ($dbh, $us_fk, $chref, $anaref, $file_name, $extract_type) = @_;
  my @am_pk_list;
  my %ch = %$chref;
  my %ana = %$anaref;
  
  # Build the ordered list of am_pk's
  # First cond label has no leading tween. See $cond_tween below.
  #
  # Rather than using an if ($first_iteration_flag) I just always
  # concat the tween, but the first time through the loop the tween
  # has been initialized to "". We aren't worried about speed too much, 
  # so I just re-assign the tween at the end of the loop every time.
  # Simpler.
  #
  my $al_pk;
  my $conds = "";
  my $cond_tween = ""; 
  my $curr_cond_count;
  my $cond_label1 = "";
  my $cond_label2 = "probe_set_name";
  my $sth = getq("get_abbrev_name", $dbh);
  my $cname_sth = getq("hyb_info", $dbh);
  foreach my $ec_pk (keys(%ana))
  {
    next if (! $ec_pk);
    $curr_cond_count = 0;
    $sth->execute($ec_pk);
    my @data = $sth->fetchrow_array();
    $sth->finish();
    if ($cond_label1 ne "")
    {
      $cond_label1 .= ",";
    }
    $cond_label1 .= "\"" . $data[0] . "\"";

    foreach my $am_pk (@{$ana{$ec_pk}})
    {
      next if (!$am_pk);
      $curr_cond_count++;
      push(@am_pk_list,$am_pk);
      $cname_sth->execute($am_pk);
      my $hr = $cname_sth->fetchrow_hashref();
      $cname_sth->finish();
      $cond_label2 .= "\t$hr->{hybridization_name}"; 
             
      if ($al_pk eq "")
      {
        $al_pk = $hr->{al_fk};
      }
      else
      {
        if ($hr->{al_fk} ne $al_pk)
        {
          set_session_val($dbh, $us_fk, "message", "warnmessage",
            get_message("WARN_LAYOUT_MISMATCH"));
        }
      }
    }
    $conds .= "$cond_tween$curr_cond_count";
    $cond_tween = ",";
  }
  # Firsts put spot_identifier into a hash keyed by als_pk.
  # We only have to do this once, since all the hybridizations must have 
  # the same array layout.
  #
  # Call a simple SQL query once for each am_pk, and put all the data
  # into the hash of strings using the als_fk as key.
  # The strings are spot identifier and tab separated signal values.
  #
  my %all_data;
  $sth = getq("get_spot_identifier", $dbh);
  $sth->execute($am_pk_list[0]); 
  while((my $als_pk, my $spot_identifier, my $usf_name) = 
    $sth->fetchrow_array())
  {
    $all_data{$als_pk} = "$spot_identifier | $usf_name";
  }
  $sth = getq("get_signal", $dbh);
  foreach my $am_pk (@am_pk_list)
  {
    next if (!$am_pk);
    # fetch data
    $sth->execute($am_pk);
    while((my $als_fk, my $signal) = $sth->fetchrow_array())
    {
      $all_data{$als_fk} .= "\t$signal";
    }
  }

  open(OUT, "> $file_name") || die "Can't open $file_name: $!\n";

  #
  # If export_format is human readable then write headers.
  # The alternative export_format is "geoss", but we don't need to 
  # check for that value, since there are only two possibilities.
  #
  # Then write data.
  #
  my $rec_count = 0;
  my $uai = 1;
  if ($extract_type =~ m/human/i)
  {
    $cond_label1 = $cond_label2; # set so we write to file_info below
    print OUT "$conds\n";
    $uai = 0;
  }

  # currently want to print out column headers
  # may change to write to db like conds
  print OUT "$cond_label2\n";
  foreach my $spot_identifier (keys(%all_data))
  {
    print OUT "$all_data{$spot_identifier}\n";
    $rec_count++;
  }
  close(OUT);
  chmod(0660, $file_name);

  my $fi_pk = fi_update($dbh, $us_fk, $us_fk, $file_name, $ch{comments},
    $conds, $cond_label1,
    undef,            # not associated with a node
    $uai,             # this can be an input file
    undef,            # ft_fk
    288,              # permissions
    $al_pk);         
  return ($rec_count, $fi_pk);
}

sub extractFile
{
  my ($dbh, $us_fk, $chref, $condsref, $extract_type, $child) = @_;
  my %ana = build_ana_hash($dbh, @$condsref);

  my ($recs, $fi_pk) = write_data_file($dbh, $us_fk, $chref, \%ana,
      $chref->{file_name}, $extract_type, $child);

  if ($extract_type =~ /human/)
  {
    $chref->{records} = $recs;
    $chref->{htmltitle} = "MAS5 hybridization data export";
    $chref->{htmldescription} = "";
    my $allhtml = get_allhtml($dbh, $us_fk, "get_data2.html", 
        "/site/webtools/header.html", "/site/webtools/footer.html", $chref);
    print "Content-type: text/html\n\n$allhtml";
  }
  return($fi_pk);
} #extractFile

sub s3Kur3_raNd0m
{
  my $len = shift;
  my $binary_blob;
  $len > 0 or die "precondition failed: len > 0, login.cgi";

  my $fh = new IO::File('/dev/random');
  $fh->sysread($binary_blob, $len);

  # We chomp because encode_base64 adds a trailing newline (appropriate for
  # mime messages, but unnecessary here.
  my $base64_blob;
  chomp($base64_blob = encode_base64($binary_blob));
  $fh->close();
  return $base64_blob;
}


sub rm_inactive_users
{
  my ($dbh, $us_fk, $chref) = @_;

  my $type = "all"; 
  my $deleted = "";
  my $not_deleted = "";
  $type = $chref->{type} if (exists $chref->{type});

  #select inactive users (NULL last login)
  my $sth = getq("get_inactive_users", $dbh, $type);
  $sth->execute();

  while (my($inactive_us_pk, $login, $age) = $sth->fetchrow_array())
  {
    #if has been more than "days_to_confirm" days since last_updated,
    # attempt to delete the user.
     my $days = 0;
     $days = $1 if ($age =~ /(\d+) days/);
     
     # small potential for a problem here.  If days to confirm is set 
     # to 30 and a user creates an account in Feb (28 days), the 
     # sql age command might return that a month has passed after
     # 28 days.  However, the user would have had to wait till the 
     # last day to confirm the account for this to show up.  Rather
     # than spend time coding around this, I'm just going to assume
     # they can create another account if they need to.
     if (($days > get_config_entry($dbh, "days_to_confirm")) ||
         ($age =~ /month/) || ($age =~ /year/))
     {
       # user has been inactive too long.  We will try to remove.
       my $remove = remove_user_generic($dbh, $us_fk, $login);
       if ($remove eq "true")
       {
          $deleted .= "$login\n";     
       }
       else
       {
         $not_deleted .= "$login\n";
       } 
     }
  }
  if ($deleted ne "")
  {
     $deleted = "The following users were deleted:\n" . $deleted;
  }
  if ($not_deleted ne "")
  {
    $not_deleted = "The following users are inactive, but could not be " .
      "deleted as they are in use: \n" . $not_deleted;
  }

  # return a string of deleted users
  if (($deleted ne "") || ($not_deleted ne ""))
  {
    return($deleted . "\n" . $not_deleted);
  }
  else
  {
   return("There were no inactive users to delete.\n");
  }
}

sub remove_org_generic
{
  my ($dbh, $us_fk, $org) = @_;

  my $sth;
  my $success = "true";

  my $sql = "select org_fk from org_usersec_link, organization where " .
    "org_pk=org_fk and org_name ='$org'";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my ($fk) = $sth->fetchrow_array())
  { 
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DELETE_SPECIAL_CENTER_HAS_MEMBERS");
  } 
  
  if ($success eq "true")
  { 
   $sql = "delete from organization where org_name = '$org'";
   $dbh->do($sql);
  }
  $dbh->commit();
  return($success);  
}  

sub remove_user_generic
{
  my ($dbh, $us_fk, $login) = @_;

  my $sth;
  my $success = "true";

  my $sql = "select us_pk,con_fk from usersec where login='$login'";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  my ($rm_us_fk, $con_fk) = $sth->fetchrow_array();
  $sth->finish();

  # the user is not allowed to remove themself
  if ($us_fk == $rm_us_fk)
  {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DELETE_SELF","$login");
  }

  # if the user is a pi for anyone other than themself, they cannot be
  # removed
  $sql = "select * from pi_sec where pi_key='$rm_us_fk'";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my ($u, $p) = $sth->fetchrow_array())
  {
    if ($u != $p)
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DELETE_USER_IS_PI","$login");
    }
  }

  # if the user is a pi for anyone other than themself, they cannot be
  # removed
  $sql = "select us_fk from groupref where us_fk='$rm_us_fk'";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  while (my ($u) = $sth->fetchrow_array())
  { 
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DELETE_USER_OWNS_DATA","$login");
  } 
  
  if ($success eq "true")
  { 
   # remove the user from pi_sec 
   $sql = "delete from pi_sec where us_fk = '$rm_us_fk'";
   $dbh->do($sql);
  
   # remove the user from all groups
   $sql = "delete from grouplink where us_fk = '$rm_us_fk'"; 
   $dbh->do($sql);

   # remove all others from users group
   $sql = "delete from grouplink where gs_fk = '$rm_us_fk'";
   $dbh->do($sql);

   # remove all of the user's groups
   $sql = "delete from groupsec where gs_owner='$rm_us_fk'";
   $dbh->do($sql);

   # remove usersec
   $sql = "delete from usersec where login='$login'";
   $dbh->do($sql);

   #remove the users contact information
   $sql = "delete from contact where con_pk = '$con_fk'";
   $dbh->do($sql);


   # remove the user's directory
   `rm -rf $USER_DATA_DIR/$login`
   
  }
  $dbh->commit();
  return($success);  
}  

sub create_org_generic
{
  my ($dbh, $us_fk, $chref) = @_;

  my $sql;
  my %ch=%$chref;
  my $success = "true";

  # check if the organization name is NULL
  if ($ch{org_name} eq "")
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "FIELD_MANDATORY", "Special Center Name");
  }
   
  # check if the organizatin name is already in use
  my $sth = getq("select_organization_by_name", $dbh, $ch{org_name});
  $sth->execute();
  my $hr;
  while ($hr = $sth->fetchrow_hashref())
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
      "FIELD_MUST_BE_UNIQUE","$ch{org_name}");
  }
  $sth->finish();

  if (exists($ch{display_logo}))
  {
    $ch{display_logo} = 't';
  }
  else
  {
    $ch{display_logo} = 'f';
  }

  if (exists($ch{needs_approval}))
  {
    $ch{needs_approval} = 't';
  }
  else
  {
    $ch{needs_approval} = 'f';
  }

  $ch{logo_fi_fk} = 'NULL' if (! $ch{logo_fi_fk});
  $ch{icon_fi_fk} = 'NULL' if (! $ch{icon_fi_fk});
  $ch{logo_fi_fk} = 'NULL' if ($ch{logo_fi_fk} eq 'None');
  $ch{icon_fi_fk} = 'NULL' if ($ch{icon_fi_fk} eq 'None');

  if ($success eq "true")
  { 
    # insert the organization
    doq_insert_org($dbh, \%ch);
   
  }
  $dbh->commit();
  return($success);  
}  

sub edit_org_mem_generic
{
  my ($dbh, $us_fk, $chref) = @_;

  my $sql;
  my $sth;
  my %ch=%$chref;
  my $success = "";
  my $org = $chref->{org_pk};

  # chref contains users to be added and removed
  # an added user will look like add_#, where # is the us_pk
  # a removed user will look like rm_#, where # is the us_pk
  my $curkey="rm_" . $us_fk;
  if (exists ($chref->{$curkey}))
  {
    $success .= set_session_val_or_str($dbh, $us_fk, "message",
      "errmessage", "ERROR_DELETE_SELF");
  }
  else
  {
    my $key;
    foreach $key (keys(%$chref))
    {
      if ($key =~ /(add)_(\d+)/ )
      {
        my $curkey = "cur_$2";
        if (! exists ($chref->{$curkey}))
        {
          doq_insert_org_usersec_link($dbh, {"org_fk",$org, "us_fk",$2,
            "curator",'f'});
        }
      }
      if ($key =~ /(cur)_(\d+)/ )
      {
        doq_insert_org_usersec_link($dbh, {"org_fk",$org, "us_fk",$2,
          "curator",'t'});
      }
      if ($key =~ /rm_(\d+)/)
      {
        doq_rm_org_usersec_link($dbh, {"org_fk", $org, "us_fk", $1} );
      }
    }
    $success = "true";
  }
  $dbh->commit();
  return($success);  
}  

sub edit_org_generic
{
  my ($dbh, $us_fk, $chref) = @_;

  my $sql;
  my %ch=%$chref;
  my $success = "true";

  if (exists($ch{needs_approval}))
  {
    $ch{needs_approval} = 't';
  }
  else
  {
    $ch{needs_approval} = 'f';
  }

  my $sth = getq("select_organization", $dbh, $ch{org_pk});
  $sth->execute();

  my ($org) = $sth->fetchrow_hashref();
  my $org_name = $org->{org_name};
  make_logo_icon_avail($dbh, $us_fk, $org_name, \%ch);

  if ($success eq "true")
  { 
    # edit the organization
    doq_edit_org($dbh, \%ch);
  }
  $dbh->commit();
  return($success);  
}  

# move the assigned logo & icon
sub make_logo_icon_avail
{
  my ($dbh, $us_fk, $org_name, $chref) = @_;
  my %ch = %$chref;    
  unless (-e "$WEB_DIR/site/logos")
  {
    mkdir "$WEB_DIR/site/logos", 0755 ||
    warn "Unable to make $WEB_DIR/site/logos: $!";
  }
  unless (-e "$WEB_DIR/site/logos/$org_name")
  {
    mkdir "$WEB_DIR/site/logos/$org_name", 0755 
      || warn "Unable to make $WEB_DIR/site/logos/$org_name: $!";       
  }
  unless (-e "$WEB_DIR/site/icons")
  {
    mkdir "$WEB_DIR/site/icons", 0755 ||
    warn "Unable to make $WEB_DIR/site/icons: $!";
  }
  unless (-e "$WEB_DIR/site/icons/$org_name")
  {
    mkdir "$WEB_DIR/site/icons/$org_name", 0755 
      || warn "Unable to make $WEB_DIR/site/icons/$org_name";;     
  }
  
  # remove files currently in the logo/icon directory
  foreach (glob("$WEB_DIR/logos/$org_name/*"), 
           glob("$WEB_DIR/icons/$org_name/*"))
  {
    unlink $_ || warn "Couldn't remove $_: $!";
  }

  # copy over the files to directory they can be served from
  if (($ch{logo_fi_fk} ne "None") && (exists($ch{logo_fi_fk})))
  {
    my ($src) = doq($dbh, "get_file_name", $ch{logo_fi_fk});
    $src =~ /.*\/(.*)/;
    my $dest = "$WEB_DIR/site/logos/$org_name/$1";
    copy($src, $dest);
  }
  else
  {
    $ch{logo_fi_fk} = 'NULL';
  }
  if (($ch{icon_fi_fk} ne "None") && (exists($ch{icon_fi_fk})))
  {
    my ($src) = doq($dbh, "get_file_name", $ch{icon_fi_fk});
    $src =~ /.*\/(.*)/;
    my $dest = "$WEB_DIR/site/logos/$org_name/$1";
    copy($src, $dest);
  }
  else
  {
    $ch{icon_fi_fk} = 'NULL';
  } 
}

sub user_list
{
  my $dbh = $_[0];

  my $sth = getq("user_list", $dbh);
  $sth->execute();

  my $fname;
  my $lname,
  my $con_pk;
  my $select = "<select name=\"esp_info\">\n";
  while(($con_pk, $fname, $lname) = $sth->fetchrow_array())
  {
    # $se_hash{"$fname $lname"} = $con_pk;
    $lname =~ s/\,/ /g; # can't allow comma in names
    $fname =~ s/\,/ /g;
    $select.= "<option value=\"$con_pk,$lname,$fname\">$lname, $fname" .
      "</option>\n";
  }
  $select .= "</select>\n";
  return $select;
}

sub draw_insert_tree
{
  my ($dbh, $us_fk, $chref) = @_;
  my %ch = %$chref;

  %ch = radio_source(\%ch);
  $ch{htmltitle} = "Create New Analysis Tree";
  $ch{help} = set_help_url($dbh, "analysis_management",
      "create_or_run_a_new_analysis_tree");
  # currently only Quality Control is valid first input
  # if we add another good first input, we'll need this
  # $ch{select_initial_node} = select_node($dbh, $us_fk, "");

  my $allhtml = get_allhtml($dbh, $us_fk, "insert_tree.html",
     "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
  $allhtml = fixselect("structure", $ch{structure}, $allhtml);
  $allhtml =~ s/{(.*)}/$ch{$1}/g;
  print "Content-type: text/html\n\n$allhtml";
}

sub draw_insert_order_curator1
{
  my ($dbh, $us_fk, $chref) = @_;
  my %ch = %$chref;

  $ch{user_list} = user_list($dbh);
  $ch{select_org} = select_org($dbh);

  $ch{htmltitle} = "Array Order Creation";
  $ch{help} = set_help_url($dbh, "create_a_new_array_order");

  my $allhtml = get_allhtml($dbh, $us_fk, "insert_order_curator1.html",
     "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
  print "Content-type: text/html\n\n$allhtml";
}

sub draw_insert_miame
{
  my ($dbh, $us_fk, $chref) = @_;
  my %ch = %$chref;

  $ch{exp_select1} = select_studies($dbh, $us_fk, "sty_fk");
  $ch{exp_type_select} = select_exp_types($dbh, $us_fk, "miame_type_fk");
  $ch{user_pi} = user_pi();


  $ch{htmltitle} = "Create MIAME Information";
  $ch{htmldescription} = "You may choose to make your study information " .
    "and data publically available.  If you wish to do this, complete " .
    "the following form once your study is complete.  The form acquires " .
    "additional information about your study, so that the published " .
    "information adheres to MIAME ( <a href=\"http://www.mged.org/miame\">" .
    "Minimum Information About a Microarray Experiment</a>) guidelines.  " .
    "The additional information will assist others in understanding your " .
    "data correctly.";

  my $allhtml = get_allhtml($dbh, $us_fk, "insert_miame1.html",
      "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
  $allhtml = fixselect("sty_fk", $ch{sty_fk}, $allhtml);
  $allhtml = fixselect("pi_info", $ch{pi_info}, $allhtml);
  $allhtml = fixselect("miame_type_fk", $ch{miame_type_fk}, $allhtml);
  $allhtml = addHelp($allhtml);

  print "Content-type: text/html\n\n";
  print "$allhtml\n";
}

sub draw_edit_org
{
  my ($dbh, $us_fk, $org_pk) = @_;
  my $co=new CGI;

  my $sth = getq("select_organization", $dbh, $org_pk);
  $sth->execute();
  my $hr;
  $hr = $sth->fetchrow_hashref();
  $sth->finish();

  my $headerfile = "/site/webtools/header.html";
  my $footerfile = "/site/webtools/footer.html";
  my $allhtml = readfile("org_editorg.html", "$headerfile", "$footerfile");
  $hr->{htmltitle} = "Edit your special center";
  $hr->{help} = set_help_url($dbh, "edit_special_center_information");
  $hr->{htmldescription} = "This page can be used to edit a special center.";
  $hr->{select_logo} = select_fi_fk($dbh, $us_fk, "logo");
  $hr->{select_icon} = select_fi_fk($dbh, $us_fk, "icon");

  my %ch = %{get_all_subs_vals($dbh, $us_fk, $hr)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  $allhtml = fixselect("logo_fi_fk", $hr->{logo_fi_fk}, $allhtml);
  $allhtml = fixselect("icon_fi_fk", $hr->{icon_fi_fk}, $allhtml);
  $allhtml = fixradiocheck("needs_approval",
    $hr->{needs_approval}, "checkbox", $allhtml);
  print $co->header;
  print "$allhtml\n";
  print $co->end_html;

  $dbh->disconnect();
  exit();
}

sub select_fi_fk
{
  my ($dbh, $us_fk, $type) = @_;
  my $count = 0;
    
  my $q_name = "select_" . $type;
  my $fieldname = $type . "_fi_fk";
  my $sth = getq($q_name, $dbh, $us_fk);
  $sth->execute();
  my $sel = "<select name=\"$fieldname\">\n";
  $sel .= "<option value=\"None\">None</option>\n"
    if ($type eq "icon") || ($type eq "logo");
  while((my $fi_pk, my $filename) = $sth->fetchrow_array())
  {
    $filename =~ /(.*)Upload\/$type\/(.*)/;
    $sel .= "<option value=\"$fi_pk\">$2</option>\n";
    $count++;
  }
  $sel .= "</select>\n";
  $sel = "You must upload a file of type $type in file upload before you"
    . " can assign it." if ($count == 0);
  return $sel;
}

sub draw_edit_mem
{
  my ($dbh, $us_fk, $org_pk) = @_;
  my $co=new CGI;

  my $headerfile = "/site/webtools/header.html";
  my $footerfile = "/site/webtools/footer.html";
  my ($allhtml, $loop_template, $loop_tween, $loop_template2) = 
    readtemplate("org_edit_mem.html", "$headerfile", "$footerfile");

  my $sth = getq("get_users_by_org", $dbh, $org_pk);
  $sth->execute();
  my $hr;
  while ($hr = $sth->fetchrow_hashref())
  {
    $hr->{name} =  $hr->{contact_fname} . " " . $hr->{contact_lname};
    $hr->{curator} = "No" if ($hr->{curator} == 0);
    $hr->{curator} = "Yes" if ($hr->{curator} == 1);
    my $loop_instance = $loop_template;
    $loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
    $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
  }
  $allhtml =~ s/<loop_here>//; 

  $sth = getq("get_not_users_by_org", $dbh, $org_pk);
  $sth->execute();
  while ($hr = $sth->fetchrow_hashref())
  {
    $hr->{name} =  $hr->{contact_fname} . " " . $hr->{contact_lname};
    my $loop_instance = $loop_template2;
    $loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
    $allhtml =~ s/<loop_here2>/$loop_instance\n<loop_here2>/;
  }
  $allhtml =~ s/<loop_here2>//; 

  $hr->{htmltitle} = "Modify special center members";
  $hr->{help} = set_help_url($dbh, "edit_special_center_members");
  $hr->{htmldescription} = "This page can be used to add and remove members
    to/from your special center.";

  my %ch = %{get_all_subs_vals($dbh, $us_fk, $hr)};
  $ch{org_pk} = $org_pk;
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  print $co->header;
  print "$allhtml\n";
  print $co->end_html;

  $dbh->disconnect();
  exit();
}

sub get_num_conds_in_study
{
  my ($dbh, $sty_pk) = @_;

  my $sql = 
    "select count(*) from study, exp_condition where sty_fk = sty_pk and". 
    " sty_pk=$sty_pk";
  my ($count) = $dbh->selectrow_array($sql);
  return($count);
}

sub get_study_status
{
  my ($dbh, $us_fk, $sty_pk, $save_msg) = @_;
  my $status = "COMPLETE";
  my $q_name = "get_study_status";

  my $sql = "select ec_pk, name, abbrev_name, sample_type from " .
    "exp_condition where sty_fk = $sty_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute(); 

  my $hr;
  my $num_ec = 0;
  while ($hr = $sth->fetchrow_hashref())
  {
    $num_ec++;
    if (is_invalid_ec($dbh, $us_fk, $hr, $save_msg))
    {
      $status = "INCOMPLETE";
    }
  }
  $status = "INCOMPLETE" if ($num_ec ==0);
  
  if (is_study_loaded($dbh, $us_fk, $sty_pk))
  {
    $status = "LOADED";
  }
  
# $status = "PUBLISHED";
  return ($status);
}

sub is_invalid_ec
{
  my ($dbh, $us_fk, $ec_ref, $set_message) = @_;
  my %ec = %$ec_ref;
  my $msg;

  my $len = length($ec{abbrev_name});
  $msg = get_message("FIELD_MANDATORY", "Experimental Condition Name")
    if (length($ec{name}) == 0); 
  $msg = get_message("ERROR_SHORT_NAME_TOO_LONG") if ($len > 6);
  $msg = get_message("FIELD_MANDATORY", "Short Name") if ($len < 1);
  $msg = get_message("ERROR_SHORT_NAME_INVALID_CHARACTERS") 
    if ($ec{abbrev_name} =~ m/[^A-Za-z0-9]/ );
 
  if (($set_message) && ($msg))
  {
    set_session_val($dbh, $us_fk, "message", "errmessage", $msg);
  }
  return ($msg)
}

sub select_order_status
{
  my ($dbh, $field_name) = @_;
  $field_name = "select_order_status" if (!$field_name);
  
  my $html = "<select name=\"$field_name\">
                <option value=\"INCOMPLETE\">INCOMPLETE</option>
                <option value=\"COMPLETE\">COMPLETE</option>
                <option value=\"SUBMITTED\">SUBMITTED</option>
                <option value=\"APPROVED\">APPROVED</option>
                <option value=\"LOADED\">LOADED</option>
             </select>\n";
  return($html);
}

#
# if you add a status to this, make sure to update select_order_status
sub get_order_status
{
  my ($dbh, $us_fk, $oi_pk, $save_msg) = @_;
  my $status = "INCOMPLETE";

  if (verify_order_completeness($dbh, $us_fk, $oi_pk))
  {
    $status = "COMPLETE";
  }
  else
  {
    get_stored_messages($dbh, $us_fk) unless ($save_msg);
  }
  my $sql = "select * from order_info where oi_pk=$oi_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my $o_hr;
  $o_hr = $sth->fetchrow_hashref();

  if ($o_hr->{locked} == 1)
  {
    $status = "SUBMITTED";
  }
  if ($o_hr->{is_approved} == 1)
  {
    $status = "APPROVED";
  }
  $sql = "select date_loaded from order_info,sample,arraymeasurement 
    where oi_pk=$oi_pk and oi_pk=oi_fk and smp_pk = smp_fk";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  my $finished = 2;
  while ($o_hr = $sth->fetchrow_hashref())
  {
    $finished = 1 if ($finished == 2);
    $finished = 0 if (!$o_hr->{date_loaded});
  }

  if ($finished == 1)
  {
    $status = "LOADED";
  }

  return ($status);
}

sub get_study_info
{
  my ($dbh, $us_fk, $sty_pk) = @_;
  
  my $sth=getq("study_info_by_sty_pk", $dbh);
  $sth->execute($sty_pk);
  my $study_info = $sth->fetchrow_hashref(); 
  $sth->finish();

  ($study_info->{pi_us_fk}, $study_info->{pi_group_fk}, undef, undef) = 
    doq($dbh, "who_owns", $sty_pk);
  ($study_info->{pi_name}, $study_info->{pi_group}) = 
    doq($dbh, "get_study_info", $us_fk, $sty_pk);
  $sth=getq("get_exp_cond", $dbh, $us_fk);
  $sth->execute($sty_pk);
  my @ec;
  $study_info->{number_of_conditions} = 0;
  my $hr;
  while ($hr = $sth->fetchrow_hashref())
  {
    $study_info->{number_of_conditions}++;
    push @ec, $hr;
  }
  $study_info->{exp_conds} = \@ec; 
  $study_info->{status} = get_study_status($dbh, $us_fk, $sty_pk);
  $study_info->{classification} = getq_dis_fk_by_sty_fk($sty_pk); 
  return($study_info); 
}


sub get_order_info
{
  my ($dbh, $us_fk, $oi_pk) = @_;

  my $sth=getq("order_info_by_oi_pk", $dbh);
  $sth->execute($oi_pk);
  my $order_info = $sth->fetchrow_hashref(); 
  $sth->finish();
  (undef, $order_info->{pi_name}, $order_info->{pi_group}) = 
    doq($dbh, "get_order_info", $us_fk, $oi_pk);
  $sth = getq("get_billing_code", $dbh);
  $sth->execute($oi_pk);
  $order_info->{billing_code} = $sth->fetchrow_array();
  $order_info->{billing_code} = "" 
    if (! defined $order_info->{billing_code}); # silences warning
                        
  $order_info->{org_name} = get_order_org_name($dbh, $us_fk, $oi_pk);

  return($order_info); 
}

sub get_order_org_name
{
  my ($dbh, $us_fk, $oi_pk) = @_;
  
  my ($org_name) = $dbh->selectrow_array("select org_name from order_info, 
   organization where org_fk = org_pk and oi_pk=$oi_pk");

  $org_name = "None" if (! $org_name); 
  return ($org_name);
}

sub upload_file
{
  my ($dbh, $us_fk, $chref, $q) = @_;
  my %ch = %$chref;
  my $success = 1;
  my $fi_pk;
  my $replace;
  $ch{file_name} = $q->param('filedata') if (! $ch{file_name});

  # uploading files from a windows machime includes backslashes which we don't
  # want
  if ($ch{file_name} =~ /.*\\(.*)/)
  {
    $ch{file_name} = $1;
  }
  
  my $login = doq($dbh, "get_login", $us_fk);
  my ($allhtml) = readfile("../webtools/get_data3.html",
      "/site/webtools/header.html", "/site/webtools/footer.html");
  my $conds = "";
  my $cond_labels = "";
  my $uai = 0;
  my $ft_fk = undef; 
  my $al_fk = undef;
  if ($ch{filetype} eq "analysis_input")
  {
    $al_fk = 0;
    $conds = $ch{conds};
    $cond_labels = $ch{cond_labels};
    $uai = 1;
    $al_fk = $ch{al_fk} if ($ch{al_fk});
  }
  
  my $full_file_name = "$USER_DATA_DIR/$login/Upload/" 
    . $ch{filetype} . "/" . $ch{file_name};
  mkdir "$USER_DATA_DIR/$login/Upload", 0770 
    unless -e "$USER_DATA_DIR/$login/Upload";
  mkdir "$USER_DATA_DIR/$login/Upload/$ch{filetype}", 0770 
    unless -e "$USER_DATA_DIR/$login/Upload/$ch{filetype}";
  if (-e $full_file_name)
  {
    $success = 0;
    warn "File exists $full_file_name";
    set_session_val($dbh, $us_fk, "message", "errmessage",
      get_message("ERROR_FILE_EXISTS"));
  }
  else
  {
    $fi_pk = write_upload_file($dbh, $us_fk, $q->param("filedata"),
       $us_fk, $us_fk, $full_file_name, $ch{comments},$conds,
       $cond_labels, undef, $uai, $ft_fk, 432, $al_fk); 
        
    if ($ch{filetype} eq "mas5")
    {
      $success = load_upload_mas5_data($dbh, $us_fk, $fi_pk, \%ch);
      # success is 1 if all went well
    }
    elsif ($ch{filetype} eq "criteria")
    {
      $ch{add_info} = qq#<p>To create analysis conditions using the uploaded
      criteria file, click <a href="create_an_cond.cgi">here</a>.#;
      if (verify_criteria_file($dbh, $us_fk, $fi_pk) eq "true")
      {
        create_automatic_components($dbh, $us_fk, $fi_pk, \%ch);
      }
      else
      {
        $success = 0;
      }
    }
    elsif ($ch{filetype} eq "cDNA")
    {
      warn "cDNA upload not fully supported yet\n"; 
    }
    if ($success == 1)
    {
      %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
      $allhtml =~ s/{(.*?)}/$ch{$1}/g;
      print "Content-type: text/html\n\n$allhtml\n";
      exit;
    }
    else
    {
       delete_file($dbh, $fi_pk);
    }
  }
  if ($success == 0)
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
         "ERROR_LOAD");
    my $url = index_url($dbh);
    print "Location: $url\n\n";
  }
}

sub write_upload_file
{
   my ($dbh, $us_fk, $upfh, $owner_pk, $group_pk, $full_file_name, 
       $fi_comments, $conds, $cond_labels, $node_fk, $uai, $ft_fk,
       $permissions, $al_fk) = @_;

   open(OUT, "> $full_file_name") || die "Can't open $full_file_name: $!\n";
   my $bytesread; my $buffer;
   while( $bytesread =read($upfh,$buffer,1024)) 
   {
      print OUT $buffer;
   }
   close(OUT);
   chmod(0660, $full_file_name);

   if ($full_file_name =~ /(.*)\.zip$/)
   {
     system('unzip', $full_file_name);
     $full_file_name = $1;
   }

   if ($full_file_name =~ /(.*)\.tar(\.gz)?$/) {
      system('tar', '-x', ($2 ? '-z' : ()), '-f', $full_file_name )
      and die "tar returned failure: $?";
      $full_file_name = $1;
    }
  my $fi_pk = fi_update($dbh, $owner_pk, $group_pk, $full_file_name,
     $fi_comments, $conds, $cond_labels, $node_fk, $uai, $ft_fk,     
     $permissions, $al_fk); 
   return ($fi_pk);
}

sub check_duplicate_hyb_name
{
  my ($dbh, $us_fk, $hyb_name) = @_;
  my $sth = getq("unique_hyb", $dbh, $hyb_name);
  $sth->execute();
  my ($count) = $sth->fetchrow_array();
  
  return ($count);
}

sub define_filetype_default
{
  my %filetypes = (
        "logo" =>
          {
            "file" => "../webtools/upl_file.html",
            "help" => "upload_logo_or_icon_file",
            "description" => "Specify the logo file you are uploading.",
          },
        "icon" =>
          {
            "file" => "../webtools/upl_file.html",
            "help" => "upload_logo_or_icon_file",
            "description" => "Specify the icon file you are uploading. "
              . "Note that while you can upload icon files, they are not " .
              "yet used by the system.",
          },
        "mas5" =>
          {
            "file" => "upl_mas5.html",
            "help" => "upload_mas5_data_file",
            "description" => "First, provide a unique name for the " .
               " hybridization data you are loading.  Then indicate the " .
               " chip type associated with the data.  Finally, specify " .
               " the data file you are uploading.",
          },
        "criteria" =>
          {
            "file" => "upl_file.html",
            "help" => "upload_criteria_file",
            "description" => "Specify the criteria file you are uploading. "
              . "Note that the criteria file has a specialized format.  See " .
              "help for more information.", 
          },
        "analysis_input" => 
          {
            "file" =>  "upl_ana_in.html",
            "help" =>  "upload_analysis_input_file", 
            "description" => "Provide the condition grouping and the " . 
              "condition labels in the specified fields.  Then, specify " .
              "the data file you are uploading.  Note that analysis " .
              "input files have a specialized format.  See help " .
              "for more information.",
          },
        "data" =>
          {
            "file" => "upl_file.html",
            "help" => "upload_data_file",,
            "description" => "Specify the file you are uploading.  Data " .
              "files may be an individual text file that contains signal " .
              "data for multiple chips or a tar/zip file that contains " .
              "multiple chip data files of type txt, chp, dat, rpt, dtt, " .
              " & cab.  See help for more information.",
          },
        "other" =>
          {
            "file" => "upl_file.html",
            "help" => "upload_other_file",,
            "description" => "Specify the file you are uploading.",
          },
  );
  return(%filetypes);
}

sub drawUploadInfo
{
  my ($dbh, $us_fk, $chref) = @_;
  my %ch = %$chref;
  my $filename;
  my %filetypes = define_filetype_default();
  if (exists $ch{filetype})
  {
    my $info = $filetypes{$ch{filetype}};
    $filename = $info->{file};
    $ch{htmldescription} = $info->{description};
    $ch{help} = set_help_url($dbh, $info->{help});
  }
  else
  {
    $filename = "upl_filetype.html";
    $ch{help} = set_help_url($dbh, $ch{helplink} || "upload_a_file");
    $ch{htmldescription} = "This page initiates uploading a data file.  " .
      "Select the type of file you are uploading.  For more information " .
      "on the expected file format, click on the link associated with " .
      "the file type you wish to upload.";
  }

  $ch{htmltitle} = "File Upload";
  $ch{message} = get_message($ch{message});

  my ($allhtml) = readtemplate("$filename","/site/webtools/header.html", 
      "/site/webtools/footer.html"); 

  $ch{select_arraylayout}=build_al_select($dbh) 
  if (($ch{filetype} eq "mas5") || ($ch{filetype} eq "analysis_input"));
  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  $allhtml = fixradiocheck("filetype", $ch{filetype}, "radio", $allhtml)
  if (! $ch{filetype});
  $allhtml = fixselect("al_fk", $ch{al_fk}, $allhtml) 
  if ($ch{filetype} eq "mas5");
  print "Content-type: text/html\n\n$allhtml\n";
} # drawUploadInfo

sub draw_org_approve
{
  my ($dbh, $us_fk, $chref) = @_;
  my %ch=%$chref;
  #
  # readtemplate() is in session_lib
  #
  (my $allhtml, my $loop_template, my $tween, my $loop_template2) = 
    readtemplate("org_approve.html", "/site/webtools/header.html", 
      "/site/webtools/footer.html"); 

  my $recordlist = makelist_org_approve($dbh, $us_fk, $loop_template, 
    $loop_template2, $ch{org_pk}, $ch{order_number});
  $allhtml =~ s/<loop_here>/$recordlist/sg;

  $ch{htmltitle} = "Approve Order";
  $ch{help} = set_help_url($dbh, "special_center_management");
  $ch{htmldescription} = "This page can be used to approve orders.";
  $ch{msg_color} = "";
  %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

  $allhtml =~ s/{(.*?)}/$ch{$1}/g;
  print "Content-type: text/html\n\n";
  print "$allhtml\n";
    
  $dbh->disconnect;
  exit(0);
}

sub makelist_org_approve
{
  my ($dbh, $us_fk, $loop_template, $loop_template2, $org_fk, $ord_num) = @_;
    
  # sql statements
  my $sql = "select * from order_info where ";
  if (defined $org_fk)
  {
    $sql .= " org_fk = $org_fk";
  }
  if (defined $ord_num)
  {
    $sql .= " order_number = '$ord_num'";
  }
  $sql .= " order by oi_pk desc";
  my $billing_sql =  "select billing_code from billing where oi_fk=?";
  my $sample_sql =   "select timestamp, exp_condition.name as ec_name, 
    abbrev_name, study.study_name, study.sty_pk from sample,exp_condition,
    study where study.sty_pk=exp_condition.sty_fk and exp_condition.ec_pk=
    sample.ec_fk and smp_pk=?";
    my $sc_sql = "select count(smp_pk) from sample where oi_fk=?";
    my $am_sql = "select hybridization_name,smp_pk,am_pk,al_fk,qc_fk 
      from arraymeasurement,sample,order_info where oi_pk=? and 
      order_info.oi_pk=sample.oi_fk and arraymeasurement.smp_fk=
      sample.smp_pk order by smp_pk,am_pk";
    my $al_sql = "select arraylayout.name as al_name from arraylayout 
      where al_pk=?";

    # sth vars
    my $sth =  $dbh->prepare($sql);
    my $billing_sth =  $dbh->prepare($billing_sql);
    my $sample_sth =  $dbh->prepare($sample_sql);
    my $sc_sth =      $dbh->prepare($sc_sql);
    my $owner_sth =   getq("order_owner_info", $dbh);
    my $am_sth =      $dbh->prepare($am_sql);
    my $al_sth =      $dbh->prepare($al_sql);

    my $reclist;
    #
    # Put all necessary data in to the $rec hash, and just loop through
    # the keys substituting into the HTML template.
    # This assumes that field names, and anything added to the $rec hash
    # is unique!
    # 
    $sth->execute();
    my $o_hr; # order_info hash ref
    while($o_hr = $sth->fetchrow_hashref())
    {
      my $sth = getq("select_sample_by_oi_fk", $dbh);
      $sth->execute($o_hr->{oi_pk});
      my $smps;
      my $x;

      while ($x = $sth->fetchrow_array())
      {
        $smps .= "$x,";
      }
      chop($smps);

      $billing_sth->execute($o_hr->{oi_pk});
      ($o_hr->{billing_code}) = $billing_sth->fetchrow_array();
      $sc_sth->execute($o_hr->{oi_pk});
      ($o_hr->{number_of_samples}) = $sc_sth->fetchrow_array();

      $owner_sth->execute($o_hr->{oi_pk});
      ($o_hr->{login},$o_hr->{contact_fname},$o_hr->{contact_lname},
        $o_hr->{contact_phone},$o_hr->{us_pk}) = $owner_sth->fetchrow_array();
      ($o_hr->{created_by_login}, $o_hr->{created_by_fname}, 
        $o_hr->{created_by_lname}) = doq($dbh, "order_creator_info", 
        $o_hr->{oi_pk});

      my $loop_instance = $loop_template;
      my $reclist2; # list of loop_instance2 records
      $reclist2 = "";

      $am_sth->execute($o_hr->{oi_pk});
      verify_order_completeness($dbh, $us_fk, $o_hr->{oi_pk}); 
      my $s_hr; # Messy. Used for results from several queries.
      while($s_hr = $am_sth->fetchrow_hashref())
      {
        $s_hr->{al_name} = "None selected";
        if ($s_hr->{al_fk} > 0)
        {
          $al_sth->execute($s_hr->{al_fk});
          ($s_hr->{al_name}) = $al_sth->fetchrow_array();
        }
        $sample_sth->execute($s_hr->{smp_pk}) ;
        ($s_hr->{timestamp}, $s_hr->{ec_name}, $s_hr->{abbrev_name}, 
          $s_hr->{study_name}, $s_hr->{sty_pk}) = $sample_sth->fetchrow_array();

        $s_hr->{timestamp} = sql2date($s_hr->{timestamp}); 
        my $loop_instance2 = $loop_template2;
        #
        # Only one of the hash refs will hit, so it is ok
        # to have both on the right side of the regexp.
        #
        $loop_instance2 =~ s/{(.*?)}/$o_hr->{$1}$s_hr->{$1}/g;
        $reclist2 .= $loop_instance2;
      }
      $o_hr->{message} .= get_stored_messages($dbh, $us_fk);     
      $o_hr->{order_status} = get_order_status($dbh, $us_fk, $o_hr->{oi_pk});         if ($o_hr->{order_status}  eq "SUBMITTED")
      {
        $o_hr->{approve_button} = qq#<input type=submit name=submit # .
          qq#value="Approve Order $o_hr->{order_number}">#;
      } 
      else
      {
        $o_hr->{approve_button} = "&nbsp";
      }

      $loop_instance =~ s/{(.*?)}/$o_hr->{$1}/g;
      $loop_instance =~ s/\<loop_here2\>/$reclist2/s; 
      $reclist .= $loop_instance;
    }
    return $reclist;
}

sub change_dbpw_generic
{
  my ($dbh, $us_fk, $newpass, $confirm) = @_;
  my $success = 1;

  if (-w "$WEB_DIR/.geoss")
  {
    # change the password in postgres
    my $sql = "alter user $GEOSS_SU_USER with password '$newpass'";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
   
    open (INFILE, "> $WEB_DIR/.geoss") || die "Unable to open $WEB_DIR/.geoss: $!\n";
    print INFILE "$newpass";
    close(INFILE); 
    $dbh->commit();
    $success = set_return_message($dbh, $us_fk, "message", "goodmessage",
        "SUCCESS_CHANGE_PASSWORD", "$GEOSS_SU_USER");
  } 
  else
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_CHANGE_PASSWORD_NO_ACCESS");
  }
  return $success;
}

sub build_al_select
{
  # Build something like this:
  # <select name="al_fk">
  # <option value="1">HG-U95Av2</option>
  # <option value="2">MG-U74A</option>
  # </select>
  my ($dbh, $field_name) = @_;

  $field_name = "al_fk" if (! $field_name);
  my $sql = "select al_pk,name from arraylayout order by name";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my $select_arraylayout = "<select name=\"$field_name\">\n";
  my $mid = "";
  while((my $al_pk, my $name) = $sth->fetchrow_array())
  {
    if ($al_pk != 0)
    {
      $mid .= "<option value=\"$al_pk\">$name</option>\n";
    }
    else
    {
      $select_arraylayout .= "<option value=\"$al_pk\">$name</option>\n";
    }
  }
  $select_arraylayout .= $mid . "</select>\n";
  return $select_arraylayout;
}

# this isn't exactly an exhaustive check and we will probably need to add 
# to, but it should catch glaring errors
sub check_upload_format_mas5
{
  my ($dbh, $us_fk, $fi_pk) = @_;
  my $good_format = 1;

  my $filename = doq($dbh, "get_file_name", $fi_pk);
  `grep "Probe Set Name" $filename`;
  $good_format = 0 if ($?);
 
  `grep Signal $filename`;
  $good_format = 0 if ($?);
 
  if (! $good_format)
  { 
    set_session_val($dbh, $us_fk, "message", "errmessage",
      get_message("ERROR_LOAD_BAD_INPUT"));
  }
  return ($good_format);
}

# Loading Data Subroutines
#

# this subrouting is intended for Member Users who upload data (as 
# opposed to curators).  It assumes that only the txt file is 
# provided and that no arraymeasurment record exists yet.

sub load_upload_mas5_data
{
  my ($dbh, $us_fk, $fi_pk, $chref) = @_;
  my $success;

  if (check_upload_format_mas5($dbh, $us_fk, $fi_pk))
  {
    ($success, my $am_pk) =
    create_am($dbh, $us_fk, $chref->{file_name}, $chref->{al_fk}, 
        $chref->{hyb_name});
    $success = prepare_load_mas5($dbh, $us_fk, $chref->{file_name}, $am_pk)
      if ($success == 1);
    my $file_name = doq($dbh, "get_file_name", $fi_pk);
    $success = insert_txt_data($dbh, $us_fk, $file_name, $am_pk, 
        $chref->{al_fk}) if ($success == 1);

    if ($success == 1)
    {
      doq($dbh, "set_date_loaded", $am_pk);
      $dbh->commit(); 
    }
    else
    {
      $dbh->rollback();
      my $success2 .= set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_DATA_LOAD");
      $dbh->commit();
      $success = $success2;
    }
  }
  else
  {
    $success = 0;
  }
  return($success);
}

sub load_brf_data
{
  my ($dbh, $us_fk, $chref) = @_;
  my $success = 1;

  # we want to load everything for $chref->{am_pk}

  # check if data is already loaded
  if (doq($dbh, "am_used_by_ams_date", $chref->{am_pk}))
  {
    $success = 0;
    my $msg = get_message("ERROR_DATA_ALREADY_LOADED", $chref->{am_pk});
    set_return_message($dbh, $us_fk, "message", "errmessage", $msg);
  }
  else 
  {
    my %qc = parse_rpt($chref->{rpt_file});
    my $sth = getq("hyb_info", $dbh);
    $sth->execute($chref->{am_pk});
    ((undef, undef, my $al_key) = $sth->fetchrow_array());
    $sth->finish();

    doq($dbh, "set_is_loaded", $chref->{am_pk});
    insert_qc($dbh, $chref->{am_pk}, \%qc);
    my $lot_number = get_lot_number($dbh, $us_fk, $chref->{exp_file},
      $chref->{txt_file} );
    doq_update_lot_number($dbh, $us_fk, $chref->{am_pk}, $lot_number) if ($lot_number);

    $success = insert_txt_data($dbh, $us_fk, $chref->{txt_file}, 
      $chref->{am_pk}, $al_key) if ($success == 1);
    doq($dbh, "set_date_loaded", $chref->{am_pk});
  }
  if ($success != 1)
  {
    $dbh->rollback();
    # set all the messges stored in success
    # we assume messages are stored as ##m followed by an optional param
    # : separates messages
    my $success2;
    foreach (split(/:/, $success))
    {
      /(\d+m)(.*)/;
      $success2 .= set_return_message($dbh, $us_fk, "message", "errmessage",
        "$1", "$2");
      
    }
    $success2 .= set_return_message($dbh, $us_fk, "message", "errmessage",
      "ERROR_DATA_LOAD");
    $success = $success2;
  }
  $dbh->commit();
  return($success);
}

sub insert_qc
{
  my $dbh = $_[0];
  my $am_pk = $_[1];
  my %qc = %{$_[2]};

  doq_insert_qc($dbh, \%qc);
  #
  # last_pk_seq uses currval, which assumes that nextval has been called 
  # in this session
  #
  my $qc_pk = doq($dbh, "last_pk_seq"); # see sql_lib

  doq_insert_housekeeping($dbh, $qc_pk, \%qc);
  doq_update_qc_fk($dbh, $qc_pk, $am_pk);
  return $qc_pk;
}

sub create_am
{
  my ($dbh, $us_fk, $filename, $al_fk, $hyb_name) = @_;
  my $success = 1;

  my $submission_date = `date`;
  chomp($submission_date);
  $submission_date = date2sql($submission_date);

  $dbh->quote($hyb_name);
  $dbh->quote($filename);

  my $sql = "insert into arraymeasurement (hybridization_name, 
    submission_date, am_comments, al_fk, description, is_loaded) values
    ('$hyb_name','$submission_date','$filename', $al_fk,'Affymetrix data','t')";
  
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  return($success, insert_security($dbh, $us_fk, $us_fk, 432));
}

sub prepare_load_mas5
{
  my ($dbh, $us_fk, $filename) = @_;
  my $success = 1;
  # must have TXT file
  my $login = doq($dbh, "get_login", $us_fk);
  if (! -r "$USER_DATA_DIR/$login/Upload/mas5/$filename")
  {
    $success = 0;
    my $msg = get_message("ERROR_UNABLE_TO_READ_FILE", $filename);
    set_return_message($dbh, $us_fk, "message", "errmessage", $msg);
  }
  return ($success);
}

sub prepare_load_brf
{
  my ($dbh, $us_fk, $chref, $filesref) = @_;
  my $success = "";
  my %ch = %$chref;
  my %files = %$filesref;

  # cannot load data that requires approval but has not been approved
  my $order_status = get_order_status($dbh, $us_fk, $ch{oi_pk});
  my $locked = doq_get_order_locked($dbh, $ch{oi_pk});
  (my $needs_approval, undef, undef) = doq_needs_approval($dbh, $ch{oi_pk});
  if (! $locked)
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "CANT_LOAD_DATA_UNLOCKED");
  }

  if (($needs_approval) && ($order_status eq "SUBMITTED"))
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "CANT_LOAD_DATA_NOT_APPROVED");
  }
 
  # confirm that the right files exist
  if ($success eq "")
  {
    if (! (-r "$files{txt}")) 
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_LOAD_DATA_MISSING_DATA_FILE", "$files{txt}");
    }
  }
 
  # link files
  my $out_path;
  my %new_files;
  if ($success eq "")
  {
     my $sth = getq("owner_info", $dbh);
     $sth->execute($ch{oi_pk});
     ((my $owner_us_fk, my $owner_gs_fk, my $owner_login) = 
       $sth->fetchrow_array());
    $sth->finish();
    $out_path = $USER_DATA_DIR . "/$owner_login/Data_Files/$ch{order_number}";
    if (! -e "$USER_DATA_DIR/$owner_login/Data_Files")
    {
      umask(0002);
      mkdir("$USER_DATA_DIR/$owner_login/Data_Files", 0770) ||
        warn "Unable to make $owner_login/Data_Files: $!";
    }
    
    foreach my $ext (keys(%files))
    {
      $ch{in_file} = $files{$ext};
      $files{$ext} =~ /(.*)\/(.*)/;
      $ch{out_file} = "$out_path/$2";
      chomp($ch{in_file});
      chomp($ch{out_file});
      if (! -e $out_path)
      {
        umask(0002);
        mkdir($out_path, 0770) || warn "Unable to mkdir $out_path $!";
      }
      if (-e $ch{in_file})
      {
        my $clobber = 1;
        if(!link_or_copy($ch{in_file}, $ch{out_file}, $clobber))
        {
          warn "unable to link or copy $ch{in_file} to $ch{out_file}: $!";
          $success = set_return_message($dbh, $us_fk, "message", "errmessage",
            "ERROR_LOAD_DATA_LINK", $ch{in_file}, $ch{out_file});
        }
        else
        {
          chmod(0440, $ch{out_file});
          fi_update($dbh, $owner_us_fk, $owner_gs_fk, $ch{out_file},
                      "Hybridization data", "",   # conds
                      "",   # cond labels
                      undef,   # node_fk
                      0,    #use_as_input
                      undef,   #ft_fk
                      288,      #permissions
                      undef); # not yet associated with an al_fk
          $new_files{$ext} = $ch{out_file};
        }
      }
    }
  }

  if ($success eq "")
  {
    #  verify that the chip type specified in arraymeasurement matches
    #  the chip type in the file
    my $sth2 = getq("hyb_info", $dbh);
    $sth2->execute($ch{am_pk});
    ((undef, undef, my $al_pk) = $sth2->fetchrow_array());
    $sth2->finish();
    $sth2 = getq("al_name", $dbh);
    $sth2->execute($al_pk);
    ((my $geoss_chip) = $sth2->fetchrow_array());
    $sth2->finish();

    my $file_chip = get_file_chip($files{'rpt'});

    if ($file_chip eq "0")
    {
       set_return_message($dbh, $us_fk, "message", "warnmessage",
         "WARN_FILE_CHIP_TYPE_UNKNOWN", $geoss_chip);
    }
    elsif ($geoss_chip !~  /$file_chip/)
    {
       $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_CHIP_TYPE_FILE_MISMATCH", $geoss_chip, $file_chip);
    }
  }
  return ($success, \%new_files);
}

sub get_file_chip
{
  my ($file) = @_;
  my $file_chip=0;

  if (! -r $file)
  {
    warn "Unable to read $file:$!\n";
  }
  else
  {
    $file_chip =  `grep "Probe Array Type" "$file"`;
    $file_chip =~ /Probe Array Type:\s+(\S*)\s*/;
    $file_chip = $1;
    # ignore anything in braces after the chip name
    if ($file_chip =~ /(.*)\(.*\)$/)
    {
      $file_chip = $1;
    }
  }
  return ($file_chip);
}

sub get_lot_number
{
  my ($dbh, $us_fk, $exp_name, $txt_name) = @_;
  my $number = "";

  # the lot number is in the EXP file or the TXT file

  my $ret = `grep -i "Chip Lot" $exp_name` if ($exp_name);
  if ($ret =~ /Chip Lot:\s+(\d+)/)
  {
    $number = $1;
  }
  $ret = `grep -i "Probe Array Number" $txt_name` if ($txt_name);
  if ($ret =~ /Probe Array Lot: (\d+)/)
  {
    $number = $1;
  }
  
  $ret = `grep -i "Lot Number" $txt_name` if ($txt_name);
  if ($ret =~ /Lot Number: (\d+)/)
  {
    $number = $1;
  }
  
  return ($number);
}

sub get_layout_hash
{
  my ($dbh, $us_fk, $al_pk) = @_;

  my $success = 1;
  my $ls_sth = getq("get_layout_spot", $dbh);
  $ls_sth->execute($al_pk);
  my %skh; # spot key hash
  if ($ls_sth->rows() == 0)
  {
    $success = 0;
    my $msg = get_message("ERROR_NO_LAYOUT_SPECIFIED", $al_pk);
    set_return_message($dbh, $us_fk, "message", "errmessage", $msg);
  }
  else
  {
    my $als_pk;
    my $spot_identifier;
    while(($als_pk, $spot_identifier) = $ls_sth->fetchrow_array())
    {
      if (exists($skh{$spot_identifier}))
      {
        $success = 0;
        my $msg = get_message("ERROR_AMBIGUOUS_SPOT_ID", $spot_identifier);
        set_return_message($dbh, $us_fk, "message", "errmessage", $msg);
      }
      $skh{$spot_identifier} = $als_pk;
    }
    $ls_sth->finish();
  }
  return ($success, \%skh);
}

sub insert_txt_data
{
  my ($dbh, $us_fk, $file_name, $am_pk, $al_pk, $log) = @_;

  $GEOSS::Database::ignore_security=1;
  my $hyb = GEOSS::Experiment::Arraymeasurement->new(pk => $am_pk);
  (my $success, my $skh_ref) = get_layout_hash($dbh, $us_fk, $al_pk);
  if ($success == 1)
  {
    my %skh = %$skh_ref;

    my $total_rows=0;
    my $spot_key;
    my $ams_sth;

    $ams_sth = getq("insert_am_spots_mas5", $dbh);

    my $first_flag = 1;
    my $first_probeset = "";
    my $last_probeset = "";
    my $refRow;
    my $all_data=readfile($file_name);
    my ($analysis_description, $is_mas5, $current_record, $ad_array_ref,
      $col_ref) = get_header($all_data);
    while (($current_record,$refRow) = get_data($dbh, $us_fk, 
       $current_record, $ad_array_ref, $col_ref)) 
    {
      last if (! defined $refRow);
      if ($first_flag)
      {
        $first_probeset = $refRow->{"Probe Set Name"};
        $first_flag = 0;
      }
      if (exists($skh{$refRow->{"Probe Set Name"}}))
      {
        $spot_key = $skh{$refRow->{"Probe Set Name"}};
        $ams_sth->execute($spot_key,
                          $am_pk,
                          $refRow->{"Stat Pairs"},
                          $refRow->{"Stat Pairs Used"},
                          $refRow->{"Signal"},
                          $refRow->{"Detection"},
                          $refRow->{"Detection p-value"});

        #
        # Spots aren't directly secured, so don't call insert_security()
        #
        $total_rows++;
        $last_probeset = $refRow->{"Probe Set Name"};
      }
      else
      {
        my $psn = $refRow->{"Probe Set Name"};
        $success = 0;
        GEOSS::Session->set_return_message("errmessage", 
            "ERROR_NO_SPOT_FOR_PROBE_SET_NAME", $psn);
      }
    }
    print "Total rows for hybridization $hyb: $total_rows\n";
    print $log "Total rows for hybridization $hyb: $total_rows\n" if ($log);
    print $log "First Probe Set Name: $first_probeset\n" if ($log);
    print "First Probe Set Name: $first_probeset\n";
    print $log "Last Probe Set Name: $last_probeset\n" if ($log);
    print "Last Probe Set Name: $last_probeset\n";
  }
  return($success);
}

sub get_header
{
  my $all_data = $_[0];
  my $is_mas5 = 0;

  my @ad_array = split('\n', $all_data);
  chomp(@ad_array);
  my $header = "";

  my $current_record = 0;
  while ($ad_array[$current_record] !~ m/Probe Set Name/)
  {
    # remove all control characters
    $ad_array[$current_record] =~ s/[\000-\037]//g; 
    $header .= "$ad_array[$current_record]\n";
    $current_record++;
  }
  # remove carriage control charcters, leave tabs!
  $ad_array[$current_record] =~ s/[\015\012]//g; 
  if ($ad_array[$current_record] =~ m/Signal/)
  {
    $is_mas5 = 1;
  }
  my @column_names = split('\t',$ad_array[$current_record]);
  $current_record++;
  return ($header, $is_mas5, $current_record, \@ad_array, \@column_names);
}


sub get_data
{
  my ($dbh, $us_fk, $current_record, $ad_array_ref, $col_ref) = @_;

  if ($current_record >= @$ad_array_ref)
  {
    $current_record = -1;
    return ($current_record, undef);
  }
  my %hash;
  my @data = split('\t', $ad_array_ref->[$current_record]);
  $current_record++;
  if ($#data == 0)
  {
    #
    # If there are no columns, we're done.
    # We haven't seen this case, I just put it in to be cautious.
    #
    return ($current_record, undef);
  }
  for(my $xx=0; $xx < @$col_ref; $xx++)
  {
    # remove any control chars. ^J^M are the usual problem.
    $data[$xx] =~ s/[\000-\037]//g; 
    if ($xx == 0 &&  (! $data[0]))
    {
      #
      # If the first column is empty, we're done.
      # We can't check this until the control chars are removed
      # This case occurs at the end of a MAS5 data file. There are a 
      # couple of blank lines down there.
      #
      return ($current_record,undef);
    }
    $hash{"$col_ref->[$xx]"} = $data[$xx];
  }
  if (exists($hash{Detection}))
  {
    $hash{Detection} =~ s/P/1/;
    $hash{Detection} =~ s/A/-1/;
    $hash{Detection} =~ s/M/0/;
  }
  if (exists($hash{"Abs Call"}))
  {
    $hash{"Abs Call"} =~ s/P/1/;
    $hash{"Abs Call"} =~ s/A/-1/;
    $hash{"Abs Call"} =~ s/M/0/;
  }

  return ($current_record, \%hash);
}

sub get_info
{
    (my $dbh, my $am_pk) = @_;
    my $sql = "select hybridization_name,order_number from arraymeasurement,
      sample,order_info where am_pk=? and order_info.oi_pk=sample.oi_fk 
      and arraymeasurement.smp_fk=sample.smp_pk";
    my $sth = $dbh->prepare($sql);
    $sth->execute($am_pk);

    (my $hybridization_name, my $order_name) = $sth->fetchrow_array();
    return ($hybridization_name, $order_name);
}

sub delete_file
{
   my $dbh = $_[0];
   my $fi_pk = $_[1];
   my $file_name = doq($dbh, "get_file_name", $fi_pk);
   doq($dbh, "delete_file_info", $fi_pk);
   `rm -f $file_name`;
   if ($?)
   {
     warn "Error removing file: $!";
   } 
   if (-e $file_name)
   {
     die "File was not deleted!\n";
   }
}
   
sub select_lab_book_owner
{
  my $field_name = shift || "lab_book_owner";

  my $us_fk = GEOSS::Session->user->pk;
  # get all the contact names
  #
  # build a drop down list of the sorted names
  # key is "fname lname" and value is the con_pk
  # The list only includes the names of all people for the groups 
  # that the user is in.

  # get the user keys for all users in the groups
  # that the current user is in

  my $sql = "select distinct us_fk from grouplink where gs_fk" .
    " in (select gs_fk from grouplink where us_fk=$us_fk)";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $in_clause = "";
  while(my ($key) = $sth->fetchrow_array())
  {
    $in_clause .= "$key,";
  }
  chop($in_clause);

  # get the contact information for all the users
  $sql="select con_pk, contact_lname, contact_fname from contact where" .
    " con_pk in ( $in_clause ) order by contact_lname";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  my $fname;
  my $lname,
  my $con_pk;
  my $select = "<select name=\"$field_name\">\n";
      $select .= "<option value=\"\">Please select</option>\n";
  while(($con_pk, $lname, $fname) = $sth->fetchrow_array())
  {
    # $se_hash{"$fname $lname"} = $con_pk;
    $select .= "<option value=\"$con_pk\">$lname, $fname</option>\n";
  }

  $select .= "</select>\n";
    
  return $select;
}

sub get_ec_info
{
  my ($dbh, $us_fk, $ec_pk) = @_;
  my %ec;
  my @ec_pks; 
  #get the info from exp_condition
  my $sth = getq("get_ec_by_ec_pk", $dbh, $us_fk);
  $sth->execute($ec_pk);
  my $ec_ref = $sth->fetchrow_hashref();
  %ec = %$ec_ref;

  # build a sample array of all samples associated with the ec
  $sth = getq("select_sample_by_ec_fk", $dbh, $us_fk);
  $sth->execute($ec_pk);
  my $smp_pk;
  my @smp_array = ();
  while (($smp_pk) = $sth->fetchrow_array()) 
  {
     my $smp_ref = get_sample_info($dbh, $us_fk, $smp_pk);
     $ec{is_loaded} = 1 if ($smp_ref->{is_loaded});
     push @smp_array, $smp_ref;
  }
  $ec{smp_array_ref} = \@smp_array; 
  return (\%ec);
}

# return the following information for each sample
# smp_pk
# smp_name
# ec_fk
# num_am
# al_fk(s) for am_pks
# lab_book
# lab_book_owner
# smp_origin
# smp_manipulation
# status
# oi_fk
# is_loaded
#
sub get_sample_info
{
  my ($dbh, $us_fk, $smp_pk) = @_;
  my %smp;
  my @am_pks; 

  #get the info from sample
  my $sth = getq("get_sample_by_smp_pk", $dbh, $us_fk);
  $sth->execute($smp_pk);
  my $smp_ref = $sth->fetchrow_hashref();
  if ($smp_ref)
  {
    %smp = %$smp_ref;
  
    #get the remaining info from arraymeasurement
    $smp{num_am} = doq($dbh, "num_hybs", $smp_pk);
    $smp{al_fk} = doq($dbh, "al_fk_for_smp_pk", $smp_pk);
    $smp{is_loaded} = doq($dbh, "sample_used_by_ams", $smp_pk);
    return (\%smp);
  } 
  else
  {
    GEOSS::Session->set_return_message("errmessage", "ERROR_OBJECT_UNKNOWN",
        "sample", $smp_pk);
    return();
  }
}

sub get_all_ec_info
{
  my ($dbh, $us_fk, $sty_pk) = @_;
  my @all_ecs;
  my $sth = getq("select_ecs_by_sty_pk", $dbh, $us_fk);
  $sth->execute($sty_pk);
  
  my $ec_pk;

  # get all samples associated with the order
  while (($ec_pk) = $sth->fetchrow_array()) 
  {
    push @all_ecs, get_ec_info($dbh, $us_fk, $ec_pk);
  }

  return (\@all_ecs);
}


sub get_all_sample_info_by_sty_pk
{
  my ($dbh, $us_fk, $sty_pk) = @_;
  my @all_smps;
  my $sth = getq("select_sample_by_sty_pk", $dbh, $us_fk);
  $sth->execute($sty_pk);
  
  my $smp_pk;

  # get all samples associated with the order
  while (($smp_pk) = $sth->fetchrow_array()) 
  {
    push @all_smps, get_sample_info($dbh, $us_fk, $smp_pk);
  }

  return (\@all_smps);
}

sub get_all_sample_info
{
  my ($dbh, $us_fk, $oi_pk) = @_;
  my @all_smps;
  my $sth = getq("select_sample_by_oi_fk", $dbh, $us_fk);
  $sth->execute($oi_pk);
  
  my $smp_pk;

  # get all samples associated with the order
  while (($smp_pk) = $sth->fetchrow_array()) 
  {
    push @all_smps, get_sample_info($dbh, $us_fk, $smp_pk);
  }

  return (\@all_smps);
}

sub doq_update_samples
{
  my ($dbh, $us_fk, $smp_pk, $oi_pk, $smp_ref) = @_;

  my $q_name = "doq_update_samples";
  my $sql = "update sample set ";
  my $key;
  foreach $key (keys(%$smp_ref))
  {
    if (($key eq "ec_fk") || ($key eq "smp_name") ||
        ($key eq "lab_book") || ($key eq "lab_book_owner") ||
        ($key eq "smp_origin") || ($key eq "smp_manipulation"))
    {
      if ($smp_ref->{$key} eq "NULL")
      {
        $sql .= " $key=$smp_ref->{$key},";
      }
      else
      { 
        my $val = $dbh->quote($smp_ref->{$key});
        $sql .= " $key=$val,";
      }
    } 
  }
  chop($sql); # remove trailing comma
  $sql .= " where smp_pk = $smp_pk";

  $dbh->do($sql);
  $sql = "update order_info set date_last_revised = now() where oi_pk =
  '$oi_pk'";
  $dbh->do($sql);
  $dbh->commit();
}


sub insert_exp_conds
{
  my ($dbh, $us_fk, $sty_pk, $chref) = @_;

  my $name = $chref->{default_exp_cond_name} || "";
  my $notes = $chref->{notes} || "";
  my $spc_fk = $chref->{default_spc_fk} || NULL;
  my $sample_type = $chref->{default_sample_type};
  my ($tissue_type, $cell_line,$sample_treatment);
  if ($sample_type eq "tissue")
  {
     $tissue_type = $chref->{default_type_details} || "";
  }
  elsif ($sample_type eq "cells")
  {
     $cell_line = $chref->{default_type_details} || "";
  }
  my $description = $chref->{default_description};
  my $abbrev_name = "";

  my $sql = "insert into exp_condition (sty_fk,name,notes,spc_fk," .
    "tissue_type,cell_line,description,sample_treatment,".
    "sample_type,abbrev_name) values ($sty_pk,trim('$name')," .
    "trim('$notes'),'$spc_fk',trim('$tissue_type'),trim('$cell_line')," .
    "trim('$description'),trim('$sample_treatment'),trim('$sample_type'),".
    "trim('$abbrev_name'))";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  $sth->finish();

  (my $owner_us_fk, my $owner_gs_fk, my $temp1, my $permissions) = 
    doq($dbh, "who_owns", $sty_pk);
  # new exp_condition gets same permissions as study
  my $ec_pk=insert_security($dbh, $owner_us_fk, $owner_gs_fk, $permissions);

  my $i;
  for ($i=0; $i < $chref->{default_bio_reps}; $i++)
  {
    insert_samples($dbh, $us_fk, $sty_pk, $chref, $ec_pk);
  } 
  $dbh->commit();
}

sub determine_default_al_fk_for_sample
{
  my ($dbh, $us_fk, $smp_pk, $default) = @_;

  # determine the al_fk.  If current hybs exist for this sample, use the same
  # al_fk as these are chip replicates
  # if no hybs exist for this sample, use the default al_fk

  my $al_fk = 1;  # always have an al_fk value

  my $sql = "select al_fk from arraymeasurement where smp_fk = $smp_pk";
  my @al_fks;
  @al_fks = $dbh->selectrow_array($sql); 
  if ($#al_fks > -1)
  {
    $al_fk = $al_fks[0];
  } else
  {
    # if caller didn't pass in a default, check to see if a default is defined 
    # in the study record
    if (!$default)
    {
      $sql = "select default_al_fk from study, exp_condition, sample " .
       "where sty_pk = sty_fk and ec_pk = ec_fk and smp_pk = $smp_pk";
      $default = $dbh->selectrow_array($sql);
    } 
    $al_fk = $default if ($default);
  }
  return($al_fk);
}

sub set_am_defaults
{
  my ($dbh, $us_fk, $sty_pk, $chref, $smp_pk) = @_;

  my $defaults = get_study_info($dbh, $us_fk, $sty_pk);

  $chref->{default_al_fk} = determine_default_al_fk_for_sample($dbh, 
    $us_fk, $smp_pk, $defaults->{default_al_fk}) if (! $chref->{default_al_fk});
}

sub set_ec_defaults
{
  my ($dbh, $us_fk, $sty_pk, $chref) = @_;

  my $defaults = get_study_info($dbh, $us_fk, $sty_pk);

  # general case for character varying/text
  foreach my $key ("default_exp_cond_name", "default_sample_type",
      "default_type_details")
  {
    if (! $chref->{$key})
    {
      $chref->{$key} = $defaults->{$key};
    }
  }

  #general casee for integer
  foreach my $key ("default_spc_fk")
  {
    if (! $chref->{$key})
    {
      $chref->{$key} = $defaults->{$key} ? $defaults->{$key} : "NULL";
    }
  }

  # integer - default to 1
  foreach my $key ("default_bio_reps")
  {
    if (! $chref->{$key})
    {
      $chref->{$key} = $defaults->{$key} ? $defaults->{$key} : 1 ;
    }
  }
}

sub set_sample_defaults
{
  my ($dbh, $us_fk, $sty_pk, $chref, $ec_pk) = @_;

  my $defaults = get_study_info($dbh, $us_fk, $sty_pk);

  # general case for character varying/text
  foreach my $key ("default_smp_manipulation", 
      "default_smp_origin", "default_lab_book", "default_smp_name")
  {
    if (! $chref->{$key})
    {
      $chref->{$key} = $defaults->{$key};
    }
  }

  #general casee for integer
  foreach my $key ("default_lab_book_owner")
  {
    if (! $chref->{$key})
    {
      $chref->{$key} = $defaults->{$key} ? $defaults->{$key} : "NULL";
    }
  }

  # integer - default to 1
  foreach my $key ("default_chip_reps")
  {
    if (! $chref->{$key})
    {
      $chref->{$key} = $defaults->{$key} ? $defaults->{$key} : 1 ;
    }
  }
}

sub insert_samples
{
  my ($dbh, $us_fk, $sty_pk, $chref, $ec_pk) = @_;

  my $submission_date = `date`;
  chomp($submission_date);
  $submission_date = date2sql($submission_date);
  set_sample_defaults ($dbh, $us_fk, $sty_pk, $chref, $ec_pk);

  my ($owner, $group, undef, $perms) = doq($dbh, "who_owns", $sty_pk);
  my $origin = $dbh->quote($chref->{default_smp_origin});
  my $sql = "insert into sample (ec_fk, smp_name, lab_book,
     lab_book_owner, smp_origin, smp_manipulation) values ($ec_pk, " .
     $dbh->quote($chref->{default_smp_name}) . ", " .
     $dbh->quote($chref->{default_lab_book}) . 
     ", $chref->{default_lab_book_owner}, " . 
     $dbh->quote($chref->{default_smp_origin}) . ", " .
     $dbh->quote($chref->{default_smp_manipulation}) . ")"; 
  warn "SQL: $sql";
  $dbh->do($sql);
  my $smp_pk = insert_security($dbh, $owner, $group, $perms);

  my $i;

  # insert hybridizations
  set_am_defaults ($dbh, $us_fk, $sty_pk, $chref, $smp_pk);
  $sql = "insert into arraymeasurement (submission_date, al_fk, smp_fk) values 
    ('$submission_date', $chref->{default_al_fk}, $smp_pk)";
  for ($i =0; $i<$chref->{default_chip_reps}; $i++)
  {
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    insert_security($dbh, $owner, $group, $perms);
  }
  
  $dbh->commit();
}

sub check_valid_study_defaults
{
  my ($dbh, $us_fk, $chref) = @_;
  my $ret = 1;

  return($ret);
}

# historical orders may not have default values assigned.  Additionally,
# they may not have hybridizations.  This will invalidate the current 
# order edit mechanism.  We want to do the following:
#
# if there is no default chip type, see if we can figure it out
# if hybridizations currently exist, set the default chip type 
# = to the current chip type
#
# if there is not default chip number, set default to 1
#
# next, ensure that all samples have at least 1 hybridization
# if they don't and we have a default chip type and chip num,
# add they hybridizations
#
# if they don't and we don't have a default chip type, fail the 
# check_valid_defaults
#
sub check_valid_defaults
{
  my ($dbh, $us_fk, $chref) = @_;
  my $ret = 1;

  # get the order information
  my $ord_ref = get_order_info($dbh, $us_fk, $chref->{oi_pk});
  
  if (! $chref->{default_ams})
  {
    doq_order_info_update($dbh, $us_fk, $chref->{oi_pk},
        {
          "default_ams", 1,
        });  
    $dbh->do("update order_info set date_last_revised = now() where
      oi_pk = '$chref->{oi_pk}'");
    $chref->{default_ams} = 1;
  }

  if (! $chref->{al_fk})
  {
    my $al_fk = getq_al_fk_by_oi_pk($dbh, $us_fk, $chref->{oi_pk});
    if ($al_fk)
    {
      doq_order_info_update($dbh, $us_fk, $chref->{oi_pk},
        {
          "default_al_fk", $al_fk,
        });
      $chref->{default_al_fk} = $al_fk;
      $dbh->do("update order_info set date_last_revised = now() where
         oi_pk = '$chref->{oi_pk}'");
    }
    else
    {
      $ret = 0;
    }
  }
  $dbh->commit();

  # for each sample, check more than one hybridization
  my $sth = getq("get_sample", $dbh, $us_fk);
  $sth->execute($chref->{oi_pk});
  while (my $s_hr = $sth->fetchrow_hashref())
  {
    my $num_am = doq($dbh, "num_hybs", $s_hr->{smp_pk});
    if (($num_am == 0) && ($chref->{default_al_fk}) &&
        ($chref->{default_ams})) 
    {
       doq_update_num_am($dbh, $us_fk, $s_hr->{smp_pk}, $chref->{default_ams});
    }
    elsif (($num_am==0) && ((! $chref->{default_al_fk}) || (!
            $chref->{default_ams})))
    {
      $ret = 0;
    }
  }
  return($ret);
}

# in_array
# 8-10-04
# Steve Tropello
# Checks if specified object is in a specified array
# Return 0 (not in array) or 1 (in array)
sub in_array
{

  my ($element, @array) = @_;
  my $array_element;
  foreach $array_element (@array)
  {
    return 1 if ($array_element eq $element);
  }
  return 0;
} #in_array


sub saveExtractInfo
{
  my ($dbh, $us_fk, $chref, $condref) = @_;

  my $idx = 0;
  foreach my $cond (@$condref)
  {
    set_session_val($dbh, $us_fk, "extract", "label$idx", $cond->{label});
    set_session_val($dbh, $us_fk, "extract", "sty_fk$idx", $cond->{sty_fk});
    set_session_val($dbh, $us_fk, "extract", "ec_pk$idx", $cond->{ec_pk});
    set_session_val($dbh, $us_fk, "extract", "notes$idx", $cond->{notes});
    my @am_pks = ();
    @am_pks = @{$cond->{am_pk}} if (defined @{$cond->{am_pk}});
    my @hybs = ();
    @hybs = @{$cond->{hybrids}} if (defined @{$cond->{hybrids}});
    my $i;
    for ($i=0; $i <= $#am_pks; $i++)
    {
      set_session_val($dbh, $us_fk, "extract", "am_pk$idx", 
        "$i $am_pks[$i]");
      set_session_val($dbh, $us_fk, "extract", "hybrids$idx", 
        "$i $hybs[$i]");
    }
    $idx++;
  }
} # saveExtractInfo

sub draw_index_curtools
{
  (my $dbh, my $us_fk, my $q) = @_;
  my %ch = $q->Vars();
  if (get_config_entry($dbh, "array_center"))
  {
  if (is_curator($dbh, $us_fk))
  {
    $ch{htmltitle} = "Array Center Staff Home";
    $ch{help} = set_help_url($dbh, "array_center_staff_guide");
    (my $allhtml, my $loop_template) = readtemplate("index.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html");
    my $sth = getq("oi_pk_number_all", $dbh);
    $sth->execute();

    my $rows=$sth->rows();

    while( ($ch{oi_pk}, $ch{order_number}, $ch{pi_name}, $ch{pi_group}) = 
      $sth->fetchrow_array())
    {
      $ch{order_number} .= "," if $ch{order_number};
      my $loop_instance = $loop_template;
      $loop_instance =~ s/{(.*?)}/$ch{$1}/g;
      $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }
    $allhtml =~ s/<loop_here>//s;
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};
    $allhtml =~ s/{(.*?)}/$ch{$1}/g;

    print "Content-type: text/html\n\n$allhtml\n";
  }
  }
  else
  {
    GEOSS::Session->set_return_message("errmessage",
        "ERROR_ARRAY_CENTER_NOT_ENABLED");
    print "Location: " . index_url($dbh, "webtools") . "\n\n";
    exit;
  }
  $dbh->disconnect();
  exit(0);
}

sub is_study_loaded
{
  my ($dbh, $us_fk, $sty_pk) = @_;

  my $sql = "select date_loaded from study, exp_condition, sample,
     arraymeasurement where smp_pk=smp_fk and ec_pk=ec_fk and sty_fk = sty_pk
     and sty_pk = $sty_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $loaded = 1;
  my $date_loaded;
  my $am_count = 0;
  while (($date_loaded) = $sth->fetchrow_array())
  {
    $am_count++;
    $loaded = 0 if (! $date_loaded);
  }
  $loaded = 0 if ($am_count ==0);
  return($loaded);
}

sub select_species
{
  my $dbh = $_[0];
  my $field_name = $_[1];

  # Old code gets all entries from the species table.
  # my $sql = "select spc_pk,primary_scientific_name from species
  #     order by primary_scientific_name";
  # New code only gets a select group.
  my $sql = "select spc_pk,primary_scientific_name from ". 
   " species where spc_pk in (4,5,6,41,44,50,53,108) order by ". 
   " primary_scientific_name";

  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my %species_name;
  $field_name = "spc_fk" if (! $field_name);
  my $sample_select = "<select name=\"$field_name\">\n";
  my $spc_pk;
  my $psn;

  while(($spc_pk, $psn) = $sth->fetchrow_array())
  {
    $sample_select .= "<option value=\"$spc_pk\">$psn</option>\n";
    $species_name{$spc_pk} = $psn;
  }
  $sample_select .= "</select>\n";
  return ($sample_select, %species_name);
}

sub associate_study_disease
{
  my ($dbh, $sty_fk, $dis_fk) = @_;
  
  $dbh->do("delete from disease_study_link where sty_fk = $sty_fk");
  if ($dis_fk > 0)
  {
    $dbh->do("insert into disease_study_link (dis_fk, sty_fk) " .
       "values ($dis_fk, $sty_fk)");
  }
}

sub canonicalFilename {
  my $s = shift;
  $s =~ y/ /_/;
  $s =~ y#A-Za-z0-9_./-##cd;
  return $s;
}

sub link_or_copy {
  my $from = shift;
  my $to = shift;
  my $clobber = shift;
  if ($clobber)
  {
    if (-e $to)
    {
# potentially we should check to see if the files are different and
# warn the user if we are overwriting.  However, presumably we want
# to load from the current load data
        unlink $to or return 0;
    }
  }
  link($from, $to) and return 1;
  $! == POSIX::EXDEV or return 0;
  return copy($from, $to);
}

# this function is called prior to creating an account
# it verifies that the correct values exist and set defaults as necessary
# Values for the new account are passed in via the acctref hash.
# Calling functions can pass in as little as login, pi_login, type
# password, confirm_password or all the fields in contact table.
# Note that if us_fk is set to "command", we assume that we are 
# being called from a command line utility and return messages
# as a string instead of setting values in the session.
sub verify_acct_generic 
{
  my ($dbh, $us_fk, $acctref) = @_;

  my $sql;
  my $sth;
  my $ret_string = "";
 
  # type must be defined
  if (! exists($acctref->{type}))
  {
    $ret_string .= set_return_message($dbh, $us_fk, "message", 
        "errmessage", "FIELD_MANDATORY", "Type");
  };

  if ((exists($acctref->{login})) && ( $acctref->{login} ne ""))
  {
    $sql = "SELECT count(*) FROM usersec where login='$acctref->{login}'";
    $sth = $dbh->prepare($sql);
    $sth->execute();
    if ($sth->fetchrow_array())
    {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "FIELD_MUST_BE_UNIQUE", "Login name ");
    }
    $sth->finish;
  }     
  else
  {
    $ret_string .= set_return_message($dbh, $us_fk, "message", 
        "errmessage", "FIELD_MANDATORY", "Login name ");
  }

  if ((exists($acctref->{pi_login})) && ($acctref->{pi_login} ne ""))
  {
    $acctref->{pi_login} = $acctref->{login}
    if ($acctref->{pi_login} eq "own");
    if ((! is_pi($dbh, $acctref->{pi_login})) && 
        ($acctref->{pi_login} ne $acctref->{login}))
    {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "INVALID_PI", $acctref->{pi_login});
    }
  }     
  else
  {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "FIELD_MANDATORY", "PI Login ");
  }  

  if ((exists($acctref->{password})) && ($acctref->{password} ne ""))
  {
    $ret_string .= invalid_password($dbh, $us_fk, $acctref->{password});
  }     
  else
  {
    $ret_string .= set_return_message($dbh, $us_fk, "message", 
        "errmessage", "FIELD_MANDATORY", "Initial password");
  }  

  if ((! exists($acctref->{confirm_password})) ||
      ($acctref->{confirm_password} eq ""))
  {
    $ret_string .= set_return_message($dbh, $us_fk, "message", 
        "errmessage", "FIELD_MANDATORY", "Confirmation password");
  }  
  if ($acctref->{password} ne $acctref->{confirm_password})
  {
    $ret_string .= set_return_message($dbh, $us_fk, "message", 
        "errmessage", "ERROR_PASSWORD_MISMATCH");
  }

  if ((exists($acctref->{contact_lname})) && 
      ($acctref->{contact_lname} eq ""))
  {
    $acctref->{contact_lname} = "$acctref->{login}";
  };     

  if ((exists($acctref->{contact_email})) && 
      ($acctref->{contact_email} ne ""))
  {
    if (! valid_email_check($acctref->{contact_email}))
    {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "INVALID_EMAIL_ADDRESS", "Contact");
    }
    $sql = "SELECT con_pk FROM Contact where
      contact_email=\'$acctref->{contact_email}\'";
    $sth = $dbh->prepare($sql);
    $sth->execute();
    my $contacts = $sth->rows;
    $sth->finish;

    if ($contacts > 0 && $acctref->{type} ne "curator" 
        && $acctref->{type} ne "developer")
    {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "FIELD_MUST_BE_UNIQUE", "Contact email");
    }
  };     

  if ((($acctref->{type} eq "experiment_set_provider") ||
       ($acctref->{type} eq "administrator") ||
       ($acctref->{type} eq "curator"))
   && (get_config_entry($dbh, "allow_member_users")) != 1)
  {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "INVALID_USER_TYPE", "experiment_set_provider");
  }

  if (($acctref->{type} eq "public") && 
      (get_config_entry($dbh, "allow_public_users")) != 1)
  {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "INVALID_USER_TYPE", "public");
  } 

  if (length($acctref->{org_mail_address}) > 128)  
  {
      $ret_string .= set_return_message($dbh, $us_fk, "message", 
          "errmessage", "INVALID_LENGTH_128", "Organization Mail Address");
  } 
  return $ret_string;
}

sub verify_study_data_file_format
{
  my ($dbh, $us_fk, $sty_pk, $fi_pk) = @_;
  return 1;
}

sub submit_order
{
  my ($dbh, $us_fk, $oi_pk) = @_;

  my $email_file;
  my $submit = 1;
 
  # we can only submit an order if the order is in a "COMPLETE" state
  # and if the order is writable by the current user

  if (! is_writable($dbh, "order_info","oi_pk", $oi_pk, $us_fk)) 
  {
    warn "Error on write";
    set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("INVALID_PERMS"));
    $submit = 0;
  }

  if (get_order_status($dbh, $us_fk, $oi_pk) ne "COMPLETE") 
  {
    set_session_val($dbh, $us_fk, "message", "errmessage", 
        get_message("INCORRECT_ORDER_STATUS", "COMPLETE","submitted"));
    $submit = 0;
  }
 
  my ($needs_approval, $org_fk);
  if ($submit == 1)
  {
    ($needs_approval, $org_fk) = doq_needs_approval($dbh, $oi_pk);
  }
  if (($org_fk) && ($needs_approval == 1))
  {
    # if the order belongs to an organization, email the org admins
    my $email_file = "./order_submit_org_email.txt";

    my @org_curs = doq_get_org_curs_email($dbh, $org_fk);
    if ($#org_curs == -1)
    {
      # there are no administrators for this organization
      # automatically approve the order, but send a warning to the 
      # GEOSS administrator
      my ($org_name) = $dbh->selectrow_array("select org_name from 
        organization where org_pk = $org_fk");
      my $email_file = "no_org_curator_email.txt";
      auto_approve($dbh, $us_fk, $oi_pk, $org_fk);
      my $info = 
      {
        "email" => get_config_entry($dbh, "admin_email"),
        "org_fk" => $org_fk,
        "org_name" => $org_name,
      };
      email_generic($dbh, $email_file, $info) if ($info->{email} ne "");
    }
    my $approve_url = index_url($dbh, "orgtools") .
      "/org_approve.cgi?oi_pk=$oi_pk";
    foreach (@org_curs)
    { 
      my $info = 
      {
         "email" => $_,
         "oi_pk" => $oi_pk,
         "approve_url" => $approve_url,
      };
      email_generic($dbh, $email_file, $info) if ($info->{email} ne "");
    }
  }
  else
  {
    auto_approve($dbh, $us_fk, $oi_pk, $org_fk);
  }
  lock_order($dbh,$oi_pk);
  set_session_val($dbh, $us_fk, "message", "goodmessage", 
      get_message("SUCCESS_SUBMIT_ORDER"));
  return $submit;  
}

sub auto_approve
{
  my ($dbh, $us_fk, $oi_pk, $org_fk, $order_number) = @_;

  # if the order does not require approval, approve automatically
  # and send to the curator
  my $email_file = "./order_submit_curator_email.txt";
  my $curator_email = get_config_entry($dbh, "curator_email");
  my $assign_url = index_url($dbh, "curtools") . 
    "/assign_order_number.cgi?oi_pk=$oi_pk";
  my $info = 
  {
    "email" => $curator_email,
    "oi_pk" => $oi_pk,
    "order_assign_url" => $assign_url,
  };
  email_generic($dbh, $email_file, $info);
  doq_approve_order($oi_pk, $org_fk);
}

sub verify_data_file
{
  my ($dbh, $us_fk, $file, $ams, $chip) = @_;
  my $success = 1;
  
  if (! -r $file)
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
      "UNABLE_TO_READ_FILE", "$file:$!"); 
  };

  if (! -T $file)
  {
    $success = set_return_message($dbh, $us_fk, "message", "errmessage",
      "ERROR_BAD_FILE_TYPE", "ASCII text"); 
  };

  if (open(my $fh, $file)) 
  {
    chomp(my $line = <$fh>);
    if ($line !~ s/^Probesets\t//i)
    {
      $success = set_return_message($dbh, $us_fk, "message", "errmessage",
        "ERROR_BAD_FILE_FORMAT", 
        "The header of the first column must be 'Probesets'.  Line is $line."); 
    }

    my @ams = map {
      GEOSS::Experiment::Arraymeasurement->new(pk => $ams->{$_})
       or $success = set_return_message($dbh, $us_fk, "message", "errmessage",
       "ERROR_BAD_FILE_CONTENT", 
       "Arraymeasurement $ams->{$_} specified in $file: line 1 doesn't exist.");
    } split /\s+/, $line;

    for (my $i; $i < 10; $i++)
    {
      #verify several lines for chip agreement (al_spots) and data format
      $line = <$fh>; chomp ($line);
      next unless length($line); 
 
      my ($probeset, @signals) = split /\s+/, $line;
      my $spots = $chip->al_spots;
      if (! exists($spots->{$probeset}))
      {
        $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_BAD_FILE_CONTENT", 
          "Bad $probeset in $file: line $i. Probeset doesn't exist for\
          the specified layout: $chip.");
      }
      
      if (scalar(@ams) != scalar(@signals))
      {
        $success = set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_BAD_FILE_FORMAT", 
          "The number of signal values (" . scalar(@signals) . ") in $file: \
          line $i does not match the number of arraymeasurements (" . 
          scalar(@ams) . ")."); 

      }
      foreach (@signals)
      {
        if ((defined $_) && ($_ !~ /\d+\.?\d*/))
        {
          $success = set_return_message($dbh, $us_fk, "message", "errmessage",
            "ERROR_BAD_FILE_CONTENT", 
            "Bad signal value ($_) in $file: line $i.  Expected real \
            number.");
        }
      }
    }
  } 
  else {
    warn "Unable to open $file: $!";
  }
  return($success);
}

sub set_data_dir {
  my $file = shift;
  my $destdir = shift;
  my $owner = shift;
  my $group = shift;

  mkdir($destdir);
  my $destfile = $destdir . "/" . basename($file->name);
  link_or_copy($file->name, $destfile, 1);
  $file = GEOSS::Fileinfo->update_or_insert(
    { name => $destfile },
    { owner => $owner,
      group => $group,}
  );
  opendir(my $dir, $file) or die "Unable to opendir $file";
  my $datafile;
  while ($datafile = readdir($dir))
  {
    if (-f $datafile)
    {
      link_or_copy($file->name . "/$datafile", $destfile . "/$datafile", 1);
      GEOSS::Fileinfo->update_or_insert(
          { name => $destfile . "/$datafile" },
          { owner => $owner,
            group => $group,}
          );
    }
  }
  closedir($dir);
  return ($file);
}

sub load_data_from_file
{
  my ($file, $valid_ams, $chip) = @_;
  
  my $spots = $chip->al_spots;

  open(my $fh, $file) or die "Unable to open $file: $!";
  chomp(my $line = <$fh>); # header line
  $line =~ s/^Probesets\t//i
    or die "unable to parse $file: first column header must be Probesets";
  my @ams = map {
    GEOSS::Experiment::Arraymeasurement->new(pk => $valid_ams->{$_})
      or die "arraymeasurement $_ does not exist";
  } split /\s+/, $line;

  while ($line = <$fh>)
  {
    chomp($line);
    next unless length($line);

    my ($probeset, @signals) = split /\s+/, $line;
    exists($spots->{$probeset})
      or die "unknown probeset $probeset for chip $chip";
    my $als = $spots->{$probeset};

    foreach my $i (0 .. $#signals) {
      $ams[$i]->set_measurement($als, $signals[$i]);
    }
  }

  foreach (@ams) {
    # XXX the update function doesn't handle literal values that should not
    # be quoted (like now()).
    $dbh->do('update arraymeasurement set date_loaded=now() where am_pk='
        . $_->pk);
  }
}

1;
