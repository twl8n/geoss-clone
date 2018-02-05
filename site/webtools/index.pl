use strict;
use CGI;
use GEOSS::Database;

require "$LIB_DIR/geoss_session_lib";

main:
{
    my $q = new CGI;
    
    my $dbh = new_connection();
    my $us_fk = get_us_fk($dbh, "webtools/index.cgi");
    
    draw_index($dbh, $us_fk, $q);

    $dbh->disconnect;
}

sub draw_index
{
    (my $dbh, my $us_fk, my $q) = @_;

    my %ch = $q->Vars();
    my $load = get_config_entry($dbh, "user_data_load");
    my $load_html = "";
    if ($load)
    {
      $load_html = "<a href=\"study_load.cgi\">Load a study</a><br>";
    }

    if (is_curator($dbh, $us_fk))
    {
	#
	# This is icky, but if we move over to run-time templates, we'll have true conditionals!
	#
    }
    if (! is_public($dbh, $us_fk))
    {
      $ch{mem_html} = mem_html($load_html); 
      $ch{view_qc} = qq!<a href="view_qc1.cgi">View Quality Control records</a><br>!;
      $ch{express_extract} = qq!<a href="express_extract1.cgi">Create a data file containing all data for one study</a><br>!;
    }
    else
    {
      $ch{mem_html} = pub_html(); 
    }

    $ch{htmltitle} = "Member Home";
    $ch{help} = set_help_url($dbh, "user_guide");
    my $allhtml = get_allhtml($dbh, $us_fk, "index.html", "/site/webtools/header.html",
      "/site/webtools/footer.html", \%ch);

    print "Content-type: text/html\n\n$allhtml\n";
}

sub pub_html
{
  my $htmlstr = qq!<b>Array Study Management</b> \
     <table width="700" border="0" cellpadding="3" cellspacing="0"> \
       <tr>\
         <td bgcolor="#88AA88"> \
           <table width="100%" border="0" cellpadding="3" cellspacing="0">  \
             <tr> \
               <td bgcolor="#FFFFFF"> <p> \
                 <a href="study_viewer.cgi">View all studies</a><br>\
               </td> \
             </tr> \
           </table>  \
         </td> \
       </tr>\
     </table><br>!;

  return($htmlstr);
}

sub mem_html
{
  my ($load_html) = @_;

  my $publishing_html = "";
  if (get_config_entry($dbh, "data_publishing"))
  {
    $publishing_html = qq!
      <a href="insert_miame1.cgi">Create publishing information</a> / 
      <a href="choose_miame1.cgi">Edit/Delete/Submit publishing information</a>
      <br>
    !;
  }
  my $htmlstr = qq!<b>Array Study Management</b>  \
       <table width="700" border="0" cellpadding="3" cellspacing="0"> \
         <tr> <td bgcolor="#88AA88"> \
           <table width="100%" border="0" cellpadding="3" cellspacing="0">\
             <tr> <td bgcolor="#FFFFFF"><p> \
               <a href="edit_study.cgi">Create new array study</a> / \
               <a href="choose_study.cgi">Edit/Delete an existing array study</a><br> \
               <a href="study_viewer.cgi">View all studies</a><br> \
               <a href="chgrp_study1.cgi">Change permissions for array studies</a> <br> \
               $load_html $publishing_html\
              <a href="order_viewer.cgi">View all array orders</a><br>\
              <a href="chgrp_order1.cgi">Change permissions for array orders</a><br> \
            </td></tr>\
          </table>  \
        </td> </tr> \
      </table><br>!;
  return($htmlstr);
}
