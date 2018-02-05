#!/usr/bin/perl -w

=head1 NAME
  
geoss_initialize - does post installation initialization of GEOSS

=head1 SYNOPSIS

./geoss_initialize --db_name=<database_name> --db_user=db_user
   
=head1 DESCRIPTION
  
This script should be run after a make install.  It loads the 
database, adds the administrator user, adds all analyses, and
adds all layouts. 

It finishes by printing out the next installation activities,
including suggested modifications to httpd.conf.

=cut
    
use strict;

use IO::File;
use GEOSS::BuildOptions;
use GEOSS::Database;
use GEOSS::Terminal;
use GEOSS::Util;
use Getopt::Long 2.13;

#command line options
my $db_name = "";
my $db_user = "";

getOptions();

{
  print "Setting database password...\n";
  my $fn = "$WEB_DIR/.geoss";
  my $fh = IO::File->new($fn, 'w', 0600)
    or die "unable to open $fn for writing: $!";
  $fh->print(dbpass_from_user() . "\n");
  use User::pwent;
  my $pw = getpwnam($WEB_USER)
    or die "unable to find user $WEB_USER: $!";
  chown $pw->uid, $pw->gid, $fn
    or die "unable to chown $fn to $WEB_USER: $!";
}

{
  print "Installing schema...\n";
  $dbh->do(slurp_file("$WEB_DIR/database/geoss_schema.sql"));
  $dbh->commit();
}

print "Adding administrator user\n";
system "$BIN_DIR/geoss_adduser --login=admin --password=administrator"
     . " --type=administrator --pi_login=admin --contact_fname=admin"
     . " --contact_lname=admin"
  and warn "Unable to add administrator user.";

print "Adding public user\n";
system "$BIN_DIR/geoss_adduser --login=public --password=public"
     . " --type=experiment_set_provider --pi_login=public"
     . " --contact_fname=public --contact_lname=public"
  and warn "Unable to add public user";

  
{
  print "Installing schema...\n";
  $dbh->do(slurp_file("$WEB_DIR/database/initialize_db.sql"));
  $dbh->commit();
}

print "Adding all analyses\n";
system "$BIN_DIR/geoss_add_all_ana"
  and warn "Unable to load all analyses.";

print "Adding layouts.  This make take a few minutes.\n";
my $layout_path = ask_user(<<'EOF');
Enter the filename (with full path) of the layout tar file or
the directory containing layout files:
EOF
system "$BIN_DIR/geoss_add_all_layouts admin $layout_path"
  or warn "Unable to load all layouts.";

print "\n\n";


print <<EOF;
Your next step is to modify your apache configuration to allow web access and
ExecCGI on $WEB_DIR.  Based on your build parameters, and assuming a default
apache setup, you will need to add the following:

<Directory "$WEB_DIR/site">
  AllowOverride Limit
  Options ExecCGI FollowSymLinks
  Order allow,deny
  Allow from all
</Directory>

After saving your changes, restart the webserver (apachectl restart).
You should now be able to logon to GEOSS by visiting 
  http://<your server>/$GEOSS_DIR/site.
EOF

sub getOptions
{
    my $help;

    if (@ARGV > 0 )
    {
      # format
      # string : 'var=s' => \$var,
      # boolean : 'var!' => \$var,
       
           GetOptions(
                  'db_name=s' => \$db_name,
                  'db_user=s' => \$db_user,
                  'help|?' => \$help,
                  );
    } #have command line args
    usage() if ($db_name eq "");
    usage() if ($db_user eq "");
    usage() if ($help); 

} # getOptions

sub usage
{
      print "Usage: \n";
      print " geoss_initialize --db_name=<db_name> --db_user=<db_user> \n";   
      exit;
} #usage
