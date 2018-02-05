use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my %formhash;
    my $co = new CGI;
    my %glhash;

    %formhash = $co->Vars();

    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/groups.cgi");

    foreach my $key (keys(%formhash))
    {
        if ($key =~ m/gl_(\d+)/)
        {
            $glhash{$1} = $formhash{$key};
        }
    }
    if ((! exists($formhash{step}))) {
        #
        # step 1: the user has logged via htaccess.        
        #
        showGroups($dbh, $us_fk, $co);
    }
    elsif ($formhash{step} == 2) {
        #
        # step 2: We get their group info and display it in a web page
        #
        my $con_fk = $us_fk;
        my $sql = "select gs_name from groupsec where gs_pk=$formhash{gs_pk}";
        ($formhash{gs_name}) = $dbh->selectrow_array($sql);

        my %ch = %{get_all_subs_vals($dbh, $us_fk, {})};

        my $allhtml = readfile("groups2.html", "/site/webtools/header.html", "/site/webtools/footer.html");
        $ch{htmltitle} = "GEOSS Group Management";
        $ch{help} = set_help_url($dbh, "manage_membership_of_my_groups");
        $ch{htmldescription} = "" ;

        $allhtml =~ s/<start>(.*)<end>/<loop_here>/s;
        my $loop_template = $1;
        my $gchecks = gchecks($dbh, $formhash{gs_pk}, $formhash{gs_name}, $loop_template);

        $allhtml =~ s/<loop_here>/$gchecks/; # remove lingering template loop tag
        $allhtml =~ s/{gs_name}/$formhash{gs_name}/;
        $allhtml =~ s/{gs_pk}/$formhash{gs_pk}/;
        $allhtml =~ s/{step}/3/;

        $allhtml =~ s/{(.*?)}/$ch{$1}/g;
        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
    }
    elsif ($formhash{step} == 3) {
        #
        # step 3: update grouplinks to reflect new membership
        #
        my $sql = "select gs_owner from groupsec where gs_pk=$formhash{gs_pk}";
        my $sth = $dbh->prepare($sql);
        $sth->execute();

        if ($sth->rows() < 1)
        {
            die "Wrong number of groups returned for $sql\n";
        }
        update_grouplink($dbh, $formhash{gs_pk}, \%glhash);

        $dbh->commit;

        # we want to show the "manage" buttons again
        showGroups($dbh, $us_fk, $co);
    }
    $dbh->disconnect;
}

sub showGroups
{
  my ($dbh, $us_fk, $co) = @_;

        my $sql = "select gs_pk,gs_name from groupsec where gs_owner=$us_fk";
        my $sth = $dbh->prepare($sql);
        $sth->execute();

        my $allhtml = readfile("groups.html", "/site/webtools/header.html", "/site/webtools/footer.html");
        $allhtml =~ s/<start>(.*)<end>/<loop_here>/s;
        my $loop_template = $1;
        my $loop_instance;
        my $loop_count = 0;
        my $s_hr;
        while($s_hr = $sth->fetchrow_hashref())
        {
            $loop_instance = $loop_template;
            foreach my $key (keys(%{$s_hr}))
            {
                my $value = $s_hr->{$key};
                $loop_instance =~ s/{$key}/$value/g;
            }
            $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
            $loop_count++;
            
        }

        $allhtml =~ s/{group_count}/$loop_count/;
        my $s = "";
        if ($loop_count > 1) 
        {
            $s = "s";
        }
        $allhtml =~ s/{s}/s/;
        $allhtml =~ s/<loop_here>//; # remove lingering template loop tag
        $allhtml =~ s/{step}/2/g;
        my %ch;
        $ch{htmltitle} = "GEOSS Group Management";
        $ch{htmldescription} = "";

        %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

        $allhtml =~ s/{(.*?)}/$ch{$1}/g;


        print $co->header;
        print "$allhtml\n";
        print $co->end_html;
} #showGroups

