use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my %ch = $q->Vars();
    my $dbh=new_connection();
    my $us_fk = get_us_fk($dbh, "webtools/user_password1.cgi");

    # if you need to use a loop template, you can't use the get_allhtml
    # function to read your html and do message substitutions.  You need
    # to uncomment the get_all_subs_vals call, the s/, and the read_template

    # my ($allhtml, $loop_template, $tween, $loop_template2) = read_template(
    # "user_password1.html", "/site/webtools/header.html", "/site/webtools/footer.html");

    my $htmltitle = "Change password";


    $ch{htmltitle} = $htmltitle;
    $ch{help} = set_help_url($dbh, "");
    $ch{htmldescription} = "";

    # %ch = %{get_all_subs_vals($dbh, $us_fk, \%ch)};

    my $allhtml = get_allhtml($dbh, $us_fk, "user_password1.html",
      "/site/webtools/header.html", "/site/webtools/footer.html", \%ch);
    #$allhtml =~ s/{(.*?)}/$ch{$1}/g;
    print $q->header;
    print "$allhtml\n";
    print $q->end_html;
    $dbh->disconnect();
    exit();
}

