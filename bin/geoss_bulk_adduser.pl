
=head1 NAME
 
 geoss_bulk_adduser - loads multiple new geoss users

=head1 SYNOPSIS

 ./geoss_bulk_adduser --infile <filename> [--readonly] [--debug]

=head1 DESCRIPTION

geoss_bulk_adduser reads input from a file and uses the input 
to create multiple geoss accounts

The input file contains tab separated columns.  Column headers must be field
names.  The following columns must be present in the file:

=over 10

=item 
login

=item 
type

=item 
pi_login

=back

=over 5

=item 
The following columns may be present:

=back

=over 10

=item 
password

=item 
contact_email

=item 
contact_fname

=item 
contact_lname

=item 
contact_phone

=item 
organization

=item 
building

=item 
room_number

=item 
org_phone

=item 
org_email

=item 
org_mail_address

=item 
org_toll_free_phone

=item 
org_fax

=item 
url

=item 
credentials

=item 
org_pk

=back

Note:  org_pk can be used to associate the new user with and existing special
center.  The org_pk should be the value of the org_pk in the organization
table for the relevant special center.


=head1 OPTIONS

=item 
--readonly - lists all users that will be added, but doesn't add them

=item 
--debug - prints verbose messages while running

=item 
--infile - input file that contains user data



=cut

  use strict;
  use GEOSS::Database;
  use GEOSS::Terminal;
  use Getopt::Long 2.13;
  require "$LIB_DIR/geoss_session_lib";

  my $infile; 
  my $readonly;
  my $debug;

  getOptions();

  # open handle to database
  open (INFILE, "$infile") || die "Unable to open $infile: $!\n";

  # read headers
  my @headers = split(/\t/, <INFILE>);
  chomp($headers[$#headers]);
  die "Input file must contain a 'login' column\n" 
    if (! in_array("login", @headers));
  die "Input file must contain a 'pi_login' column\n" 
    if (! in_array("pi_login", @headers));
  die "Input file must contain a 'type' column\n" 
    if (! in_array("type", @headers));
    
  my $data;
  while ($data = <INFILE>)
  {
    chomp $data;
    my @user = split(/\t/, $data);
    my %user;
    my $col;
    foreach $col (@headers)
    {
      $user{$col} = shift @user;
    }
    if ($readonly)
    {
       print "READONLY: Adding user: $user{login}\n";
       foreach (keys(%user))
       {
          print "$_ : $user{$_}\n" if ($user{$_});
       }
    }
    else
    {
       print "Adding user: $user{login}\n";
       my $cmd = "$BIN_DIR/geoss_adduser --login=\"$user{login}\" --type=\"$user{type}\" --pi_login=\"$user{pi_login}\" ";
       if ($user{password})
       {
         $cmd .= "--password \"$user{password}\" " 
       }
       else
       {
         $cmd .= "--password " . pw_generate() . " ";
       }
       $cmd .= "--organization \"$user{organization}\" " 
         if ($user{organization}); 
       $cmd .= "--contact_fname \"$user{contact_fname}\" " 
         if ($user{contact_fname}); 
       $cmd .= "--contact_lname \"$user{contact_lname}\" " 
         if ($user{contact_lname}); 
       $cmd .= "--contact_phone \"$user{contact_phone}\" " 
         if ($user{contact_phone}); 
       $cmd .= "--contact_email \"$user{contact_email}\" " 
         if ($user{contact_email}); 
       $cmd .= "--department \"$user{department}\" " if ($user{department}); 
       $cmd .= "--building \"$user{building}\" " if ($user{building}); 
       $cmd .= "--room_number \"$user{room_number}\" " if ($user{room_number}); 
       $cmd .= "--org_phone \"$user{org_phone}\" " if ($user{org_phone}); 
       $cmd .= "--org_email \"$user{org_email}\" " if ($user{org_email}); 
       $cmd .= "--org_mail_address \"$user{org_mail_address}\" "
         if ($user{org_mail_address}); 
       $cmd .= "--org_toll_free_phone \"$user{org_toll_free_phone}\" " 
         if ($user{org_toll_free_phone}); 
       $cmd .= "--org_fax \"$user{org_fax}\" " if ($user{org_fax}); 
       $cmd .= "--url \"$user{url}\" " if ($user{url}); 
       $cmd .= "--credentials \"$user{credentials}\" " if ($user{credentials}); 
        

       print "Running: $cmd" if ($debug);
       my $rc = system "$cmd";
       if ($rc != 0)
       {
         warn "Unable to add $user{login}\n" 
       }
       else
       {
         if ($user{org_pk})
         {
           my $us_fk = doq($dbh, "get_us_pk", $user{login});
           warn "$user{login} ($us_fk) belongs to org: $user{org_pk}\n";
           doq_insert_org_usersec_link($dbh, {
               "org_fk", $user{org_pk},
               "us_fk", $us_fk,
               "curator", 'f',});
         }
       }
    }
  }

  close (INFILE);
  
  $dbh->commit();
  $dbh->disconnect(); 


### SUBROUTINES ###
sub getOptions
{
  my $help;
  if (@ARGV > 0)
  {
    GetOptions(
      'readonly!' => \$readonly,
      'debug!' => \$debug,
      'infile=s' => \$infile,
      'help|?'      => \$help,
    );
  }
  usage() if $help;

  print "Running geoss_bulk_adduser with the following options:\n" if ($debug);
  print "  readonly\n" if (($debug) && ($readonly));
  print "  debug\n" if ($debug);
  print "  infile $infile\n" if ($debug);

  if (! $infile)
  {
    print "You must specify an infile.\n";
    usage();
  }
  if (! -r $infile)
  {
      die "Unable to read $infile :$!.  
        Please specify a valid input file.\n";
  }

}

sub usage
{
      print "Usage: \n";
      print "./geoss_bulk_adduser [--readonly] [--debug]
        [--infile=<infile>]\n";
      exit;
} # usage

=head1 NOTES

=head1 AUTHOR
Teela James
