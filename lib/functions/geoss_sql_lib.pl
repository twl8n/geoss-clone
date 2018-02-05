package main;
use strict;
use GEOSS::Database;

# doq is at the bottom.

sub getq
{
  my $q_name = $_[0];
  my $dbh    = $_[1];
  my @args;
  $args[0]=$_[2];
  $args[1]=$_[3];
  if (! defined($dbh))
  {
    die "Database handle undefined in sql_lib getq()\n";
  }
  my $sth; 
  my $ok_flag = 0;
  my $sql;

  if ($q_name eq "get_non_admin_contact_names")
  {
    $sql = "select con_pk,contact_fname,contact_lname,login from " .
      "usersec,contact where con_pk=us_pk and type != 'administrator'" .
      " order by contact_lname,contact_fname";
  }
  elsif ($q_name eq "unique_hyb")
  {
    my $hyb = $args[0];
    $sql = "select count(*) from arraymeasurement where " .
      "hybridization_name='$hyb'";
  }
  elsif ($q_name eq "get_all_config_entries")
  {
    $sql = "select * from configuration";
  }
  elsif ($q_name eq "get_config_entry")
  {
    my $column = $args[0];
    $sql = "select $column from configuration";
  }
  elsif ($q_name eq "get_all_us_pks_by_type")
  {
    my $type = $args[0];
    $sql = "select us_pk from usersec, contact where con_pk = " .
      "con_fk and type = '$type'";
  }
  elsif ($q_name eq "get_user_type")
  {
    my $us_fk = $args[0];
    $sql = "select type from contact where con_pk = '$us_fk'";
  }
  elsif ($q_name eq "get_user_type_by_login")
  {
    my $login = $args[0];
    $sql = "select type from contact,usersec where con_pk = con_fk " .
      "and login = '$login'";
  } 
  elsif ($q_name eq "get_all_gs_pks")
  {
    $sql = "select gs_pk from groupsec";
  }
  elsif ($q_name eq "get_checkboxes")
  {
    $sql = "select upv_pk from user_parameter_names, " .
      " user_parameter_values  where upn_fk = upn_pk and " .
      "up_type='checkbox' and node_fk=?";
  }
  elsif ($q_name eq "get_inactive_users")
  {
    my $type = $args[0];
    if ($type eq "all")
    {
      $sql = "select us_pk, login, age(last_updated) from contact, " .
        "usersec where con_pk = con_fk and last_login is NULL";
    }
    else
    {
      $sql = "select us_pk, login, age(last_updated) from contact, usersec "
        . "where con_pk = con_fk and last_login is NULL and type = '$type'";
    }
  }
  elsif ($q_name eq "select_data")
  {
    my $us_fk = $args[0];
    $sql = "select fi_pk, file_name from file_info, groupref where " .
      "fi_pk=ref_fk and us_fk=$us_fk and file_name like '%Upload/data/%'";
  }
  elsif ($q_name eq "select_logo")
  {
    my $us_fk = $args[0];
    $sql = "select fi_pk, file_name from file_info, groupref where " .
      "fi_pk=ref_fk and us_fk=$us_fk and file_name like '%logo/%'";
  }
  elsif ($q_name eq "select_icon")
  {
    my $us_fk = $args[0];
    $sql = "select fi_pk, file_name from file_info, groupref where " .
      "fi_pk=ref_fk and us_fk=$us_fk and file_name like '%icon/%'";
  }
  elsif ($q_name eq "select_users_to_disable")
  {
    $sql = "select us_pk, login, contact_fname, contact_lname from " .
      "contact, usersec where con_pk=con_fk and type != 'disable' " .
      "order by login";
  }
  elsif ($q_name eq "select_users_to_enable")
  {
    $sql = "select us_pk, login, contact_fname, contact_lname from " .
      "contact, usersec where con_pk=con_fk and type = 'disabled' order by" .
      " login ";
  }
  elsif ($q_name eq "get_orgs_by_user")
  {
    my $us_fk = $args[0];
    my $org_pk = $args[1];
    if (is_administrator($dbh, $us_fk))
    {
      $sql = "select org_pk, org_name from organization";
    }
    else
    {
      $sql = "select org_pk, org_name from organization, org_usersec_link " .
        "where org_fk=org_pk and us_fk = '$us_fk' ";
    }
    $sql .= " and org_pk = $org_pk" if ($org_pk);
  }
  elsif ($q_name eq "get_orgs_by_org_curator")
  {
    my $us_fk = $args[0];
    $sql = "select org_pk, org_name from organization, org_usersec_link " .
      "where org_fk=org_pk and us_fk = '$us_fk' and curator = 't' ";
  }
  elsif ($q_name eq "get_users_by_org")
  {
    my $org_fk = $args[0];
    $sql = "select us_pk, login, contact_fname, contact_lname, curator " .
      "from org_usersec_link, usersec, contact where us_fk=us_pk and " .
      "con_fk=con_pk and org_fk='$org_fk' order by lower(contact_fname), " .
      "lower(contact_lname)";
  }
  elsif ($q_name eq "get_not_users_by_org")
  {
    my $org_fk = $args[0];
    $sql = "select us_pk, login, contact_fname, contact_lname from " .
      "usersec, contact where con_fk=con_pk and us_pk not in (select " .
      "us_fk from org_usersec_link where org_fk ='$org_fk') order by " .
      "lower(contact_fname), lower(contact_lname)";
  }
  elsif ($q_name eq "is_org_curator")
  {
    my $us_fk = $args[0];
    my $org_pk = $args[1];
    $sql = "select curator from org_usersec_link where us_fk='$us_fk'";
    if ($org_pk > 0)
    {
      $sql .= " and org_fk=$org_pk";
    }
  }
  elsif ($q_name eq "select_all_organizations")
  {
    $sql = "select * from organization";
  }
  elsif ($q_name eq "select_organization_by_name")
  {
    my $org_name = $args[0];
    $sql = "select * from organization where org_name='$org_name'";
  }
  elsif ($q_name eq "select_organization")
  {
    my $org_fk = $args[0];
    $sql = "select * from organization where org_pk='$org_fk'";
  }
  elsif ($q_name eq "get_orders_by_org")
  {
    my $org_fk = $args[0];
    $sql = "select * from order_info where org_fk='$org_fk'";
  }
  elsif ($q_name eq "select_remove_orgs")
  {
    $sql = "select org_name from organization where org_pk not in " .
      "(select distinct(org_fk) from org_usersec_link)";
  }
  elsif ($q_name eq "get_org_logos")
  {
    $sql = "select org_name, logo_fi_fk, org_url, file_name from " .
      "organization, file_info where logo_fi_fk=fi_pk and display_logo " .
      "= 't' and file_name like '%Upload/logo%'";
  }
  elsif ($q_name eq "select_remove_user")
  {
    $sql = "select us_pk, login, contact_fname, contact_lname from " .
      "contact, usersec where con_pk=con_fk and us_pk not in (select " .
      "distinct(us_fk) from groupref) order by login";
  }
  elsif ($q_name eq "select_user_login")
  {
    $sql = "select login, contact_fname, contact_lname
             from usersec, contact where con_fk = con_pk
             order by login";
  }
  elsif ($q_name eq "select_user_list")
  {
    my $pi_key = $args[0];
    $sql = "select distinct(login), contact_fname, contact_lname from " .
      "usersec, contact, pi_sec where con_fk = con_pk and us_pk = us_fk " .
      "and pi_key = '$pi_key' order by login";
  }
  elsif ($q_name eq "select_user_not_list")
  {
    my $pi_key = $args[0];
    $sql = "select distinct(login), contact_fname, contact_lname from " .
      "usersec, contact, pi_sec where con_fk = con_pk and us_fk = us_pk " .
      "and us_fk not in (select us_fk from pi_sec where pi_key = " .
      "'$pi_key') order by login";
  }
  elsif ($q_name eq "select_pi_list")
  {
    my $us_fk = $args[0];
    $sql = "select distinct(login), contact_fname, contact_lname from " .
      "usersec, contact, pi_sec where con_fk = con_pk and us_pk = pi_key " .
      "and us_fk = '$us_fk' order by login";
  }
  elsif ($q_name eq "select_pi_not_list")
  {
    my $us_fk = $args[0];
    $sql = "select distinct(login), contact_fname, contact_lname from " .
      "usersec, contact where con_fk = con_pk and us_pk not in (select " .
      "pi_key from pi_sec where us_fk = '$us_fk') order by login";
  }
  elsif ($q_name eq "select_exp")
  {
    my $us_fk = $args[0];
    my $where_clause;
    my $from_clause;
    ($from_clause, $where_clause) = read_where_clause("exp_condition", 
        "ec_pk", $us_fk);
    $sql = "select ec_pk,name,sty_fk,study_name
      from exp_condition,study,$from_clause
      where $where_clause  and sty_fk=sty_pk order by lower(study_name),
      lower(name)";
  }
  elsif ($q_name eq "select_exp_loaded")
  {
    my $us_fk = $args[0];
    my $where_clause;
    my $from_clause;
    ($from_clause, $where_clause) = read_where_clause("exp_condition", 
      "ec_pk", $us_fk);
    $sql = "select distinct ec_pk, name, sty_fk, study_name from ( " .
      "select ec_pk,name,sty_fk,study_name from exp_condition,study," .
      "sample,arraymeasurement, $from_clause where $where_clause  and " .
      "sty_fk=sty_pk and smp_pk = smp_fk and ec_pk = ec_fk and is_loaded " .
      "= 't' order by lower(study_name),lower(name))t";
  }
  elsif ($q_name eq "get_hyb_info_extract")
  {
    $sql = "select arraylayout.name, am_comments, smp_name, contact_lname,
     contact_fname from arraymeasurement, arraylayout, sample, groupref, 
     contact, usersec where groupref.ref_fk = smp_pk and con_pk
     = groupref.us_fk and groupref.us_fk = usersec.us_pk and smp_fk=smp_pk and
     al_pk=al_fk and hybridization_name=?";
  }
  elsif ($q_name eq "get_abbrev_name")
  {
    $sql = "select abbrev_name from exp_condition where ec_pk=?";
  }
  elsif ($q_name eq "get_spot_identifier")
  {
    $sql = "select als_pk,spot_identifier, usf_name from " .
  	  "al_spots,arraymeasurement, usersequencefeature  where ". 
  	  "al_spots.al_fk=arraymeasurement.al_fk and " . 
  	  "al_spots.usf_fk=usersequencefeature.usf_pk and am_pk=?";
  }
  elsif ($q_name eq "get_signal")
  {
    $sql = "select als_fk,signal from am_spots_mas5 where am_fk=?";
  }
  elsif ($q_name eq "get_file_names_by_us_fk")
  {
    # see get_input_files below
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("file_info", "fi_pk", 
      $us_fk);
    $sql = "select fi_pk,file_name, fi_checksum, fi_comments from 
      file_info, $fclause where $wclause order by file_name";
  }
  elsif ($q_name eq "get_exp_cond")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("exp_condition", 
      "ec_pk", $us_fk );
    $sql = "select * from exp_condition,$fclause where sty_fk=? and $wclause
      order by ec_pk";
  }
  elsif ($q_name eq "get_sample")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("sample", "smp_pk", $us_fk);
    $sql = "select * from sample,$fclause where oi_fk=? and $wclause order" .
     " by smp_pk";
  }
  elsif ($q_name eq "get_ec_by_ec_pk")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("exp_condition", "ec_pk",
        $us_fk);
    $sql = "select * from exp_condition,$fclause where ec_pk=? and $wclause ".
      "order by ec_pk";
  }
  elsif ($q_name eq "get_sample_by_smp_pk")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("sample", "smp_pk", $us_fk);
    $sql = "select * from sample,$fclause where smp_pk=? and $wclause ".
      "order by smp_pk";
  }
  elsif ($q_name eq "order_info_by_oi_pk")
  {
    $sql = "select * from order_info where oi_pk=?";
  }
  elsif ($q_name eq "orders_by_order_number")
  {
    # from choose_order_curator.cgi
    $sql = "select * from order_info order by order_number desc";
  }
  elsif ($q_name eq "billing_info")
  {
    # from choose_order_curator.cgi
    $sql =  "select * from billing where oi_fk=?";
  }
  elsif ($q_name eq "study_info_by_sty_pk")
  {
    $sql = "select * from study where sty_pk=?";
  }
  elsif ($q_name eq "sample_ec_and_study")
  {
    # from choose_order_curator.cgi
    $sql = "SELECT timestamp, exp_condition.name as ec_name, abbrev_name," .
      " study.study_name, study.sty_pk FROM sample, exp_condition, study" .
      " WHERE study.sty_pk=exp_condition.sty_fk AND" .
      " exp_condition.ec_pk=sample.ec_fk AND smp_pk=?";
  }
  elsif ($q_name eq "sample_count")
  {
    # from choose_order_curator.cgi
    $sql = "select count(smp_pk) from sample where oi_fk=?";
  }
  elsif ($q_name eq "am_sample_order_info_unloaded")
  {
    # from choose_order_curator.cgi
    $sql = " SELECT hybridization_name, smp_pk, am_pk, al_fk, qc_fk
             FROM arraymeasurement, sample, order_info WHERE oi_pk=? AND
             order_info.oi_pk=sample.oi_fk AND
             arraymeasurement.smp_fk=sample.smp_pk and (is_loaded = 'f' 
             or is_loaded is NULL) ORDER BY smp_pk,am_pk";
  }
  elsif ($q_name eq "am_sample_order_info")
  {
    # from choose_order_curator.cgi
    $sql = " SELECT hybridization_name, smp_pk, am_pk, al_fk, qc_fk
     FROM arraymeasurement, sample, order_info WHERE oi_pk=? AND
     order_info.oi_pk=sample.oi_fk AND
     arraymeasurement.smp_fk=sample.smp_pk ORDER BY smp_pk,am_pk";
  }
  elsif ($q_name eq "al_pk_by_am_pk")
  {
    $sql = "select al_fk from arraymeasurement where am_pk=?";
  }
  elsif ($q_name eq "al_name")
  {
    # from choose_order_curator.cgi
    # get_data1.pl
    $sql = "select arraylayout.name as al_name from arraylayout where al_pk=?";
  }
  elsif ($q_name eq "user_list")
  {
    $sql = "select con_pk,contact_fname,contact_lname from contact " .
      "order by contact_lname,contact_fname";
  }
  elsif ($q_name eq "user_pi_us_fk")
  {
    $sql = "select pi_key as pi_us_fk, (select login from usersec " . 
      "where us_pk=pi_key) as pi_login from usersec,pi_sec where us_pk=? " .
      "and us_fk=us_pk";
  }
  elsif ($q_name eq "user_pi")
  {
    $sql = "select gs_owner,gs_pk, gs_name, contact_fname, contact_lname
  	from grouplink,groupsec,contact where us_fk=? and gs_pk=gs_fk and 
  	gs_owner in (select pi_key from pi_sec where us_fk=?) and gs_owner=con_pk";
  }
  elsif ($q_name eq "update_pi_key")
  {
    $sql = "update pi_sec set pi_key=? where us_fk=? and pi_key=?";
  }
  elsif ($q_name eq "get_an_fks_for_specfied_ft_name")
  {
    $sql = "select an_fk from analysis_filetypes_link, filetypes " .
      "where ft_fk = ft_pk and ft_name =? and input = 't' ";
  }
  elsif ($q_name eq "get_ft_name_for_specified_an_pk")
  {
    $sql = "select ft_name from analysis_filetypes_link, filetypes, " .
      "analysis where an_pk = an_fk and ft_fk = ft_pk and arg_name " .
      "like '--outfile' and an_pk = ?";
  }
  elsif ($q_name eq "get_an_fk_for_node")
  {
    $sql = "select an_fk from node where node_pk = ?";
  }
  elsif ($q_name eq "login_us_fk")
  {
    $sql = "select us_fk as user_us_fk,pi_key as user_pi_key,(select " .
      "login from usersec where us_pk=pi_key) as pi_login from pi_sec, " .
      "usersec where login=? and us_fk=us_pk";
  }
  elsif ($q_name eq "oi_pk_number_all")
  {
    $sql = "select oi_pk,order_number, (select contact_fname || ' ' || " .
      "contact_lname from contact,groupref where ref_fk=oi_pk and " .
      "us_fk=con_pk) as pi_name, (select  gs_name from groupsec,groupref " .
      "where ref_fk=oi_pk and gs_fk=gs_pk) as pi_group from order_info " .
      "order by order_number desc";
  }
  elsif ($q_name eq "owner_info")
  {
    $sql = "select us_fk,gs_fk,login from groupref,usersec where ref_fk=? " .
      "and us_pk=us_fk";
  }
  elsif ($q_name eq "get_layout_spot")
  {
    $sql = "SELECT als_pk,spot_identifier FROM al_spots WHERE al_fk=?";
  }
  elsif ($q_name eq "insert_am")
  {
    $sql = "insert into arraymeasurement
#  	(type, description, release_date, submission_date, smp_fk,instance_code,is_loaded,al_fk,am_comments) 
  	  values (trim(?),trim(?),?,?,?,trim(?),'f',?,trim(?))";
  }
  elsif ($q_name eq "select_qc_fk_by_am_pk")
  {
    $sql = "select qc_fk from arraymeasurement where am_pk=?";
  }
  elsif ($q_name eq "select_qc_fk_by_smp_fk")
  {
    $sql = "select qc_fk from arraymeasurement where smp_fk=?";
  }
  elsif ($q_name eq "delete_quality_control")
  {
    # Used in two places.
    $sql = "delete from quality_control where qc_pk=?";
  }
  elsif ($q_name eq "delete_arraymeasurement")
  {
    $sql = "delete from arraymeasurement where am_pk=?";
  }
  elsif ($q_name eq "delete_arraymeasurement_by_smp_fk")
  {
    $sql = "delete from arraymeasurement where smp_fk=?";
  }
  elsif ($q_name eq "select_study_name_pk_by_smp_pk")
  {
    $sql = "select  study_name, sty_pk from study, exp_condition, sample " .
      "where sty_pk=sty_fk and ec_pk=ec_fk and smp_pk=?"; 
  }
  elsif ($q_name eq "select_sample_by_sty_pk")
  {
    $sql = "select smp_pk from sample, exp_condition " .
       " where ec_fk=ec_pk and sty_fk=? order by smp_pk";
  }
  elsif ($q_name eq "select_sample_by_oi_fk")
  {
    $sql = "select smp_pk from sample where oi_fk=? order by smp_pk";
  }
  elsif ($q_name eq "select_sample_by_ec_fk")
  {
    $sql = "select smp_pk from sample where ec_fk=? order by smp_pk";
  }
  elsif ($q_name eq "select_ecs_by_sty_pk")
  {
    $sql = "select ec_pk from exp_condition where sty_fk=? order by ec_pk";
  }
  elsif ($q_name eq "select_am_pk_by_smp_fk")
  {
    $sql = "select am_pk from arraymeasurement where smp_fk=?";
  }
  elsif ($q_name eq "delete_sample")
  {
    # This assumes that security checks have been done.
    $sql = "delete from sample where smp_pk=?";
  }
  elsif ($q_name eq "delete_order_info")
  {
    # This assumes that security checks have been done.
    $sql = "delete from order_info where oi_pk=?";
  }
  elsif ($q_name eq "delete_exp_condition")
  {
    # This assumes that security checks have been done.
    $sql = "delete from exp_condition where ec_pk=?";
  }
  elsif ($q_name eq "check_write_permissions")
  {
    # 0200=128 0020=16 Only return u+w or g+w records
    $sql = "select ref_fk from groupref where ref_fk=?and " .
      "(((permissions & 128) > 0) or ((permissions & 16) > 0))";
  }
  elsif ($q_name eq "select_groupref")
  {
    $sql = "select * from groupref where ref_fk=?";
  }
  elsif ($q_name eq "delete_groupref")
  {
    # Delete one record from groupref, only if u+w or r+w
    $sql = "delete from groupref where ref_fk=? and " . 
      "(((permissions & 128) > 0) or ((permissions & 16) > 0))";
  }
  elsif ($q_name eq "delete_study")
  {
    $sql = "delete from study where sty_pk=?";
  }
  elsif ($q_name eq "all_study_ec_pk")
  {
    # There is a slightly different select_ec_pk below.
    $sql = "select ec_pk from exp_condition where sty_fk=?";
  }
  elsif ($q_name eq "oi_pk_by_number")
  {
    $sql = "select oi_pk from order_info where order_number=?";
  }
  elsif ($q_name eq "select_fi")
  {
    $sql = "select fi_pk from file_info where file_name=?";
  }
  elsif ($q_name eq "select_tree")
  {
    my $us_fk  = $args[0];
    (my $fclause, my $wclause) = write_where_clause("tree", "tree_pk", $us_fk );
    $sql = "select tree_name,tree_pk from tree,$fclause where $wclause " .
      "order by tree_name";
  }
  elsif ($q_name eq "select_tree_nc")
  {
    my $us_fk  = $args[0];
    (my $fclause, my $wclause) = write_where_clause("tree", "tree_pk", $us_fk );
    $sql = "SELECT tree_name, tree_pk, number_of_nodes FROM tree, $fclause,"
      . " (SELECT COUNT(tree_fk) AS number_of_nodes, tree_fk FROM node " .
      "GROUP BY tree_fk) AS node_count WHERE node_count.tree_fk=tree_pk " .
      "AND $wclause ORDER BY tree_name";
  }
  elsif ($q_name eq "select_tree_nc_by_pk")
  {
    my $us_fk  = $args[0];
    (my $fclause, my $wclause) = write_where_clause("tree", "tree_pk", $us_fk );
    $sql = "SELECT tree_name, tree_pk, number_of_nodes FROM tree, $fclause,"
      . "(SELECT COUNT(tree_fk) AS number_of_nodes, tree_fk FROM node " .
      " GROUP BY tree_fk) AS node_count WHERE tree_pk=? AND ". 
      " node_count.tree_fk=tree_pk AND $wclause ORDER BY tree_name";
  }
  elsif ($q_name eq "get_tree_root_node")
  {
    my $us_fk  = $args[0];
    (my $fclause, my $wclause) = write_where_clause("tree", "tree_pk", $us_fk );
    $sql = "select node_pk, tree_name from node,tree,$fclause where " .
      "tree_pk=? and tree_pk=tree_fk and parent_key=-1 and $wclause";
  }
  elsif ($q_name eq "insert_tree")
  {
    $sql = "insert into tree (tree_name, fi_input_fk) values (?,?)";
  }
  elsif ($q_name eq "insert_tree_node")
  {
    $sql = "insert into node (tree_fk,parent_key,an_fk) values (?,?,?)";
  }
  elsif ($q_name eq "read_tree")
  {
    my $us_fk  = $args[0];
    (my $fclause, my $wclause) = read_where_clause("tree", "tree_pk", $us_fk );
    $sql = "SELECT tree_name, node_pk, an_name, parent_key, an_fk, " .
      " version, an_type FROM tree, node, analysis, $fclause WHERE " .
      " tree_pk=? AND tree_pk=tree_fk AND an_fk=an_pk AND $wclause " .
      " ORDER BY node_pk";
  }
  elsif ($q_name eq "update_tree_node")
  {
    $sql = "update node set an_fk=? where node_pk=?"
  }
  elsif ($q_name eq "select_layout")
  {
    $sql = "select name from arraylayout order by name";
  }
  elsif ($q_name eq "select_analysis")
  {
    $sql = "select * from analysis order by an_name";
  }
  elsif ($q_name eq "delete_tree")
  {
    $sql = "delete from tree where tree_pk=?";
  }
  elsif ($q_name eq "delete_tree_node")
  {
    $sql = "delete from node where node_pk=?";
  }
  elsif ($q_name eq "default_an_pk")
  {
    $sql = "select min(an_pk) from analysis"; # By convention, insert Quality Control (the default) first
  }
  elsif ($q_name eq "get_input_files")
  {
    # see get_file_name above.
    #
    # Yes, we show the user a list of all files they can read. This 
    # may include other user's files, and I'm not sure that reading 
    # other user's file repositories works.
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("file_info", "fi_pk", 
        $us_fk);
    $sql = "select fi_pk, file_name from file_info,$fclause where " .
      "$wclause and use_as_input order by file_name";
  }
  elsif ($q_name eq "update_tree_name")
  {
    $sql = "update tree set tree_name=trim(?) where tree_pk=?";
  }
  elsif ($q_name eq "update_order_user")
  {
    # experiment set providers only get to write 2 fields in order_info
    $sql = "update order_info set pi_us_fk=?, pi_gs_fk=? where oi_pk=?";
  }
  elsif ($q_name eq "update_billing_code")
  {
    $sql = "update billing set billing_code=trim(?) where oi_fk=?";
  }
  elsif ($q_name eq "get_billing_code")
  {
    $sql = "select billing_code from billing where oi_fk=?";
  }
  elsif ($q_name eq "hybs_readable")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("arraymeasurement", 
      "am_pk", $us_fk);
    $sql = "select am_pk, smp_fk, am_comments, hybridization_name, " .
      "al_fk  from arraymeasurement, $fclause where $wclause";
  }
  elsif ($q_name eq "hybs_readable_plus")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("arraymeasurement", 
      "am_pk", $us_fk);
    $sql = "select study_name, hybridization_name, smp_name, am_pk " .
      "from arraymeasurement, study, exp_condition, sample, $fclause " .
      "where $wclause and ec_pk=ec_fk and smp_pk=smp_fk and sty_fk = " .
      "sty_pk and is_loaded = 't' order by lower(study_name), lower " .
      "(smp_name), lower(hybridization_name)";
  }
  elsif ($q_name eq "hybs_readable_for_condition")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("arraymeasurement", 
      "am_pk", $us_fk);
    $sql = "select name, hybridization_name, am_pk, ec_pk, sty_fk, " .
      "notes, study_name, smp_name, smp_origin, smp_manipulation " .
      "from arraymeasurement, study, exp_condition, sample, $fclause " .
      "where $wclause and sty_fk = sty_pk and ec_pk=ec_fk and " .
      "smp_pk=smp_fk and ec_pk=?";
  }
  elsif ($q_name eq "hyb_owner_info")
  {
    $sql = "select usersec.login,contact.contact_fname, " .
      "contact.contact_lname from sample,groupref,usersec,contact " .
      "where smp_pk=? and groupref.ref_fk=smp_pk and " .
      "contact.con_pk=groupref.us_fk and groupref.us_fk=usersec.us_pk";
  }
  elsif ($q_name eq "sample_info")
  {
    $sql = "SELECT ec_pk, notes, abbrev_name, description, smp_name" .
      " FROM sample, exp_condition WHERE sample.smp_pk=? AND " . 
      " sample.ec_fk=exp_condition.ec_pk";
  }
  elsif ($q_name eq "insert_am_spots_mas5")
  {
    $sql = "insert into am_spots_mas5 (als_fk,am_fk,statpairs," .
      "statpairsused,signal,detection,detectionp) values (?,?,?,?,?,?,?)";
  }
  elsif ($q_name eq "insert_am_spots_mas4")
  {
    $sql = "insert into am_spots_mas4 (als_fk,am_fk,positive,negative, " .
      "pairsused,pairsinavg,positivefraction,logavg,avgdiff,abscall) " .
      "values (?,?,?,?,?,?,?,?,?,?)";
  }
  elsif ($q_name eq "qc_list")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("arraymeasurement", 
      "am_pk", $us_fk );
    $sql = "select qc_fk,hybridization_name from arraymeasurement," .
      "$fclause where $wclause and qc_fk is not null";
  }
  elsif ($q_name eq "get_qc_secure")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("arraymeasurement", 
      "am_pk", $us_fk );
    $sql = "select *,hybridization_name from quality_control, " .
      "arraymeasurement,$fclause where $wclause and qc_pk=? and qc_fk=qc_pk";
  }
  elsif ($q_name eq "get_qc")
  {
    $sql = "select *,hybridization_name from quality_control,
      arraymeasurement where qc_pk=? and qc_fk=qc_pk";
  }
  elsif ($q_name eq "get_qc_housekeeping")
  {
    $sql = "select control_name,control_value from housekeeping_control 
      where qc_fk=?";
  }
  elsif ($q_name eq "hyb_info")
  {
    $sql = "select am_pk,hybridization_name,al_fk from arraymeasurement 
      where am_pk=?";
  }
  elsif ($q_name eq "sample_chip_check")
  {
    $sql = "select count(am_pk) from arraymeasurement where smp_fk=? 
      and (al_fk is null or al_fk=0)";
  }
  elsif ($q_name eq "order_ec_check")
  {
    $sql = "select count(smp_pk) from sample where oi_fk=? and ((ec_fk is
      null) or (ec_fk = 0))";
  }
  elsif ($q_name eq "order_owner_info")
  {
    $sql = "SELECT usersec.login, contact.contact_fname,
      contact.contact_lname, contact.contact_phone, usersec.us_pk
      FROM order_info, groupref, usersec, contact WHERE 
      order_info.oi_pk=? AND groupref.ref_fk=oi_pk AND
      contact.con_pk=groupref.us_fk AND groupref.us_fk=usersec.us_pk";
  }
  elsif ($q_name eq "insert_study")
  {
    $sql = "insert into study (study_name, sty_comments, created_by) values
      (trim(?), trim(?), ?)";
  }
  elsif ($q_name eq "get_study_info")
  {
    $sql = "select study_name, sty_comments, created_by from study 
      where sty_pk = ?";  
  }
  elsif ($q_name eq "select_miame_types")
  {
    $sql = "select miame_type_pk, miame_type_name from miame_type";
  }
  elsif ($q_name eq "all_studies")
  {
    $sql = "select study_name from study order by study_name";
  }
  elsif ($q_name eq "all_trees")
  {
    $sql = "select tree_name from tree order by tree_name";
  }
  elsif ($q_name eq "studies_i_can_read")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("study", "sty_pk", $us_fk );
    $sql = "select study_name, sty_pk, sty_comments from study,$fclause 
      where $wclause order by lower(study_name), lower(sty_comments)";
  }
  elsif ($q_name eq "studies_i_can_read_loaded")
  {
    my $us_fk = $args[0];
    (my $fclause, my $wclause) = read_where_clause("study", "sty_pk", $us_fk );
    $sql = "select study_name, sty_pk, sty_comments, is_loaded from 
      study, sample, arraymeasurement, exp_condition, $fclause 
      where $wclause and sty_fk=sty_pk and smp_pk=smp_fk and ec_pk = 
      ec_fk order by lower(study_name), lower(sty_comments)";
  }
  elsif ($q_name eq "studies_i_own")
  {
    my $us_fk = $args[0];
    $sql = " SELECT study_name, ref_fk, gs_fk,	gs_name,	permissions,
  	  (permissions&256=256) as user_read,
  	  (permissions&128=128) as user_write,
  	  (permissions&32=32) as group_read,
  	  (permissions&16=16) as group_write
      FROM study,groupref,groupsec WHERE groupref.us_fk=$us_fk AND
    	groupref.gs_fk=groupsec.gs_pk AND
    	(groupref.us_fk=groupsec.gs_owner OR
    	groupsec.gs_pk=groupsec.gs_owner) AND
    	ref_fk=sty_pk ORDER BY study_name";
  }
  elsif ($q_name eq "select_dis_name")
  {
    $sql = "select dis_pk,dis_name from disease";
  }
  elsif ($q_name eq "select_gs_name")
  {
    my $us_fk = $args[0];
    $sql = "select gs_pk,gs_name from groupsec where gs_owner=$us_fk";
  }
  elsif ($q_name eq "insert_security")
  {
    # 
    # 2003-02-10 Tom: Make arg order same as update below.
    #
    $sql = "insert into groupref (us_fk, gs_fk, permissions, ref_fk) 
      values (?,?,?,?)";
  }
  elsif ($q_name eq "update_security")
  {
    my $us_fk = $args[0];
    $sql = "update groupref set us_fk=?, gs_fk=?, permissions=? 
      where ref_fk=? and us_fk=$us_fk";
  }
  elsif ($q_name eq "update_security_curator")
  {
    $sql = "update groupref set us_fk=?, gs_fk=? permissions=? where ref_fk=?";
  }
  elsif ($q_name eq "groupref_table_name")
  {
    $sql = "SELECT * from (
        SELECT count(*), 'smp_pk' as table from sample where smp_pk=$args[0]
        UNION
        SELECT count(*), 'spc_pk' as table from species where spc_pk=$args[0]
        UNION
        SELECT count(*), 'sty_pk' as table from study where sty_pk=$args[0]
        UNION
        SELECT count(*), 'ec_pk' as table from exp_condition where ec_pk=$args[0]
        UNION
        SELECT count(*), 'am_pk' as table from arraymeasurement where am_pk=$args[0]
        UNION
        SELECT count(*), 'al_pk' as table from arraylayout where al_pk=$args[0]
        UNION
        SELECT count(*), 'qc_pk' as table from quality_control where qc_pk=$args[0]
        UNION
        SELECT count(*), 'oi_pk' as table from order_info where oi_pk=$args[0]
        UNION
        SELECT count(*), 'fi_pk' as table from file_info where fi_pk=$args[0]
        UNION
        SELECT count(*), 'tree_pk' as table from tree where tree_pk=$args[0]
        UNION
        SELECT count(*), 'node_pk' as table from node where node_pk=$args[0])
        as table_select where count>0 
        ";
  }
  elsif ($q_name eq "select_ec_pk")
  {
    $sql = "select ec_pk,permissions from exp_condition,groupref 
      where sty_fk=? and ref_fk=ec_pk";
  }
  elsif ($q_name eq "orders_i_own")
  {
    my $us_fk = $args[0];
    $sql = "SELECT order_number, ref_fk, gs_fk,	gs_name,	permissions,
  	  (permissions&256=256) as user_read, (permissions&128=128) as user_write,
  	  (permissions&32=32) as group_read, (permissions&16=16) as group_write
      FROM order_info,groupref,groupsec WHERE groupref.us_fk=$us_fk AND
    	groupref.gs_fk=groupsec.gs_pk AND (groupref.us_fk=groupsec.gs_owner 
      OR groupsec.gs_pk=groupsec.gs_owner) AND ref_fk=oi_pk ORDER BY 
    	order_number";
  }
  elsif ($q_name eq "select_smp_pk")
  {
    $sql = "select smp_pk,permissions from sample,groupref where oi_fk=? 
      and ref_fk=smp_pk";
  }
  elsif ($q_name eq "select_am_pk")
  {
    # used in session_lib::lock_order() 
    # also used in chgrp_order2.cgi::set_sample_hyb_perms()
    $sql = "select am_pk,permissions from arraymeasurement,groupref 
      where smp_fk=? and ref_fk=am_pk";
  }
  elsif ($q_name eq "files_i_own")
  {
    my $us_fk = $args[0];
    $sql = " SELECT file_name, ref_fk, gs_fk,	gs_name,	permissions,
    	(permissions&256=256) as user_read, (permissions&128=128) as user_write,
    	(permissions&32=32) as group_read, (permissions&16=16) as group_write
      FROM file_info,groupref,groupsec WHERE groupref.us_fk=$us_fk AND
    	groupref.gs_fk=groupsec.gs_pk AND (groupref.us_fk=groupsec.gs_owner 
      OR groupsec.gs_pk=groupsec.gs_owner) AND ref_fk=fi_pk ORDER BY 
    	file_name";
  }
  elsif ($q_name eq "match_checksum")
  {
    $sql = "select file_name from file_info where fi_checksum=?";
  }
  elsif ($q_name eq "default_upv")
  {
    $sql = "select upn_pk,up_type,up_default from user_parameter_names 
      where an_fk=?";
  }
  elsif ($q_name eq "insert_upv")
  {
    $sql = "insert into user_parameter_values (node_fk, up_value, upn_fk) 
      values (?,?,?)";
  }
  elsif ($q_name eq "default_spv")
  {
    $sql="select spn_pk,sp_default from sys_parameter_names where an_fk=?";
  }
  elsif ($q_name eq "insert_spv")
  {
    $sql = "insert into sys_parameter_values (node_fk, sp_value, spn_fk) 
      values (?,?,?)";
  }
  elsif ($q_name eq "get_upn")
  {
    $sql = "select * from user_parameter_names,user_parameter_values 
      where node_fk=? and upn_pk=upn_fk order by upn_pk";
  }
  elsif ($q_name eq "get_spn")
  {
    $sql = "select * from sys_parameter_names,sys_parameter_values 
      where node_fk=? and spn_pk=spn_fk";
  }
  elsif ($q_name eq "update_upv")
  {
    $sql = "update user_parameter_values set up_value=? where upv_pk=?";
  }
  elsif ($q_name eq "select_an_fk")
  {
    $sql = "select an_fk from node where node_pk=?";
  }
  elsif ($q_name eq "delete_upv")
  {
    $sql = "delete from user_parameter_values where node_fk=?";
  }
  elsif ($q_name eq "delete_spv")
  {
    $sql = "delete from sys_parameter_values where node_fk=?";
  }
  elsif ($q_name eq "select_upv_files")
  {
    $sql = "select node_pk, up_display_name, up_value, an_name from 
      analysis, node, user_parameter_names, user_parameter_values 
      where tree_fk=? and upn_pk=upn_fk and node_fk = node_pk and 
      up_type='file' and user_parameter_names.an_fk = an_pk";
  }
  elsif ($q_name eq "order_report")
  {
    $sql = "select order_number, oi_pk, billing_code, us_fk, 
      contact_fname || ' ' || contact_lname as contact_name, 
      contact_phone from order_info o, billing b, groupref g, 
      contact c where o.oi_pk=b.oi_fk and o.oi_pk=g.ref_fk 
      and c.con_pk=g.us_fk order by order_number desc";
  }
  elsif ($q_name eq "distinct_al_where_oi_pk")
  {
    $sql = "select distinct al_pk,name as al_name from order_info, 
      sample, arraymeasurement,arraylayout where oi_pk=oi_fk and 
      smp_fk=smp_pk and al_fk=al_pk and oi_pk=? order by name asc";
  }
  # write_log("sql: $sql");
  if (defined($sql))
  {
    $sth = $dbh->prepare($sql);
    return $sth;
  }
  else
  {
    my $temp = $DBI::errstr; # quiet compiler warnings
    die "Query $q_name not found in sql_lib getq()\n";
  }
}

