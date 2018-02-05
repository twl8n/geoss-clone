use strict;
use CGI;
use GEOSS::Database;
use GEOSS::Session;
use GEOSS::Experiment::Study;

require "$LIB_DIR/geoss_session_lib"; 

my $us_fk = GEOSS::Session->user->pk;

my ($allhtml, $loop_template) = readtemplate("choose_tree.html", 
    "/site/webtools/header.html", "/site/webtools/footer.html");

foreach my $tree (reverse(GEOSS::Analysis::Tree->new_list()))
{
  next if (! $tree->can_write);
  my $hr;
  $hr->{tree_name} = $tree->name; 
  $hr->{tree_pk} = $tree->pk;
  my @nodes = $tree->nodes;
  $hr->{number_of_nodes} = @nodes;
  my $loop_instance = $loop_template;
  $loop_instance =~ s/{(.*?)}/$hr->{$1}/sg;
  $allhtml =~ s/<loop_here>/$loop_instance<loop_here>/s;
}
$allhtml =~ s/<loop_here>//s;

my %ch = %{get_all_subs_vals($dbh, $us_fk, {})};

$ch{htmltitle} = "Choose an Analysis Tree";
$ch{html} =
set_help_url($dbh,"edit_or_delete_or_run_an_existing_analysis_tree");
$ch{htmldescription} = "Select an analysis tree to edit."; 
$allhtml =~ s/{(.*?)}/$ch{$1}/g;

print "Content-type: text/html\n\n$allhtml\n";
$dbh->disconnect();
