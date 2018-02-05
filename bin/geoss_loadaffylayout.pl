use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use Getopt::Long;
use vars qw(%options $target_database $array_layout_name $input_excel $gene_name_column $refRow
            $contact $contact_key $array_layout_key %gene_keys $dbh);

require "$LIB_DIR/AffyLayoutReader.pm"; 
import AffyLayoutReader qw(get_next_datarow);

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $sql;
    #Get command line options
    my $rc = GetOptions(\%options,
                        "help",
                        "name=s",
                        "genenames=s",
                        "chipcost=s",
                        "input=s",
                        "dbname=s",
                        "provider=i",
                        "login=s",
                        "update",
                        "nocommit",
                        "tab",
                        "speciesid=i");  # a test mode
    my $USAGE = <<"EOU";
  usage: $0 [options] --name=array_layout_name --input=input txt file
    options:
      --name=chip_name
      --dbname=target_database_name
      --login=userid 
      --chipcost=chip_cost
      --nocommit
      --tab
      --speciesid=nn where nn is a number. Human is 50, mouse is 41. See the species table in the database.
      
      For example:
      geoss_loadaffylayout --dbname=geoss --name=hg-u95av2 --input=/var/lib/geoss/layout/hg-u95av2/hg-u95av2.txt --login=mst3k --speciesid=50 --chipcost=400
      
