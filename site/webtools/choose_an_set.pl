use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $debug;
    my $q = new CGI;
    
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/choose_an_set.cgi");

    # Show the user a list of sets that are >>writable<< by the user.
    (my $fclause, my $wclause) = write_where_clause("an_set", "an_set_pk", $us_fk);
    my $sql = "select * from an_set, $fclause where $wclause order by an_set_pk desc";
    my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
    $sth->execute() || die "Execute $sql \n$DBI::errstr";

    my $allhtml = readfile("choose_an_set.html", "/site/webtools/header.html", "/site/webtools/footer.html");
    $allhtml =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
    my $loop_template = $1;

    my $chref;
    my $loop_instance; # instance of the $loop_template
    while($chref = $sth->fetchrow_hashref())
    {

      #create short description
      $chref->{an_set_desc} = substr($chref->{an_set_desc}, 0, 40);
      $chref->{an_set_desc} .= "..." if (length($chref->{an_set_desc}) > 39);

      ## Get number of an_conds in set
      $chref->{number_of_conditions} = get_number_an_conds_in_an_set($chref->{an_set_pk}, $dbh);

      $loop_instance = $loop_template;
      my $loop_instance = $loop_template;
      $loop_instance =~ s/{(.*?)}/$chref->{$1}/g;
      $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;

    }

    $chref->{htmltitle} = "Choose Analysis Set";
    $chref->{help} = set_help_url($dbh, "edit_existing_set_of_conditions");
    $chref->{htmldescription} = "Choose an analysis set to edit.";
    my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g; # substitute fields outside the loop
    $allhtml =~ s/<loop_here>//; # remove lingering template loop tag

    print "Content-type: text/html\n\n $allhtml\n";

    $dbh->disconnect;
    exit(0);

}
