use strict;
use GEOSS::Database;
use GEOSS::Terminal;
require "$LIB_DIR/geoss_session_lib";
require "$LIB_DIR/geoss_sql_lib";

main:
{
    my $input = shift || ask_user("Enter study name\n");

    my $sql = "select distinct(order_number) from order_info, sample, " .
     " exp_condition, study where study_name = '$input' and sty_fk = " .
     "sty_pk and ec_fk = ec_pk and oi_fk=oi_pk";

    my $sth  = $dbh->prepare($sql);
    $sth->execute();
    my $ord_str;
    my $ref;
    while ($ref = $sth->fetchrow_hashref())
    {
      $ord_str .= $ref->{order_number};
    }
    $dbh->disconnect();
    print $ord_str . "\n";
}

sub usage
{
   print "geoss_get_ord_num <study_name>\n";
   exit 1;
}
