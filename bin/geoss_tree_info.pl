use strict;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::User::User;
use GEOSS::Analysis::Tree;

my $pk = shift || ask_user("Enter tree_pk\n");

my $tree = GEOSS::Analysis::Tree->new(pk => $pk)
  or die "Tree ($pk) does not exist";

print "Tree: $tree\tStatus: " . $tree->status .  "\n";

print "Owner: " . $tree->owner . "\tGroup: " .  $tree->group . "\n";

sub usage
{
  print "geoss_tree_info  [tree_pk]\n";
  exit 1;
}
