

# Step 1.
# You must create /var/lib/pgsql/p.dat
# with the postgres password in clear text.
# Make that file 600 rw------- so that only postgres can read it.
# This script will exit if the permissions are not 0600.

# Step 2.
# Run from cron.
# Copy the lines below to /var/lib/pgsql/crontab.txt
# Uncomment the last line the command lines (the lines that begin with zero).
# Leave the other comments for reference
# Do:
# crontab crontab.txt
# Verify with:
# crontab -l
# (that is dash ell)


# field          allowed values
# -----          --------------
# minute         0-59
# hour           0-23
# day of month   1-31
# month          1-12 (or names, see below)
# day of week    0-7 (0 or 7 is Sun, or use names)
# Run analyze at zero minutes, 03:00 every day except the 1st.
# 0 3 2-31 * * /var/www/html/geoss/site/webtools/vacuum.cgi -a

# Run full at zero minutes, 03:00 only on the 1st of the month.
# 0 3 1 * * /var/www/html/geoss/site/webtools/vacuum.cgi -f


# Step 3.
# The results are in a log file
# /var/lig.pgsql/vacuum.log


use strict;
use CGI;
use DBI;

my $p_file = "/var/lib/pgsql/p.dat"; # clear text password
my $e_file = "/var/lib/pgsql/vacuum.log"; # log file

main:
{
    my $passwd;
    if ($ENV{LOGNAME} ne "postgres")
    {
	die "This vacuum script can only be run as user postgres\n";
    }

    #
    # Put the password in an external file. That file must be postgres read-only.
    #
    if (-e $p_file)
    {
	my @statlist = stat($p_file);
	if (($statlist[2] & 07777) ne 0600)
	{
	    print "File $p_file has wrong permissions. Exiting\n";
	    exit(1);
	}
	$passwd = `cat $p_file`;
    }
    else
    {
	print "Cannot find $p_file. Exiting.\n";
	exit(1);
    }
    chomp($passwd);

    #
    # AutoCommit must be 1 to disable transactions. VACUUM by its nature must perform
    # its own internal commits, and therefore it cannot be part of another transaction.
    #
    my $connect_string  = "dbi:Pg:dbname=geoss;host=localhost;port=5432";
    my $dbargs = {AutoCommit => 1, PrintError => 1};
    my $dbh =  DBI->connect($connect_string,
			    "postgres",
			    "$passwd",
			    $dbargs);
    
    # write_log("Connected...");
    my $sth;
    my $start;
    my $end;
    my $date = `date`;
    chomp($date);
    # 
    # Analyze does normal and analyze.
    #
    if ($ARGV[0] eq '-a')
    {
	$sth = $dbh->prepare("vacuum analyze");
	$start = time();
	$sth->execute();
	$end = time();
	my $va_time = $end - $start;
	write_log("Vaccuum analyze: $va_time seconds on $date");
    }
    elsif ($ARGV[0] eq '-f')
    {
	#
	# Full does not do an analyze.
	#
	$sth = $dbh->prepare("vacuum full");
	$start = time();
	$sth->execute();
	$end = time();
	my $vf_time = $end - $start;
	write_log("Vaccuum full:    $vf_time seconds on $date");
    }
    else
    {
	$sth = $dbh->prepare("vacuum");
	$start = time();
	$sth->execute();
	$end = time();
	my $v_time = $end - $start;
	write_log("Vaccuum normal:  $v_time seconds on $date");
    }

    $dbh->disconnect();
}

sub write_log
{
    open(LOG_OUT, ">> $e_file") || die "Could not open $e_file for write\n";
    print LOG_OUT "$_[0]\n";
    close(LOG_OUT);
    chmod(0600, $e_file);
}
