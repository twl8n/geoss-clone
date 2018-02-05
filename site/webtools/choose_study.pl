use strict;
use CGI;
use GEOSS::Database;
use GEOSS::Session;
use GEOSS::Experiment::Study;

require "$LIB_DIR/geoss_session_lib";

my $debug;
my $q = new CGI;

my $us_fk = GEOSS::Session->user->pk;

if (is_public($dbh, $us_fk))
{
  GEOSS::Session->set_return_message("errmessage", "INVALID_PERMS");
  my $url = index_url($dbh, "webtools");
  print "Location: $url\n\n";
}
else
{
  my ($allhtml, $loop_template) = readtemplate("choose_study.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html"); 
  foreach my $study (reverse (GEOSS::Experiment::Study->new_list()))
  {
    next if (! $study->can_write);
    my $chref = $study->info;
    if (($chref->{status} eq "COMPLETE") || 
        ($chref->{status} eq "INCOMPLETE"))
    {
      $chref->{delete} = qq!
        <tr>
          <td width="30%" valign="top">
            <form action="delete_study1.cgi" method="post">
              <div align="right">
                <input type="submit" name="submit" value="Delete Array Study">
                <input type="image" border="0" name="imageField2" src="../graphics/trash.gif" width="25" height="25">
                <input type="hidden" name="sty_pk" value="$chref->{pk}">
              </div>
            </form>
          </td>
          <td width="70%" valign="top">&nbsp;</td>
        </tr>
          !;
      }
    # check writeable
    $chref->{number_of_conditions} = @{$chref->{exp_conditions}};

    my $loop_instance = $loop_template; 
    $loop_instance =~ s/{(.*?)}/$chref->{$1}/g;
    $allhtml =~ s/<loop_here>/$loop_instance\n<loop_here>/;
  }

  my $chref;
  $chref->{htmltitle} = "Choose Array Study";
  $chref->{html} = set_help_url($dbh,"edit_or_delete_an_existing_array_study");
  $chref->{htmldescription} = "Select an array study to edit.";
  $chref->{message} .= get_stored_messages($dbh, $us_fk);     
  my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};

  # substitute fields outside the loop, especially am_pk
  $allhtml =~ s/{(.*?)}/$ch{$1}/g; 
  $allhtml =~ s/<loop_here>//; # remove lingering template loop tag

  print "Content-type: text/html\n\n$allhtml\n";
}
