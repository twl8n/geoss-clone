use strict;
use CGI;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    my $es_pk = $q->param("es_pk");
    
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "admintools/index.cgi");
    if (! is_administrator($dbh, $us_fk))
    {
        set_session_val($dbh, $us_fk, "message", "errmessage",
          get_message("INVALID_PERMS"));
        my $url = index_url($dbh, "webtools"); # see session_lib
        write_log("error: non administrator runs admintools/index.cgi");
        print "Location: $url\n\n";
        exit();
    }
   
    draw_index($dbh, $us_fk, $q);

    $dbh->disconnect;
}

sub draw_index
{
    (my $dbh, my $us_fk, my $q) = @_;

    my $headerfile = "/site/webtools/header.html";
    my $footerfile = "/site/webtools/footer.html";

    my %ch = $q->Vars();

    $ch{htmltitle} = "GEOSS Administrator Interface";
    $ch{help} = set_help_url($dbh, "admin_gui");
    $ch{htmldescription} = "These links can be used by a GEOSS administrator to configure GEOSS.\n";  

    if (get_config_entry($dbh, "array_center"))
    {
    $ch{special_center} = qq!
<b>Special Center Administration</b>
<table width="600" border="0" cellpadding="3" cellspacing="0">
  <tr>
    <td bgcolor="#7c0000">
      <table width="100%" border="0" cellpadding="3" cellspacing="0">
        <tr>
          <td bgcolor="#FFFFFF">
            <p>
        <a href="admin_vieworg.cgi">View all special centers</a><br>
        <a href="admin_addorg.cgi">Add a special center</a><br>
        <a href="admin_removeorg.cgi">Delete a special center</a><br>
 <p>These links can be used to manage special centers.</p>
              <br>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
<br>
!;

    }
    my $allhtml = get_allhtml($dbh, $us_fk, "index.html",
	 "$headerfile", "$footerfile", \%ch);

    print "Content-type: text/html\n\n$allhtml\n";
}