sub doq
{
  my $dbh = $_[0];
  my $q_name = $_[1];
  #
  # All args after [1] are used by individual queries.
  # We assume the query knows what it is doing.
  #
  if (! defined($dbh))
  {
    die "Database handle undefined in sql_lib getq()\n";
  }

  if ($q_name eq "am_pk_list_where_smp_fk")
  {
    my $smp_fk = $_[2];
    my @am_pk_list;
    my $sth = $dbh->prepare("select am_pk from arraymeasurement 
        where smp_fk=$smp_fk");
    $sth->execute();
    while( (my $am_pk) = $sth->fetchrow_array())
    {
      push(@am_pk_list, $am_pk);
    }
    return @am_pk_list;
  }
  elsif ($q_name eq "insert_fi")
  {
    my $file_name = $_[2];
    my $fi_comments = $_[3];
    my $fi_checksum = $_[4];
    my $conds = $_[5];
    my $cond_labels = $_[6];
    my $node_fk = $_[7]; 
    my $ft_fk = $_[8]; 
    my $last_modified = $_[9];
    my $al_fk = $_[10];
    my $sql = "insert into file_info (file_name, fi_comments, 
      fi_checksum, conds, cond_labels, node_fk, ft_fk, al_fk, 
      last_modified) values (trim(?), trim(?), trim(?), trim(?), 
      trim(?), ?, ?, ?, ?)";
    (my $sth = $dbh->prepare($sql));
    $sth->execute( $file_name,
      $fi_comments,
      $fi_checksum,
      $conds,
      $cond_labels,
      $node_fk,
      $ft_fk,
      $al_fk,
      $last_modified);
  }
  elsif ($q_name eq "update_fi")
  {
    my $fi_comments = $_[2];
    my $fi_checksum = $_[3];
    my $conds = $_[4];
    my $cond_labels = $_[5];
    my $node_fk = $_[6];
    my $ft_fk = $_[7];
    my $last_modified = $_[8];
    my $fi_pk = $_[9];
    my $al_fk = $_[10];
    my $sql = "update file_info set al_fk=?, fi_comments=trim(?), 
      fi_checksum=?, conds=trim(?), cond_labels=trim(?), node_fk=?, 
      ft_fk=?, last_modified=? where fi_pk=?";
    (my $sth = $dbh->prepare($sql));
    $sth->execute($al_fk, $fi_comments, $fi_checksum, $conds,
      $cond_labels, $node_fk, $ft_fk, $last_modified, $fi_pk); 
  }
  elsif ($q_name eq "update_security_curator")
  {
    my $us_fk = $_[2];
    my $gs_fk = $_[3];
    my $permissions = $_[4];
    my $ref_fk = $_[5];
    my $sth = getq("update_security_curator", $dbh);
    $sth->execute($us_fk, $gs_fk, $permissions, $ref_fk);
  }
  elsif ($q_name eq "fi_update_for_move")
  {
    my $old_file_name = $_[2];
    my $new_file_name = $_[3];
    ((my $fi_pk) = $dbh->selectrow_array("select fi_pk from file_info 
      where file_name='$old_file_name'")); 
    $dbh->do("update file_info set file_name='$new_file_name' where 
      fi_pk=$fi_pk");
     return $fi_pk;
  }
  elsif ($q_name eq "count_pis_for_user")
  {
    my $us_fk = $_[2];
    my ($count) = $dbh->selectrow_array("select count(*) from pi_sec where
      us_fk = '$us_fk'"); 
    return($count);
  }
  elsif ($q_name eq "insert_pi_key")
  {
    my $us_fk = $_[2];
    my $pi_key = $_[3];
    $dbh->do("insert into pi_sec (us_fk,pi_key) values ($us_fk, 
      $pi_key)"); 
  }
  elsif ($q_name eq "remove_pi_key")
  {
    my $us_fk = $_[2];
    my $pi_key = $_[3];
    $dbh->do("delete from pi_sec where us_fk = '$us_fk' and pi_key =
      '$pi_key'"); 
  }
  elsif ($q_name eq "get_us_pk")
  {
    my $login = $_[2];
    (my $us_pk) = $dbh->selectrow_array("select us_pk from usersec 
        where login='$login'"); 
    return $us_pk;
  }
  elsif( $q_name eq "get_login")
  {
    my $us_pk = $_[2];
    (my $login) = $dbh->selectrow_array("select login from usersec 
        where us_pk='$us_pk'"); 
    return $login;
  }
  elsif ($q_name eq "insert_contact")
  {
    #
    # 2003-07-10 Tom: SQL has stopped parsing Perl's ctime() output
    # so use native SQL function instead. It it more reliable anyway.
    # 
    my $type = $dbh->quote($_[2]);
    my $organization = $dbh->quote($_[3]);
    my $contact_fname = $dbh->quote($_[4]);
    my $contact_lname = $dbh->quote($_[5]);
    my $contact_phone = $dbh->quote($_[6]);
    my $contact_email = $dbh->quote($_[7]);
    my $department = $dbh->quote($_[8]);
    my $building = $dbh->quote($_[9]);
    my $room_number = $dbh->quote($_[10]);
    my $org_phone = $dbh->quote($_[11]);
    my $org_email = $dbh->quote($_[12]);
    my $org_mail_address = $dbh->quote($_[13]);
    my $org_toll_free_phone = $dbh->quote($_[14]);
    my $org_fax = $dbh->quote($_[15]);
    my $url = $dbh->quote($_[16]);
    my $credentials = $dbh->quote($_[17]);

    my $ins_sql = "INSERT INTO contact (type, organization, " .
      "contact_fname, contact_lname, contact_phone, contact_email, " .
      "department, building, room_number, org_phone, org_email, " .
      "org_mail_address, org_toll_free_phone, org_fax, url, " .
      "last_updated, credentials) values ($type,$organization," . 
      "$contact_fname,$contact_lname,$contact_phone,$contact_email," .
      "$department, $building, $room_number, $org_phone, $org_email," .
      "$org_mail_address, $org_toll_free_phone, $org_fax, $url," .
      "now(),$credentials)";

    eval {
        $dbh->do($ins_sql);
    };
    return($@);
  }
  elsif ($q_name eq "last_pk_seq")
  {
    #
    # $sql = "select last_value from pk_seq";
    # last_value may not be atomic due to race conditions.
    # currval can only be called in a session after nextval
    #
    (my $temp) = $dbh->selectrow_array("select currval('pk_seq')"); 
    return $temp;
  }
  elsif ($q_name eq "last_guc")
  {
    #
    # last_value may not be atomic due to race conditions.
    # currval can only be called in a session after nextval
    #
    (my $temp) = $dbh->selectrow_array("select currval('guc_seq')");
    return $temp;
  }
  elsif ($q_name eq "insert_adminsec")
  {
    $dbh->do("insert into adminsec (adm_us_pk,con_fk,login,password) 
      values ($_[2],$_[3],trim('$_[4]'),trim('$_[5]'))");
  }
  elsif ($q_name eq "insert_usersec")
  {
    $dbh->do("insert into usersec (us_pk,con_fk,login,password) 
      values ($_[2],$_[3],trim('$_[4]'),trim('$_[5]'))");
  }
  elsif ($q_name eq "insert_groupsec")
  {
    $dbh->do("insert into groupsec (gs_pk, gs_owner, gs_name) 
      values ($_[2], $_[3], trim('$_[4]'))");
  }
  elsif ($q_name eq "insert_grouplink")
  {
    $dbh->do("insert into grouplink (us_fk, gs_fk) 
        values ($_[2], $_[3])");
  }
  elsif ($q_name eq "is_pi")
  {
    ((my $temp) = $dbh->selectrow_array("select count(*) from pi_sec,
      usersec where usersec.login='$_[2]' and us_fk=us_pk and pi_key=
      us_pk"));
    return $temp;
  }
  elsif ($q_name eq "get_study_info")
  {
    my $us_fk = $_[2];
    my $sty_pk = $_[3];
    (my $fclause, my $wclause) = read_where_clause("study", 
        "sty_pk", $us_fk );
    my $sql = "select (contact_fname || ' ' || contact_lname) as " .
      " pi_name, gs_name as pi_group from study,groupsec,contact," .
      "$fclause where sty_pk=$sty_pk and $wclause and ref_fk=sty_pk " .
      "and con_pk=groupref.us_fk and gs_pk=groupref.gs_fk";
    ((my $pi_name, my $pi_group) = $dbh->selectrow_array($sql)); 
    return ($pi_name, $pi_group);
  }
  elsif ($q_name eq "get_order_info")
  {
    my $us_fk = $_[2];
    my $oi_pk = $_[3];
    (my $fclause, my $wclause) = read_where_clause("order_info", 
      "oi_pk", $us_fk );
    my $sql = "select order_number,(contact_fname || ' ' || 
      contact_lname) as pi_name, gs_name as pi_group from order_info,
      groupsec,contact,$fclause where oi_pk=$oi_pk and $wclause and 
      ref_fk=oi_pk and con_pk=groupref.us_fk and gs_pk=groupref.gs_fk";
    ((my $order_number, my $pi_name, my $pi_group) = 
      $dbh->selectrow_array($sql));
    return ($order_number, $pi_name, $pi_group);
  }
  elsif ($q_name eq "num_hybs")
  {
    my $smp_fk = $_[2];
    my $sql = "select count(am_pk) from arraymeasurement where 
      smp_fk=$smp_fk";
    ((my $temp) = $dbh->selectrow_array($sql));
    return $temp;
  }
  elsif ($q_name eq "al_fk_for_smp_pk")
  {
    my $smp_fk = $_[2];
    my $sql = "select min(al_fk) from arraymeasurement, sample 
      where smp_pk = smp_fk and smp_fk=$smp_fk";
    ((my $min) = $dbh->selectrow_array($sql));
    $sql = "select max(al_fk) from arraymeasurement, sample where 
      smp_pk = smp_fk and smp_fk=$smp_fk";
    ((my $max) = $dbh->selectrow_array($sql)); 
    warn "Different arraylayouts for the same sample $smp_fk: al_fk_for_smp_pk" 
      if ($min != $max);
    return $min;
  }
  elsif ($q_name eq "who_owns")
  {
    my $ref_fk = $_[2];
    ((my $us_fk, my $gs_fk, my $contact_name, my $permissions) =
      $dbh->selectrow_array("select us_fk,gs_fk,contact_fname || ' ' 
      || contact_lname,permissions  from groupref,contact where 
      ref_fk=$ref_fk and con_pk=us_fk"));
    return ($us_fk, $gs_fk, $contact_name, $permissions);
  }
  elsif ($q_name eq "order_creator_info")
  {
    my $oi_pk = $_[2];
    (my $hr = $dbh->selectrow_hashref("select login,contact_fname,
      contact_lname from usersec,contact,order_info where oi_pk=$oi_pk 
      and created_by=us_pk and con_pk=us_pk"));
    return ($hr->{login}, $hr->{contact_fname}, $hr->{contact_lname});
  }
  elsif ($q_name eq "study_creator_info")
  {
    my $sty_pk = $_[2];
    (my $hr = $dbh->selectrow_hashref("select login,contact_fname,
      contact_lname, credentials from usersec,contact,study where 
      sty_pk=$sty_pk and created_by=us_pk and con_pk=us_pk")); 
    return ($hr->{login}, $hr->{contact_fname}, $hr->{contact_lname}, 
    $hr->{credentials});
  }
  elsif ($q_name eq "miame_owner_info")
  {
    my $miame_pk = $_[2];
    (my $hr = $dbh->selectrow_hashref("select login,contact_fname,
      contact_lname, credentials, contact_email from usersec,
      contact,miame, groupref where miame_pk=$miame_pk and 
      us_fk=us_pk and miame_pk=ref_fk and con_pk=us_pk")); 
    return ($hr->{login}, $hr->{contact_fname}, $hr->{contact_lname}, 
      $hr->{credentials}, $hr->{contact_email});
  }
  elsif ($q_name eq "get_conds")
  {
    (my $conds = $dbh->selectrow_array("select conds from file_info 
      where fi_pk =$_[2]"));
    return ($conds);
  }
  elsif ($q_name eq "get_chipType")
  {
    (my $chipType = $dbh->selectrow_array("select name from file_info, 
      arraylayout where al_fk=al_pk and  fi_pk =$_[2]"));
    return ($chipType);
  }
  elsif ($q_name eq "get_condsL")
  {
    (my $condsL = $dbh->selectrow_array("select cond_labels from 
      file_info where fi_pk =$_[2]"));
    $condsL =~ tr/ :-/./;
    return ($condsL);
  }
  elsif ($q_name eq "get_al_fk_from_node_fk")
  {
    (my $al_fk = $dbh->selectrow_array("select al_fk from file_info, 
      node, tree where tree_fk=tree_pk  and fi_input_fk = fi_pk and
      node_pk =$_[2]"));
    return ($al_fk);
  }
  elsif ($q_name eq "get_tree_fi_input_fk")
  {
    (my $fi_pk= $dbh->selectrow_array("select fi_input_fk from tree 
      where tree_pk =$_[2]"));
    return ($fi_pk);
  }
  elsif ($q_name eq "get_spn_pk")
  {
    # $_[2] is analysis we want parameter name for and $_[3] is param name 
    (my $spn_pk= $dbh->selectrow_array("select spn_pk from 
      sys_parameter_names where an_fk =$_[2] and sp_name='$_[3]'"));
    return ($spn_pk);
  }
  elsif ($q_name eq "get_node_parent")
  {
    (my $p_key= $dbh->selectrow_array("select parent_key from node 
      where node_pk =$_[2]"));
    return ($p_key);
  }
  elsif ($q_name eq "set_spv")
  {
    # $_[2] is new value, $_[3] is node key, $_[4] is spn_fk
    # warn "set_spv val: $_[2] node $_[3] spn: $_[4]\n";
    $_[2] = $dbh->quote($_[2]);
    ((my $exists) = $dbh->selectrow_array("select count(*) from 
      sys_parameter_values  where node_fk = $_[3] and spn_fk=$_[4]"));
    if ($exists >= 1)
    {
      $dbh->do("update sys_parameter_values set sp_value=$_[2] 
        where node_fk = $_[3] and spn_fk = $_[4]");
    }
    else
    {
      $dbh->do("insert into sys_parameter_values (sp_value, 
        node_fk, spn_fk) values ($_[2], $_[3], $_[4])");
    }
  }
  elsif ($q_name eq "user_info2")
  {
    my $us_pk = $_[2];
    ((my $login) = $dbh->selectrow_array("select login from usersec 
      where us_pk=$us_pk"));
    ((my $fname, my $lname, my $email) = $dbh->selectrow_array("select 
      contact_fname,contact_lname, contact_email from contact where 
      con_pk=$us_pk"));
    return ($login, $fname, $lname, $email);
  }
  elsif ($q_name eq "user_info3")
  {
    my $login = $_[2];
    ((my $us_pk) = $dbh->selectrow_array("select us_pk from usersec 
      where login='$login'")); 
    ((my $fname, my $lname, my $email) = $dbh->selectrow_array("select 
      contact_fname,contact_lname, contact_email from contact where 
      con_pk=$us_pk"));
    return ($login, $fname, $lname, $email);
  }
  elsif ($q_name eq "user_info")
  {
    my $us_pk = $_[2];
    my $gs_pk = $_[3];
    ((my $login) = $dbh->selectrow_array("select login from usersec 
      where us_pk=$us_pk"));
    ((my $fname, my $lname, my $phone, my $email) = 
      $dbh->selectrow_array("select contact_fname,contact_lname,
      contact_phone, contact_email from contact where con_pk=$us_pk"));
    ((my $gs_name) = $dbh->selectrow_array("select gs_name from 
      groupsec where gs_pk=$gs_pk"));
    return ($login, $gs_name, $fname, $lname, $phone, $email);
  }
  elsif ($q_name eq "current_fi_input_fk")
  {
    my $tree_pk = $_[2];
    ((my $fi_input_fk) = $dbh->selectrow_array("select fi_input_fk 
      from tree where tree_pk=$tree_pk"));
    return $fi_input_fk;
  }
  elsif ($q_name eq "study_used_by_sample")
  {
    my $result = 0;
    my $sty_pk = $_[2];
    my $sth = $dbh->prepare("select ec_pk,smp_pk from exp_condition,
      sample where sty_fk=$sty_pk and ec_pk=ec_fk");
    $sth->execute();
    if ($sth->rows() > 0)
    {
      $result = 1;
    }
    return $result;
  }
  elsif ($q_name eq "ec_used_by_sample")
  {
    my $result = 0;
    my $ec_pk = $_[2];
    my $sth = $dbh->prepare("select smp_pk from sample where 
      ec_fk=$ec_pk");
    $sth->execute();
    if ($sth->rows() > 0)
    {
      $result = 1;
    }
    return $result;
  }
  elsif ($q_name eq "sample_used_by_ams")
  {
    my $smp_pk = $_[2];
    my $sth = $dbh->prepare("select is_loaded from arraymeasurement 
      where smp_fk=$smp_pk");
    $sth->execute();
    my $result = 0;
    while( (my $is_loaded) = $sth->fetchrow_array())
    {
      if ($is_loaded)
      {
        $result = 1;
        last;
      }
    }
    return $result;
  }
  elsif ($q_name eq "am_used_by_ams_date")
  {
    # replaces fast_data_count
    my $am_pk = $_[2];
    my ($result) = $dbh->selectrow_array("select date_loaded from 
      arraymeasurement where am_pk=$am_pk");
    return ($result);
  }
  elsif ($q_name eq "am_used_by_ams")
  {
    # replaces fast_data_count
    my $am_pk = $_[2];
    my ($result) = $dbh->selectrow_array("select is_loaded from 
      arraymeasurement where am_pk=$am_pk");
    return ($result);
  }
  elsif ($q_name eq "order_used_by_ams")
  {
    #
    # Fixed 2003-08-12 to take in account that multiple records
    # are probably returned.
    #
    my $oi_pk = $_[2];
    my $sth = $dbh->prepare("select is_loaded from sample,arraymeasurement
    	where oi_fk=$oi_pk and smp_fk=smp_pk");
    $sth->execute();
    my $result = 0;
    while( (my $is_loaded) = $sth->fetchrow_array())
    {
      if ($is_loaded)
      {
        $result = 1;
        last;
      }
    }
    return $result;
  }
  elsif ($q_name eq "get_study_name")
  {
    my $sty_pk = $_[2];
    ((my $study_name) = $dbh->selectrow_array("select study_name 
      from study where sty_pk=$sty_pk"));
    return $study_name;
  }
  elsif ($q_name eq "get_file_name")
  {
    my $fi_pk = $_[2];
    (my $file_name) = $dbh->selectrow_array("select file_name from 
      file_info where fi_pk=$fi_pk");
    return $file_name;
  }
  elsif ($q_name eq "delete_file_info")
  {
    my $fi_pk = $_[2];
    $dbh->do("delete from file_info where fi_pk=$fi_pk");
  }
  elsif ($q_name eq "set_is_loaded")
  {
    my $am_pk = $_[2];
    $dbh->do("update arraymeasurement set is_loaded='t' where 
      am_pk=$am_pk");
  }
  elsif ($q_name eq "set_date_loaded")
  {
    my $am_pk = $_[2];
    $dbh->do("update arraymeasurement set date_loaded=now() where am_pk=$am_pk");
  }
  elsif ($q_name eq "clear_is_loaded")
  {
    my $am_pk = $_[2];
    $dbh->do("update arraymeasurement set is_loaded='f' where 
      am_pk=$am_pk");
  }
  elsif ($q_name eq "oi_pk_sample_and_hyb_count")
  {  
    my $oi_pk = $_[2];
    # count samples in an order
    my $sql = "select count(*), oi_fk from sample where oi_fk=$oi_pk 
      group by oi_fk";
    (my $num_samples) = $dbh->selectrow_array($sql);
    # count hybs in a sample
    $sql = "select count(*) from arraymeasurement, sample where 
      smp_pk=smp_fk and oi_fk=$oi_pk";
    (my $num_hybs) = $dbh->selectrow_array($sql);
    return ($num_samples, $num_hybs);
  }
  elsif ($q_name eq "al_pk_sample_and_hyb_count")
  {  
    my $al_pk = $_[2];
    my $oi_pk = $_[3];
    # count samples using the same arraylayout
    my $sql = "select count(distinct smp_pk) from order_info, sample, 
      arraymeasurement,arraylayout where oi_pk=oi_fk and smp_fk=smp_pk 
      and al_fk=al_pk and al_pk=$al_pk and oi_pk=$oi_pk";
    (my $al_samples) = $dbh->selectrow_array($sql);
    # count hybs for each arraylayout
    $sql = "select count(*) from arraymeasurement, sample where 
      smp_pk=smp_fk and al_fk=$al_pk and oi_fk=$oi_pk";
    (my $al_hybs) = $dbh->selectrow_array($sql);
    return ($al_samples, $al_hybs);
  }
  else
  {
    die "$q_name not found in sub doq() in sql_lib\n";
  }
}

sub doq_get_login
{
  my $dbh = $_[0];
  my $us_pk = $_[1];
  my $sql;

  $sql = "select login from usersec where us_pk=$us_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  (my $login) = $sth->fetchrow_array();
  return $login;
}

#$us_fk is the us_pk of the user currently signed on
#$user_pk is the us_pk of the user we want the password for
sub doq_get_pw
{
  my $dbh = $_[0];
  my $us_pk = $_[1];
  my $user_pk = $_[2];
  my $sql;
   
  $sql = "select password from usersec where us_pk='$user_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  (my $password) = $sth->fetchrow_array();
  return $password;
}

#
# If the old password or us_pk don't match this will silently fail.
# Zero rows will be updated, which is not an SQL error.
# That could be a feature. This should only fail if someone finds a hole
# in the system.
#
sub doq_set_pw
{
  my $dbh = $_[0];
  # password args here are crypted.
  my $us_pk = $_[1];
  my $new_pw = $_[2];
  my $old_pw = $_[3];
  my $sql = "update usersec set password='$new_pw' where us_pk=$us_pk 
    and password='$old_pw'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

#$us_fk is the us_pk  of the user we want the sessionid for
sub doq_get_sessionid
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $sql;
   
  $sql = "select session_id from session where us_fk='$us_fk'";

  my $sth = $dbh->prepare($sql);
  $sth->execute();
  (my $sessionid) = $sth->fetchrow_array();
  return $sessionid;
}

#$sess_id is the session_id of the session we want the sess_pk for
sub doq_get_session_pk
{
  my $dbh = $_[0];
  my $sess_id = $_[1];
  my $sql;
   
  $sql = "select session_pk from session where session_id='$sess_id'";

  my $sth = $dbh->prepare($sql);
  $sth->execute();
  (my $session_pk) = $sth->fetchrow_array();
  return $session_pk;
}

sub doq_get_last_login
{
  my ($dbh, $us_pk) = @_;

  my $sql = "select last_login from usersec where us_pk=$us_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute()  ;
  (my $last_login) = $sth->fetchrow_array();
  return $last_login;
}


sub doq_get_email
{
  my $dbh = $_[0];
  my $con_pk = $_[1];

  my $sql = "select contact_email from contact where con_pk=$con_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  (my $email) = $sth->fetchrow_array();
  return $email;
}

sub doq_edit_org
{
  my $dbh = $_[0];
  my %org = %{$_[1]};

  $org{logo_fi_fk} = 'NULL' if (! $org{logo_fi_fk});
  $org{icon_fi_fk} = 'NULL' if (! $org{icon_fi_fk});
  $org{logo_fi_fk} = 'NULL' if ($org{logo_fi_fk} eq 'None');
  $org{icon_fi_fk} = 'NULL' if ($org{icon_fi_fk} eq 'None');
  my $sql = "update organization set org_description=
    trim('$org{org_description}'),org_phone=trim('$org{org_phone}'), 
    org_url=trim('$org{org_url}'), logo_fi_fk=$org{logo_fi_fk}, 
    icon_fi_fk=$org{icon_fi_fk}, needs_approval='$org{needs_approval}' 
    where org_pk=$org{org_pk}";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_insert_org
{
  my $dbh = $_[0];
  my %org = %{$_[1]};

  $org{logo_fi_fk} = 'NULL' if (! $org{logo_fi_fk});
  $org{icon_fi_fk} = 'NULL' if (! $org{icon_fi_fk});
  $org{chip_discount} = 0 if (! $org{chip_discount});
  my $sql = "insert into organization (org_name, org_description, 
    org_phone, org_url, display_logo, chip_discount, needs_approval) 
    values (trim('$org{org_name}'),trim('$org{org_description}'),
    trim('$org{org_phone}'),trim('$org{org_url}'),'$org{display_logo}',
    $org{chip_discount},'$org{needs_approval}')";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_rm_org_usersec_link
{
  my $dbh = $_[0];
  my %ch = %{$_[1]};

  my $sql = "delete from  org_usersec_link where org_fk = '$ch{org_fk}' 
    and us_fk = '$ch{us_fk}'"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_insert_org_usersec_link
{
  my $dbh = $_[0];
  my %ch = %{$_[1]};

  my $sql = "insert into org_usersec_link (org_fk, us_fk, curator) 
    values ($ch{org_fk},$ch{us_fk},'$ch{curator}')";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_update_lot_number
{
  my ($dbh, $us_fk, $am_pk, $lot_number) = @_; 

  my $sql = "select qc_fk from arraymeasurement where am_pk = $am_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my ($qc_fk) = $sth->fetchrow_array();
  $sql = "update quality_control set lot_number = $lot_number 
    where qc_pk = $qc_fk";
  $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_insert_qc
{
  my $dbh = $_[0];
  my %qc = %{$_[1]};

  my $sql = "insert into quality_control (background, noise,
   scale_factor, percent_present, biob_3_detection, biob_5_detection,
   total_rna_profile, crna_profile) values ($qc{background},
   $qc{noise}, $qc{scale_factor}, $qc{percent_present}, 
   '$qc{biob_3_detection}', '$qc{biob_5_detection}',
   '$qc{total_rna_profile}', '$qc{crna_profile}')";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_insert_housekeeping
{
  my $dbh = $_[0];
  my $qc_pk = $_[1];
  my %qc = %{$_[2]};
  #
  # Put the order in kind of 'backwards' so there is a better match
  # between insert, update, and select.
  #
  my $sql = "insert into housekeeping_control (control_value, 
    control_name, qc_fk) values (?,?,?)";
  my $sth = $dbh->prepare($sql);
    
  #
  # Read the found keys from an array in $qc{control_list}.
  # For a list of possible control probe set names, see
  # session_lib sub parse_rpt
  #
  foreach my $key (@{$qc{control_list}})
  {
    $sth->execute($qc{$key}, $key, $qc_pk);
  }
}

sub doq_update_qc_fk
{
  my $dbh = $_[0];
  my $qc_pk = $_[1];
  my $am_pk = $_[2];

  my $sql = "update arraymeasurement set qc_fk=$qc_pk where am_pk=$am_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_needs_approval
{
  my $dbh = $_[0];
  my $oi_pk = $_[1];

  my $sql = "select order_number, org_fk from order_info where 
    oi_pk='$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($order_number, $org_fk) = $sth->fetchrow_array();
  my $needs_approval;
  if ($org_fk)
  {
    $sql = "select needs_approval from order_info, organization 
      where org_fk=org_pk and oi_pk='$oi_pk'";
    $sth = $dbh->prepare($sql);
    $sth->execute();
    ($needs_approval) = $sth->fetchrow_array();
  }
  $sth->finish();
  return ($needs_approval, $org_fk, $order_number);   
}

sub doq_get_order_locked
{
  my $dbh = $_[0];
  my $oi_pk = $_[1];
  my $sql = "select locked from order_info where oi_pk = '$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $locked = $sth->fetchrow_array();
  $sth->finish();
  return $locked;   
}

sub doq_study_update
{
  my ($dbh, $us_fk, $sty_pk, $hr) = @_;
  my $success = 1;

  my %updates = %$hr;
  
  my $sql = "update study set ";
  my $key;
  foreach $key (keys(%updates))
  {
    if ($updates{$key} eq "NULL")
    {
      $sql .= "$key=$updates{$key}, ";
    }
    else
    {
      my $data = $dbh->quote($updates{$key});
      $sql .= "$key=$data, ";
    }
  }
  chop $sql; chop $sql;# get rid of trailing comma
  $sql .= " where sty_pk = '$sty_pk'";

  my $sth = $dbh->prepare($sql); 
  eval {
    $sth->execute();  
  };

  $success = report_postgres_err($dbh, $us_fk, $@) if ($@);
  return ($success);
}

sub doq_get_org_curs_email
{
  my $dbh = $_[0];
  my $org_pk = $_[1];
  my $sql = "select contact_email from contact, org_usersec_link, 
    usersec where con_pk=con_fk and us_fk=us_pk and curator='t' 
    and org_fk='$org_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my @emails = ();
  my $email;
  while (($email) = $sth->fetchrow_array())
  {
    push @emails, $email if ($email ne "");
  }
  return @emails;   
}

sub doq_unlock_order
{
  my ($dbh, $oi_pk) = @_;
 
  # lock the order 
  my $sql = "update order_info set locked='f' where oi_pk = '$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_order_info_update
{
  my ($dbh, $us_fk, $oi_pk, $hr) = @_;

  my %updates = %$hr;
  
  # lock the order 
  my $sql = "update order_info set ";
  my $key;
  foreach $key (keys(%updates))
  {
    if ($updates{$key} eq "NULL")
    {
      $sql .= "$key=$updates{$key}, ";
    }
    else
    {
      my $data = $dbh->quote($updates{$key});
      $sql .= "$key=$data, ";
    }
  }
  chop $sql; chop $sql;# get rid of trailing comma
  $sql .= " where oi_pk = '$oi_pk'";
  my $sth = $dbh->prepare($sql); 
  $sth->execute();
}

sub doq_insert_order
{
  my ($chref) = @_;
 
  my $us_pk = GEOSS::Session->user->pk;
  my %ch = %$chref;
  ($ch{owner_us_pk}, $ch{owner_gs_pk}) = split(',', $ch{pi_info});

  my $sql = "insert into order_info (created_by,org_fk) " .
    "values ($us_pk,$chref->{select_org})";

  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $oi_pk = insert_security($dbh, $ch{owner_us_pk}, $ch{owner_gs_pk},
      0660);

  $sql = "insert into billing (oi_fk, billing_code, chips_billed, 
    rna_isolation_billed, analysis_billed) 
    values ($oi_pk, trim('$chref->{billing_code}'), '0'::bool, 
    '0'::bool, '0'::bool)";
  $dbh->do($sql);
  $dbh->commit;
  return ($oi_pk);
}

sub doq_update_oi_fk
{
  my ($dbh, $us_fk, $smp_pk, $oi_pk) = @_;
 
  my $sql = "update sample set oi_fk=$oi_pk where smp_pk = '$smp_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute(); 
}

sub doq_lock_order
{
  my ($dbh, $oi_pk) = @_;
 
  my $sql = "update order_info set locked='t' where oi_pk = '$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_approve_order
{
  my ($oi_pk, $org_pk, $comments) = @_;
 
  $comments = $dbh->quote($comments);
  my $sql = "update order_info set is_approved='t', approval_date = 
    now(), approval_comments=$comments where oi_pk = '$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub getq_arraylayout_name_by_al_pk
{
  my ($dbh, $us_fk, $al_pk) = @_;
  my $sql = "select name from arraylayout where al_pk = $al_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($name) = $sth->fetchrow_array();
  $sth->finish();
  return $name;   
}

# returns "" if there are no an_conds in the an_set, otherwise returns
# chiptype of one of the hybridizations in one of the an_conds in the an_set
sub getq_an_set_chiptype
{
  my ($dbh, $us_fk, $an_set_fk) = @_;
  my $sql = "select an_cond_fk from an_set_cond_link where 
    an_set_fk = '$an_set_fk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($an_cond_pk) = $sth->fetchrow_array();
  $sth->finish();
  my $name = "";
  if ($an_cond_pk)
  {
    $name = getq_an_cond_chiptype($dbh, $us_fk, $an_cond_pk);
  }
  return $name;   
}

# returns "" if there are no hybridizations in the condition
# otherwise returns the chip type of one of they hybridizations in 
# the an condition
sub getq_an_cond_chiptype
{
  my ($dbh, $us_fk, $an_cond_fk) = @_;

  # get a hybridization from the condition - we
  # can assume all existing hybridizations in the condition have
  # the same chip type
  my $sql = "select am_fk from an_cond_am_link where 
    an_cond_fk = '$an_cond_fk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($am_pk) = $sth->fetchrow_array();
  $sth->finish();
  my $name = "";
  if ($am_pk)
  {
    $name = getq_chiptype($dbh, $us_fk, $am_pk);
  }
  return $name;   
}

sub getq_chiptype
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $am_pk = $_[2];
  my $sql = "select name from arraymeasurement, arraylayout where 
    al_fk = al_pk and am_pk = '$am_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($name) = $sth->fetchrow_array();
  $sth->finish();
  return $name;   
}

sub getq_email_addys
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $type = $_[2];
  my $sql = "select contact_email from contact where type != 'disabled'";
  if ($type ne "all")
  {
    $sql .= " and type = '$type'";
  }
    
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my @emails = ();
  while (my ($email) = $sth->fetchrow_array())
  {
    push @emails, $email;
  }
  $sth->finish();
  return @emails;   
}

#this function gets the names and logins of people whose group you are in, 
# who may have files that you can read
# Note that you yourself are excluded from the list.  This is because 
# this is intented for use in a select box, and we want the current user
# put first for ease of use
sub getq_readable_file_owners
{
   my $dbh = $_[0];
   my $us_fk = $_[1];
   my $sql = "select login, contact_fname, contact_lname from usersec, 
     contact where con_fk=con_pk and us_pk in (select gs_owner from 
     groupsec,grouplink where gs_pk = gs_fk and us_fk = $us_fk and 
     gs_fk != $us_fk) order by contact_lname, contact_fname";
   my $sth = $dbh->prepare($sql);
   $sth->execute();

   return $sth;   
}

sub getq_cond_info
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $node_fk = $_[2];
  my $sql = "select conds,cond_labels from tree, node, file_info 
    where fi_input_fk=fi_pk and tree_fk = tree_pk and node_pk=$node_fk"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($conds, $cL) = $sth->fetchrow_array();
  $sth->finish();
  return ($conds, $cL);   
}

sub getq_order_owner_login_by_order_number
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $order_number = $_[2];
  my $sql = "select login from usersec, groupref, order_info 
    where oi_pk = ref_fk and us_fk = us_pk and order_number = 
    '$order_number'"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $login = $sth->fetchrow_array();
  $sth->finish();
  return $login;   
}

sub getq_order_notify_emails_by_oi_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $oi_pk = $_[2];
  my @emails = ();
  # owner email
  my $sql = "select contact_email from contact, usersec, groupref,
    order_info where oi_pk = ref_fk and con_pk=con_fk and us_fk = us_pk
    and oi_pk = $oi_pk"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $email = $sth->fetchrow_array();
  push @emails, $email;
  # created_by email

  $sql = "select contact_email from contact, usersec, order_info where
    oi_pk = $oi_pk and created_by = us_pk and con_fk = con_pk";
  $sth = $dbh->prepare($sql);
  $sth->execute();

  $email = $sth->fetchrow_array();
  push @emails, $email;
  $sth->finish();
  return @emails;   
}

sub getq_miame_sty_fk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $miame_pk = $_[2];
  my $sql = "select sty_fk from miame where miame_pk = '$miame_pk'"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $sty_fk = $sth->fetchrow_array();
  $sth->finish();
  return $sty_fk;   
}

sub getq_an_set_pk_by_name
{
  my ($dbh, $us_fk, $an_set_name) = @_;
  my $sql = "select an_set_pk from an_set where an_set_name =
    '$an_set_name'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my @an_set_pks = ();
  while (( my $pk) =  $sth->fetchrow_array())
  {
    push @an_set_pks, $pk;
  }
  $sth->finish();
  return (\@an_set_pks);   
}

sub getq_an_cond_pk_by_name
{
  my ($dbh, $us_fk, $an_cond_name) = @_;
  my $sql = "select an_cond_pk from an_cond where an_cond_name =
    '$an_cond_name'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my @an_cond_pks = ();
  while (( my $pk) =  $sth->fetchrow_array())
  {
    push @an_cond_pks, $pk;
  }
  $sth->finish();
  return (\@an_cond_pks);   
}

sub getq_al_fk_by_oi_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $oi_pk = $_[2];
  my $sql = "select al_fk from arraymeasurement, sample where
    smp_fk=smp_pk and oi_fk='$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($al_fk) = $sth->fetchrow_array();
  my $same = 1;
  while (my $al_fk_next = $sth->fetchrow_array())
  {
    $same = 0 if ($al_fk != $al_fk_next);
  }
  $sth->finish();
  return ($al_fk) if ($same);
  return (0) if (! $same);
}

sub getq_default_sty_fk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $oi_pk = $_[2];
  my $sql = "select default_sty_fk from order_info where oi_pk='$oi_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($default_sty_fk) = $sth->fetchrow_array();
  $sth->finish();
  return ($default_sty_fk);
}

sub getq_order_number_by_oi_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $oi_pk = $_[2];
  my $sql = "select order_number from order_info where oi_pk=$oi_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($order_number) = $sth->fetchrow_array();
  $sth->finish();
  return ($order_number);   
}

sub getq_count_am_pk_by_hyb_name_by_study
{
  my ($hyb_name, $am_pk) = @_;
  my $sql = "select count(am_pk) from arraymeasurement, exp_condition,
    sample where smp_fk=smp_pk and ec_fk=ec_pk and  
    hybridization_name= '$hyb_name' and am_pk != $am_pk and sty_fk =
    (select sty_fk from exp_condition, sample, arraymeasurement where smp_fk
     = smp_pk and ec_fk = ec_pk and am_pk = $am_pk)";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($count) = $sth->fetchrow_array();
  return ($count);   
}

sub getq_owner_group_by_pk
{
  my $dbh = $_[0];
  my $pk = $_[1];
  my $sql = "select us_fk, gs_fk from groupref where ref_fk = $pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($us_pk, $gs_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($us_pk, $gs_pk);   
}

sub getq_als_pk_by_al_fk_and_spot_id
{
  my ($dbh, $us_fk, $al_fk, $spot_id) = @_;
  my $sql = "select als_pk from al_spots where al_fk=$al_fk and
    spot_identifier = '$spot_id'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($als_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($als_pk);   
}

sub getq_oi_pk_by_smp_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $smp_pk = $_[2];
  my $sql = "select oi_fk from sample where smp_pk = '$smp_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($oi_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($oi_pk);   
}

sub getq_am_pks_by_smp_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $smp_pk = $_[2];
  my $sql = "select am_pk from arraymeasurement where smp_fk = '$smp_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my @am_pks = ();
  my $am_pk;
  while (($am_pk) = $sth->fetchrow_array())
  {
    push @am_pks, $am_pk;
  }
  $sth->finish();
  return (\@am_pks);   
}

sub getq_am_pk_by_name
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $name = $_[2];
  my $sql = "select am_pk from arraymeasurement where 
    hybridization_name = '$name'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($am_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($am_pk);   
}

sub getq_al_pk_by_name
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $name = $_[2];
  my $sql = "select al_pk from arraylayout where name = '$name'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($al_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($al_pk);   
}

sub doq_exists_chip
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $al_pk = $_[2];
  my $sql = "select count(*) from arraylayout where al_pk = $al_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($count) = $sth->fetchrow_array();
  $sth->finish();
  return ($count);   
}

sub getq_disease_by_sty_pk_and_opt_dis_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $sty_pk = $_[2];
  my $dis_pk = $_[3];
  my $sql = "select dis_name from disease, disease_study_link where "
    . "dis_fk=dis_pk and sty_fk = $sty_pk";
  if ($dis_pk)
  {
    $sql .= " and dis_pk = $dis_pk";
  }
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my $disease;
  my $dis_str = "";
  while ($disease = $sth->fetchrow_array())
  {
    $dis_str .= "$disease "; 
  }
  $sth->finish();
  return ($dis_str);   
}

sub getq_dis_pk_by_dis_name
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $dis_name = $_[2];
  my $sql = "select dis_pk from disease where dis_name = '$dis_name'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($dis_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($dis_pk);   
}

sub getq_dis_name_by_dis_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $dis_pk = $_[2];
  my $sql = "select dis_name from disease where dis_pk = '$dis_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($dis_name) = $sth->fetchrow_array();
  $sth->finish();
  return ($dis_name);   
}

sub getq_dis_fk_by_sty_fk
{
  my $sty_fk = shift;
  my $sql = "select dis_fk from disease_study_link " . 
   " where sty_fk = $sty_fk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($dis_fk) = $sth->fetchrow_array();
  $sth->finish();
  return ($dis_fk);   
}

sub getq_tree_pk_by_tree_name
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $tree_name = $_[2];
  my $sql = "select tree_pk from tree where tree_name = '$tree_name'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($tree_pk) = $sth->fetchrow_array();
  $sth->finish();
  return ($tree_pk);   
}

sub getq_tree_name_by_tree_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $tree_pk = $_[2];
  my $sql = "select tree_name from tree where tree_pk = $tree_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($tree_name) = $sth->fetchrow_array();
  $sth->finish();
  return ($tree_name);   
}

sub getq_oi_fk_by_am_pk
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $am_pk = $_[2];
  my $sql = "select oi_fk from sample, arraymeasurement where smp_fk=smp_pk
    and am_pk = $am_pk";
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($oi_fk) = $sth->fetchrow_array();
  $sth->finish();
  return ($oi_fk);   
}

sub getq_miame_ana_fi_info
{
  my $dbh = $_[0];
  my $us_fk = $_[1];
  my $miame_pk = $_[2];
  my $sql = "select ana_fi_fk, file_name, conds, cond_labels, al_fk 
    from miame, file_info where fi_pk=ana_fi_fk and 
    miame_pk = '$miame_pk'"; 
  my $sth = $dbh->prepare($sql);
  $sth->execute();

  my ($ana_fi_fk, $file_name, $conds, $cond_labels, $al_fk) = 
    $sth->fetchrow_array();
  $sth->finish();
  return ($ana_fi_fk, $file_name, $conds, $cond_labels, $al_fk);   
}

sub doq_insert_am_spots_mas5
{
  my ($dbh, $us_fk, $als_fk, $am_pk, $signal) = @_;
 
  my $sql = "insert into am_spots_mas5 (als_fk, am_fk, signal) 
    values ($als_fk,$am_pk,$signal)";
  my $sth = $dbh->prepare($sql); 
  $sth->execute();  
}

sub doq_update_sample_attr
{
  my ($dbh, $us_fk, $smp_pk, $field, $value, $type) = @_;

  my $sql; 
  $sql = "update sample set $field='$value' " if ($type eq "text");
  $sql = "update sample set $field=$value " if ($type eq "int");

  $sql .= "where smp_pk = '$smp_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_update_exp_cond_attr
{
  my ($dbh, $us_fk, $ec_pk, $field, $value, $type) = @_;
 
  my $sql;
  $sql = "update exp_condition set $field='$value' " if ($type eq "text");
  $sql = "update exp_condition set $field=$value " if ($type eq "int");

  $sql .= "where ec_pk = '$ec_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_update_sample_name
{
  my ($dbh, $us_fk, $smp_pk, $smp_name) = @_;
 
  my $sql = "update sample set smp_name ='$smp_name' 
    where smp_pk = '$smp_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_update_num_am
{
  my ($dbh, $us_fk, $smp_pk, $new_num) = @_;
 
  my ($owner_pk, $group_pk) = getq_owner_group_by_pk($dbh, $smp_pk); 
  my $cur_num = 0;
  $cur_num = $dbh->selectrow_array(
     "select count(*) from arraymeasurement where smp_fk=$smp_pk");
 
  if ($cur_num < $new_num)
  {
    my $al_fk = determine_default_al_fk_for_sample($dbh, $us_fk, $smp_pk);
    my $i;
    for ($i = $cur_num; $i < $new_num; $i++)
    {
      my $sql = "insert into arraymeasurement (smp_fk, al_fk)
        values ($smp_pk, $al_fk)";
      $dbh->do("$sql");
      insert_security($dbh, $owner_pk, $group_pk, 432);
    }
  }
  elsif ($cur_num > $new_num)
  {
    if ($new_num > 0)
    {
      # delete hybridizations
      my $sql = "select am_pk from arraymeasurement where 
        smp_fk = $smp_pk and (is_loaded is NULL or is_loaded = 'f') 
        limit " . ($cur_num - $ new_num);
      my $sth = $dbh->prepare($sql);
      $sth->execute();
    
      my $am_pk;
      while (($am_pk) = $sth->fetchrow_array() )
      {
        $dbh->do("delete from arraymeasurement where am_pk = $am_pk");
      }
    }
    else
    {
      set_return_message($dbh, $us_fk, "message", "errmessage",
          "ERROR_NEEDS_HYB");
    }
  }
}

sub doq_update_al_fk
{
  my ($dbh, $us_fk, $smp_pk, $al_fk) = @_;
 
  my $sql = "update arraymeasurement set al_fk ='$al_fk' where 
    smp_fk = '$smp_pk'";
  my $sth = $dbh->prepare($sql); 
  $sth->execute();
}

sub doq_update_ec_fk
{
  my ($dbh, $us_fk, $smp_pk, $ec_fk) = @_;
 
  my $sql = "update sample set ec_fk ='$ec_fk' where smp_pk = '$smp_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
}

sub doq_update_order_number
{
  my ($dbh, $us_fk, $oi_pk, $order_number) = @_;
 
  my $curnum = getq_order_number_by_oi_pk($dbh, $us_fk, $oi_pk);
  if ($curnum)
  {
    set_return_message($dbh, $us_fk, "message","errmessage",
      "ERROR_ASSIGN_ORDER_NUMBER", $curnum);
  }
  else
  {
    my $sql = "update order_info set order_number = '$order_number' 
      where oi_pk=$oi_pk";
    my $sth = $dbh->prepare($sql);
    $sth->execute(); 
    set_return_message($dbh, $us_fk, "message","goodmessage",
      "SUCCESS_ASSIGN_ORDER_NUMBER", $order_number);
  }
}

sub doq_set_miame_ana_fi_fk
{
  my ($dbh, $us_fk, $miame_pk, $ana_fi_fk) = @_;
 
  my $sql = "update miame set ana_fi_fk='$ana_fi_fk' where 
    miame_pk = '$miame_pk'";
  my $sth = $dbh->prepare($sql);
  $sth->execute(); 
}

sub getq_can_write_x {
  my $dbh = shift;
  my $us_fk = shift;
  my $table = shift;
  my $pk = shift;

  my ($fc, $wc) = write_where_clause($table, $pk, $us_fk);
  my $sql = "select $pk from $table, $fc where " . join(' and ', $wc, @_);
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my ($ok) = $sth->fetchrow_array;
  return defined($ok);
}

sub getq_can_read_x {
  my $dbh = shift;
  my $us_fk = shift;
  my $table = shift;
  my $pk = shift;

  my ($fc, $wc) = read_where_clause($table, $pk, $us_fk);
  my $sql = "select $pk from $table, $fc where " . join(' and ', $wc, @_);
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my ($ok) = $sth->fetchrow_array;
  return defined($ok);
}

sub getq_can_read_filename 
{
  my $dbh = shift;
  my $us_fk = shift;
  my $fn = shift;

  my $condition = "file_name = " . $dbh->quote($fn);
  return getq_can_read_x($dbh, $us_fk, 'file_info', 'fi_pk', $condition);
}

sub getq_files_like 
{
  my $dbh = shift;
  my $us_fk = shift;

  my ($fc, $wc) = read_where_clause('file_info', 'fi_pk', $us_fk);
  return $dbh->prepare(
    "select fi_pk,file_name from file_info, $fc where $wc" 
      . ' and file_name like ?');
}

1;
