use strict;
use GEOSS::Database;
use GEOSS::Terminal;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_sql_lib";
require "$LIB_DIR/geoss_analysis_tree_lib";

main:
{
    my $login = $ARGV[0];

    if (! $login)
    {
        $dbh->disconnect();
        usage();
    }
    
    print "Changing GEOSS password for $login\n";
    
    # get the us_fk for $login
    my $us_fk = doq($dbh, "get_us_pk", $login);
    print "Us_fk for login is $us_fk\n";


    # call a sub to get the passwords.
    my $new_pw = prompt_for_password();
    my $new_crypt_pw = pw_encrypt($ARGV[0], $new_pw);

    # change it
    gvap_update_pw($dbh, $us_fk, $new_crypt_pw);

    print "GEOSS password changed for $login (us_fk=$us_fk).\n";

    $dbh->commit();
    $dbh->disconnect();
}

sub prompt_for_password
{
    $|=1; # disable buffered output
    system("stty -echo");
    my $new1 = '\t'; # non-matching, and something you could never type.
    my $new2 = '\n';

    while($new1 ne $new2 || length($new1) == 0 || length($new2) == 0)
    {
	# prompt for password
	print "new password:";
	$new1 = <STDIN>;
	chomp($new1);
	print "\n"; # the user's \r doesn't echo
	
	# prompt again
	print "new password again:";
	$new2 = <STDIN>;
	chomp($new2);
	print "\n"; # the user's \r doesn't echo
	
	# if they match, return
	if (0 < length($new1) && $new1 eq $new2)
	{
	    $|=0; #enable buffered output
	    system("stty echo");
	    return $new1;
	}
    }
}


sub gvap_get_us_fk
{
    my $q_name = "gvap_get_us_fk";
    my $dbh = $_[0];
    my $login = $_[1];
    my $sql = "select us_pk from usersec where login='$login'";
    my $sth = $dbh->prepare($sql);
    if ($dbh->err()) { 	die "doq $q_name 1\n$DBI::errstr\n";  }
    $sth->execute()  || die "$q_name 2\n$DBI::errstr\n";
    (my $us_fk) = $sth->fetchrow_array();
    return $us_fk;
}

sub gvap_is_curator
{
    my $q_name = "gvap_is_curator";
    my $dbh = $_[0];
    my $login = $_[1];
    my $sql = "select login from contact,usersec where login='$login' and con_pk=us_pk and type='curator'";
    my $sth = $dbh->prepare($sql);
    if ($dbh->err()) { 	die "doq $q_name 1\n$DBI::errstr\n";  }
    $sth->execute()  || die "$q_name 2\n$DBI::errstr\n";
    my $db_login = "";
    ($db_login) = $sth->fetchrow_array();
    if ($db_login && $db_login eq $login)
    {
	return 1;
    }
    else
    {
	return 0;
    }

}

sub gvap_update_pw
{
    my $q_name = "gvap_update_pw";
    my $dbh = $_[0];
    my $us_fk = $_[1];
    my $new_crypt_pw = $_[2];
    my $sql = "update usersec set password='$new_crypt_pw' where us_pk=$us_fk";
    my $sth = $dbh->prepare($sql);
    if ($dbh->err()) { 	die "doq $q_name 1\n$DBI::errstr\n";  }
    $sth->execute()  || die "$q_name 2\n$DBI::errstr\n";
}

sub usage
{
   print "geoss_change_userpw <login>\n";
   exit 1;
}
