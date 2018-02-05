use strict;
use GEOSS::Database;
use GEOSS::Terminal;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_sql_lib";

# prepare by linking the file:
# ln /var/brf-data/Archive\ Data/login/file.CAB /var/lib/geoss/login/Data_Files
# /order_number/file.CAB

main:
{
    print "Enter file owner (GEOSS login):\n";
    my $owner = <STDIN>;
    chomp ($owner);

    print "Enter file (complete path -- sorry, no tab complete):\n";
    my $file = <STDIN>;
    chomp ($file);

    if (! -f "$file")
    {
      die "The specified file does not exist";
    }

    my $sql = "select us_pk from usersec where login='$owner'";
    my $sth  = $dbh->prepare($sql) || warn "prepare $sql $DBI::errstr";
    $sth->execute() || warn "execute $sql $DBI::errstr";
    my $ref;
    $ref = $sth->fetchrow_hashref();
    $sth->finish();

    fi_update($dbh, $ref->{us_pk}, $ref->{us_pk}, $file, "", "", "", undef, 0, undef, 288, undef);
    $dbh->commit();
    $dbh->disconnect();
}

sub usage
{
   print "geoss_file_insert\n";
   exit 1;
}
