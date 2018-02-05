

# todo
# fix load_data1.cgi to send all the file names over in a list of some sort.
# pull the list apart, and assume that load_data1.cgi got things ready.
# copy, load, etc.
#

use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

 main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh = new_connection(); # session_lib
    my $us_fk = get_us_fk($dbh, "curtools/view_qc_curator.cgi");

    if (! get_config_entry($dbh, "array_center"))
    {
      GEOSS::Session->set_return_message("errmessage",
          "ERROR_ARRAY_CENTER_NOT_ENABLED");
      print "Location: " . index_url($dbh, "webtools") . "\n\n";
      exit;
    }

    if (! is_curator($dbh, $us_fk))
    {
      GEOSS::Session->set_return_message("errmessage","INVALID_PERMS");
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs $0");
        print "Location: $url\n\n";
        exit();
    }
    (my $allhtml, my $loop_template) = readtemplate("view_qc_curator.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    my $sth = getq("get_qc", $dbh);
    $sth->execute($ch{qc_pk}) || die "execute get_qc\n$DBI::errstr\n";
    my $hr = $sth->fetchrow_hashref();
    $sth->finish();
    foreach my $key (keys(%{$hr}))
    {
	$ch{$key} = $hr->{$key};
    }


    $sth = getq("get_qc_housekeeping", $dbh);
    $sth->execute($ch{qc_pk}) || die "execute get_qc_controls\n$DBI::errstr\n";
    while($hr = $sth->fetchrow_hashref())
    {
	my $loop_instance = $loop_template;
	$loop_instance =~ s/{(.*?)}/$hr->{$1}/g;
	$allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
    }

    $allhtml =~ s/<loop_here>//s;
    if ($ch{state} == 0)
    {
	#
	# State zero is the full order list. The action URL used by the form tag
	# in load_data2.html is pretty simple in this case.
	#
	$ch{action_url} = "choose_order_curator.cgi";
    }
    else
    {
	# 
	# The only other state is 1, and this is the single order case.
	# Build a action URL for show1_curator.cgi.
	#
	$ch{action_url} = "show1_curator.cgi";
    }
    #
    # order_number is a hidden field, and needs to be filled in from %ch
    #

    $ch{oi_form} = oi_form($dbh); # see session_lib
    $ch{htmltitle} = "View Quality Control";
    $ch{help} = set_help_url($dbh, "view_qc");
    %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print "Content-type: text/html\n\n$allhtml\n";
    $dbh->disconnect();
    exit(0);

}