EOU

      die "$USAGE\n" if exists $options{help};
    
    
    die "Bad option: $rc\n$USAGE" unless $rc;
    die "Must specify --name for array layout in database\n" unless exists $options{name};
    warn "No chip cost specified.  Please update arraylayout table when cost is known\n" unless exists $options{chipcost};
    die "Must specify --input filename for array layout\n" unless exists $options{input};
    die "Must specify --speciesid Human is 50, mouse is 41.\n" unless exists $options{speciesid};
    
    $target_database = exists($options{dbname}) ? $options{dbname}
    : "geoss-test";

    $gene_name_column = exists($options{genenames}) ? $options{genenames}
    : "none";

    if (exists($options{nocommit})) {
        print "Changes will not be committed, nocommit option used, test run only. \n";
    }
    
    my $date = `date`;
    chomp($date);
    print "$0 starts at $date with options:\n";
    my $opt;
    foreach $opt (keys %options)
    {
        print "$opt: $options{$opt}\n";
    }
    
    
    #
    #Connect to input file
    #
    print "Instantiating AffyLayoutReader  ";
    my $ofh = select(STDOUT); $| = 1; select($ofh);
    my $arraylayoutreader = new AffyLayoutReader ($options{input});
    print "[OK]\n";
    #
    #Set up array layout shell in database
    #
    
    print "Creating connection  ";
    $ofh = select(STDOUT); $| = 1; select($ofh);
    print "[OK]\n";
    
    #
    # aug 19 2002 Tom: don't make user enter numeric userid. Allow them to enter a login (aka userid) and get
    # the numeric id from usersec. Remember, groupsec,usersec and contact all share the same primary key
    #
    $sql = "select us_pk from usersec where login='$options{login}'";
    ($contact_key) = $dbh->selectrow_array($sql);

    
    my $us_fk = $contact_key;
    my $array_layout;
    my $array_layout_key;
    if (exists($options{update}))
    {
        my $al_sql = "select al_pk from arraylayout where name=?";
        my $al_sth = $dbh->prepare($sql) || die "$al_sql\n$DBI::errstr\n";
        $al_sth->execute($options{name}) || die "$al_sql\n$DBI::errstr\n";
        if ($al_sth->rows() > 1)
        {
            die "Multiple array layouts with name $options{name}\n";
        }
        if ($al_sth->rows() == 0)
        {
            die "No array layout with name $options{name} to update\n";
        }
        ($array_layout_key) = $al_sth->fetchrow_array() || die "$al_sql\n$DBI::errstr\n"; # $array_layout->al_pk();
        $al_sth->finish();
    }
    else
    {
        print "Instantiating ArrayLayout ";
        $ofh = select(STDOUT); $| = 1; select($ofh);
        #
        # Confirm contact information
        #
        my $sql = "select con_pk from contact where con_pk=$contact_key";
        my $sth = $dbh->prepare($sql) || die "$sql\n$DBI::errstr\n";
        $sth->execute();
        if ($sth->rows() != 1) 
        {
            die "Bad contact key $contact_key. Rows returned: " . $sth->rows() . "\n";
        }
        $sth->finish();
        my %array_layout;
        $array_layout{name} = $options{name};
        $array_layout{technology_type} = 'affymetrix';
        $array_layout{con_fk} = $contact_key;
        #
        # Need to generalize the identifier code...should it just be name? - mpear 7/16/01
        # 2002-02-28 Tom Laudeman
        # This can't be a static string, so I'll make same as name
        #
        $array_layout{identifier_code} = $options{name};
        $array_layout{chip_cost} = $options{chipcost};
        $array_layout{medium} = 'sequence_instance';
        $sql = "insert into arraylayout (name, technology_type, con_fk, identifier_code, medium, chip_cost) values (?, ?, ?, ?, ?, ?)";
        $sth = $dbh->prepare($sql);
        $sth->execute($array_layout{name},
                     $array_layout{technology_type},
                     $array_layout{con_fk},
                     $array_layout{identifier_code},
                     $array_layout{medium},
                     $array_layout{chip_cost});
        #
        # userid and groupid are both of the curator who installed the layout
        #
        my $permissions = 420; # octal 644 rw-r--r-- layouts are world readable.
        $array_layout_key = insert_security($dbh, $us_fk, $us_fk, $permissions);
        print "[OK]\n";
    }
    #
    # aug 16 2002 Tom: instead of instantiating a Bio::GEOSS class, fill in a hash and use DBI/SQL for 
    #
    my %usf;
    $usf{spc_fk} = $options{speciesid};
    $usf{chromosome} = 'affy-human';
    $usf{usf_type} = 'gene_name';
    
    #
    #Set up AL_Spots template
    #
    # al_fk -> newly inserted array_layout
    # usf_fk -> gene inserted for this array layout
    # spot_identifier->SpotID
    # spot_type->sequence_feature or control_dna depending on SpotType
    
    my %al_spot;
    $al_spot{al_fk} = $array_layout_key;
    
    my $num_features=0;
    my $num_blanks=0;
    my $num_genes=0;
    #
    # SQL statements we'll use below. Prepare these to make corresponding _sth vars,
    # except for the seq_new_pk_sql, which gets run without a prepare.
    # Don't Panic.
    #
    my $seq_update_sql     = "update usersequencefeature set usf_name=?, spc_fk=?, chromosome=?, usf_type=?, short_description=?, clone_name=?, other_name=?, other_type=?, start_position=?, end_position=? where usf_pk=?";
    my $seq_insert_sql     = "insert into usersequencefeature (usf_name, spc_fk, chromosome, usf_type, short_description, clone_name, other_name, other_type, start_position, end_position) values (?,?,?,?,?,?,?,?,?,?)";
    my $al_spot_update_sql = "update al_spots set al_fk=?, spot_type=?, spot_identifier=?, usf_fk=? where als_pk=?";
    my $al_spot_insert_sql = "insert into al_spots (al_fk, spot_type, spot_identifier, usf_fk) values (?,?,?,?)";
    my $find_al_spots_sql  = "select als_pk,usf_fk from al_spots where al_fk=$array_layout_key and spot_identifier=?";
    #
    # Old code used last_value, that's not atomic, really.
    # This new code is atomic but assumes that nextval got called in this session, "session" probably means
    # using the current connection e.g. $dbh
    #
    my $seq_new_pk_sql     = "select currval('usersequencefeature_usf_pk_seq')";


    #
    # sth vars for the SQL above
    #
    my $seq_update_sth = $dbh->prepare($seq_update_sql);
    my $seq_insert_sth = $dbh->prepare($seq_insert_sql);
    my $al_spot_update_sth = $dbh->prepare($al_spot_update_sql);
    my $al_spot_insert_sth = $dbh->prepare($al_spot_insert_sql);
    my $find_al_spots_sth = $dbh->prepare($find_al_spots_sql);
        
    my $do_update;
    my $aks_pk;
    my $usf_fk;
    while (defined($refRow = $arraylayoutreader->get_next_datarow()))
    {
        if (($num_genes % 200 == 0) ||
            ($num_features % 200 == 0))
        {
            print "Processed genes: $num_genes features: $num_features\n";
        }
        $do_update = 0;
        if (exists($options{update}))
        {
            #
            # If we are updating, get the als_pk and usf_fk
            # from the record we are updating.
            #
            $find_al_spots_sth->execute($refRow->{SpotID});
            my $found_rows = $find_al_spots_sth->rows();
            if ($found_rows > 1)
            {
                die "Found  $found_rows spots for $refRow->{SpotID}\n";
            }
            if ($found_rows == 0)
            {
                die "No spots for $refRow->{SpotID}\n";
            }            
            ($aks_pk, $usf_fk) = $find_al_spots_sth->fetchrow_array();
            $find_al_spots_sth->finish();
            $do_update = 1;
        }
        #Process Gene Identifiers
        #Insert new gene if unique for this arraylayout addition
        if (! exists $gene_keys{$refRow->{GeneID}})
        {
            #Split up gene description
            $usf{usf_name} = $refRow->{GeneID};
            $usf{short_description} = $refRow->{GeneDescription};
            $usf{chromosome} = 'affy-human';
            $usf{other_type} = ' ';
            if (exists($refRow->{clone}))
            {
                $usf{clone_name} = $refRow->{clone};
            }
            else
            {
                $usf{clone_name} = 'NA';
            }
            #unigene reference
            if (exists($refRow->{ug}))
            {
                $usf{other_name} = $refRow->{ug};
                $usf{other_type} = 'ug';
            }
            else
            {
                $usf{other_name} = $refRow->{GeneID};
                $usf{other_type} = 'gb';
            }
            if (exists($refRow->{cds}))
            {
                my $work = $refRow->{cds};
                $work =~ s/^\(//; $work =~ s/\).*$//;
                my ($start,$end) = split ",",$work;
                if ($start =~ /^\d+$/)
                {
                    $usf{start_position} = $start;
                }
                if ($end  =~ /^\d+$/)
                {
                    $usf{end_position} = $end;
                }
            }
            if ($do_update == 1)
            {
                $gene_keys{$refRow->{GeneID}} = $usf_fk; # usf_fk from the al_spots record we're updating.
                $seq_update_sth->execute($usf{usf_name},
                                         $usf{spc_fk},
                                         $usf{chromosome},
                                         $usf{usf_type},
                                         $usf{short_description},
                                         $usf{clone_name},
                                         $usf{other_name},
                                         $usf{other_type},
                                         $usf{start_position},
                                         $usf{end_position},
                                         $usf_fk);
            }
            else
            {
                my $len = length($usf{short_description});
                if ($len > 500)
                {
		    #
		    # 2004-06-04 twl8n
		    # Stop printing this warning. Why were we warning? Was there a db issue?
		    #
                    # print "Warning: description is $len chars, data line $num_features (+7), $usf{short_description}\n";
                }
                $seq_insert_sth->execute($usf{usf_name},
                                         $usf{spc_fk},
                                         $usf{chromosome},
                                         $usf{usf_type},
                                         $usf{short_description},
                                         $usf{clone_name},
                                         $usf{other_name},
                                         $usf{other_type},
                                         $usf{start_position},
                                         $usf{end_position});

                (($gene_keys{$refRow->{GeneID}}) = $dbh->selectrow_array($seq_new_pk_sql)) || die "$seq_new_pk_sql\n$DBI::errstr\n";
            }
            $num_genes++;
        }
        #
        #Insert or update spot referencing the appropriate inserted gene
        #
        if (! exists($options{update}))
        {
            $al_spot{usf_fk} = ($gene_keys{$refRow->{GeneID}});
        }
        
        $al_spot{spot_type} = $refRow->{SpotType};
        $al_spot{spot_identifier} = $refRow->{SpotID};
        $num_features++;
        if ($do_update == 1)
        {
            $al_spot_update_sth->execute($al_spot{al_fk},
                                         $al_spot{spot_type},
                                         $al_spot{spot_identifier},
                                         $al_spot{usf_fk},
                                         $aks_pk);
        }
        else
        {
            $al_spot_insert_sth->execute($al_spot{al_fk},
                                         $al_spot{spot_type},
                                         $al_spot{spot_identifier},
                                         $al_spot{usf_fk});
        }
    }
    if (exists($options{nocommit}))
    {
        print "*** data not committed, nocommit command line option active***\n";
    }
    else
    {
        $dbh->commit();
    }
    $dbh->disconnect();
    print "Added $num_genes genes, $num_features features on chip, \n";
    exit;
}