#
# For the purposes of this comment, "me" and "my" is the currently logged in user.
# Generate a set of checkboxes, one checkbox for each user in the contact table.
# If the user is in my group, set the checkbox to checked.
# This returns a set of HTML table rows, which should be fixed to be more generic
# This is called from accountAccess.pl
#
sub gchecks
{
  my $dbh = $_[0];
  my $gs_fk = $_[1];
  my $gs_name = $_[2];
  my $loop_template = $_[3];
  my @user_list; 
  my %grouph;
  
  #
  # list all users
  #
  my $sth = getq("get_non_admin_contact_names", $dbh);
  $sth->execute();
  my $key;
  my $fname;
  my $lname;
  my $login;
  my $u_count = 0;
  while(($key,$fname,$lname,$login) = $sth->fetchrow_array())
  {
    $user_list[$u_count][0] = $key;
    $user_list[$u_count][1] = "$lname, $fname ($login)";
    $u_count++;
  }
  $sth->finish();

  #
  # users in grouplink that are in my group
  #
  $sth= $dbh->prepare("select us_fk,gs_fk from grouplink where gs_fk=$gs_fk") || die "prep grouplink\n$DBI::errstr\n";
  $sth->execute() || die "exec grouplink\n$DBI::errstr\n";
  my $value;
  while(($key,$value) = $sth->fetchrow_array())
  {
    $grouph{$key} = $value;
  }
  $sth->finish();
  
  my $results;
  my $temp;
  my $loop_instance;
  #
  # Where we would normally change name="xyz" with a loop_count variable
  # instead use the us_pk i.e. for us_pk 2, name="gl" becomes name="gl_2"
  # 
  # 2003-06-12 Tom: change from hash to a list to maintain order.
  #
  for(my $uu = 0; $uu <= $#user_list; $uu++)
  {
    my $pk = $user_list[$uu][0];
    my $option = $user_list[$uu][1];
    
    $loop_instance = $loop_template;
    my $checked = "checked";
    if (! exists($grouph{$pk}))
    {
      $checked = "";
    }
    $loop_instance =~ s/{checked}/$checked/;
    $loop_instance =~ s/{username}/$option/;
    $loop_instance =~ s/{us_pk}/$pk/;
    $loop_instance =~ s/name=\"(.*?)\"/name=\"$1_$pk\"/g;
    
    $results .= $loop_instance;
  }
  return $results;
}

sub group_radiolist
{
    my $dbh = $_[0];
    my $us_fk = $_[1];
    my $rlist;
    my $sql = "select gs_pk,gs_name from groupsec where gs_owner=$us_fk";
    (my $groups) = $dbh->selectall_arrayref($sql);
    foreach my $tmp (@{$groups})
    {
        $rlist .= "<tr><td>$tmp->[1]</td><td><input type=radio name=group value=\"$tmp->[0]\"></td></tr>";
    }
    return $rlist;
}


#
# Make the database reflect the set of checkboxes returned from the web form.
# Delete any records that are no longer checked, but exist in the db.
# Insert things that are checked but don't exist in the db.
# The other two cases require no change (exists and checked, doesn't exist and isn't checked)
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

    my $sth = $dbh->prepare("select us_fk,gs_fk from grouplink where gs_fk=$gs_pk");
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
            # never delete if the us_fk = gs_fk (the group belongs to that user)
            if ($key != $gs_pk)
            {
              # it is in the db, but not returned from the web form,
              #  delete from the db.
              $sql = "delete from grouplink where us_fk=$key and gs_fk=$gs_pk";
              $dbh->do($sql) || die "Delete failed: $sql\n$DBI::errstr\n";
            }
        }
    }
    foreach my $key (keys(%glhash))
    {
        if (! exists($dbhash{$key}))
        {
            # it was returned from the web form, but is not in the db, 
            # insert into the db.
            $sql = "insert into grouplink (us_fk, gs_fk) values ($key, $gs_pk)";
            $dbh->do($sql) || die "Insert failed: $sql\n$DBI::errstr\n";
        }
    }
}

