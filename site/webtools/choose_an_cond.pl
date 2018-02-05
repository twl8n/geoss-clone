use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $debug;
    my $q = new CGI;
    
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "webtools/choose_an_cond.cgi");

    # Show the user a list of analysis conditions that are >>writable<< by the user.
    (my $fclause, my $wclause) = write_where_clause("an_cond", "an_cond_pk", $us_fk);
    my $sql = "select * from an_cond, $fclause where $wclause order by an_cond_pk desc";
    my $sth = $dbh->prepare($sql) || die "Prepare $sql \n$DBI::errstr";
    $sth->execute() || die "Execute $sql \n$DBI::errstr";

    my $allhtml = readfile("choose_an_cond.html", "/site/webtools/header.html", "/site/webtools/footer.html");
    $allhtml =~ s/<loop>(.*)<\/loop>/<loop_here>/s;
    my $loop_template = $1;

    my $chref;
    my $loop_instance; # instance of the $loop_template
    while($chref = $sth->fetchrow_hashref())
    {

      #create short description
      $chref->{an_cond_desc} = substr($chref->{an_cond_desc}, 0, 40);
      $chref->{an_cond_desc} .= "..." if (length($chref->{an_cond_desc}) > 39);

      ## Get number of ams in an_cond
      $chref->{number_of_hybridizations} = get_number_ams_in_an_cond($chref->{an_cond_pk}, $dbh);

      $loop_instance = $loop_template;
      my $loop_instance = $loop_template;
      $loop_instance =~ s/{(.*?)}/$chref->{$1}/g;
      $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;

    }

    $chref->{htmltitle} = "Choose Analysis Condition";
    $chref->{help} = set_help_url($dbh, "edit_existing_analysis_conditions");
    $chref->{htmldescription} = "Choose an analysis condition to edit.";
    my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g; # substitute fields outside the loop
    $allhtml =~ s/<loop_here>//; # remove lingering template loop tag

    print "Content-type: text/html\n\n $allhtml\n";

    $dbh->disconnect;
    exit(0);

}
