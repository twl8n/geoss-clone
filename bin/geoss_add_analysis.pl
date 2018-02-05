=head1 NAME
 
  geoss_add_analysis -  add an analysis to the list of possible analyses

=head1 SYNOPSIS

 ./geoss_add_analysis.pl --configfile <filename>

=head1 DESCRIPTION

 The geoss_add_analysis script configures a new analysis for use 
 within the GEOSS by adding the analysis definition (as defined in 
 the supplied configuration file) into the database.

=cut

  use strict;
  use DBI;
  use Getopt::Long 2.13;
  use AppConfig qw(:expand :argcount);
  use GEOSS::Database;
  use GEOSS::Terminal;
  require "$LIB_DIR/geoss_session_lib";

  my $config = AppConfig->new();
  $config->define('name', {ARGCOUNT => ARGCOUNT_ONE},
    'cmdstr', {ARGCOUNT => ARGCOUNT_ONE},
    'version', {ARGCOUNT => ARGCOUNT_ONE},
    'an_type', {ARGCOUNT => ARGCOUNT_ONE},
    'current', {ARGCOUNT => ARGCOUNT_ONE},
    'up', { ARGCOUNT => ARGCOUNT_LIST },
    'filetype',{ ARGCOUNT => ARGCOUNT_LIST },
    'extension',{ ARGCOUNT => ARGCOUNT_LIST },
    'sp', { ARGCOUNT => ARGCOUNT_LIST },
    'analysisfile', { ARGCOUNT => ARGCOUNT_LIST,});
  $config->define('configfile', {ARGCOUNT => ARGCOUNT_ONE},
    'debug', {ARGCOUNT => ARGCOUNT_ONE});
  my $success = $config->getopt(\@ARGV);
  usage() if (! $success);

  my $cfgfile = $config->get('configfile');
  my $debug = $config->get('debug');
  usage() if (!defined $cfgfile);
  $success = $config->file($cfgfile);
  die "Invalid config file format" if (! $success);

  modifyDB($config);

# end main

sub modifyDB
{
  my ($config) = @_;

  # open handle to database
  my $name = $config->get('name');
  my $version = $config->get('version');

  my $stm = $dbh->prepare("select an_pk from analysis where an_name = '$name' and version = $version");
  $stm->execute();

  #get result
  my $an_fk= $stm->fetchrow_array();
  $stm->finish();

  if (defined $an_fk)
  {
    warn "Analysis $name $version is already loaded: $an_fk"; 
  }
  else
  {
    # insert appropriate values in appropriate tables

    # we need to add the analysis
    act_analysis($dbh, $config->get('name'), $config->get('cmdstr'),
      $config->get('version'), $config->get('an_type'), $config->get('current'));  

    # we need to add filetypes
    my $keysref = act_filetype($dbh, $config->get('filetype'));    

    # we need to add the links to filetypes
    act_file_links($dbh, $config->get('analysisfile'), 
      $config->get('name'), $config->get('version'), $keysref);    

    # we need to add the sysparams
    act_sysparams($dbh, $config->get('sp'), $config->get('name'), $config->get('version')); 

    # we need to add the userparams
    act_userparams($dbh, $config->get('up'), $config->get('name'), $config->get('version'));    

    # insert appropriate values in extension table
    act_extension($dbh, $config->get('extension'), $an_fk, $keysref);

    $dbh->commit();
  }
  $dbh->disconnect(); 
} # modifyDB

sub parse_into_records
{
  my @input = @_;
  my @return = ();
  my %rec = ();

  while (my $element = shift(@input))
  { 
    my ($key, $value) = split(/=/, $element, 2);
    #remove spaces from key
    $key =~ tr/ //d;
    if (exists $rec{$key})
    {
      my %dup = %rec;
      push(@return, \%dup);
      %rec = ();
    }
    $rec{$key} = $value;
  }
  push(@return, %rec ? \%rec : ());
  return(@return);
  
} #parse_into_record

sub act_filetype
{
  my ($dbh, $filetype) = @_;
  
  my $stm = "";
  my $record;
  my $table = "filetypes";
  my @keys = ();

  my @records = parse_into_records(@$filetype);

  foreach $record (@records)
  {
    my %rec = %$record;
    my $name = $rec{name};
    my $comment = $rec{comment};
    my $arg_name = $rec{arg_name};


    checkValidFields($table, [ "name", "arg_name" ], 
      ["name", "comment", "arg_name"], $record);
    $stm = "insert into $table (ft_name, ft_comments, arg_name) " . 
        "values ('$name', '$comment', '$arg_name');";
    print "$stm\n" if $debug;
    my $sth = $dbh->prepare( $stm ); 
    $sth->execute();
  }
  $dbh->commit();
  
  # we want to get the keys for the records we just added
  # note that rows can be not unique.  Therefore, we assume
  # that the last row that matches our criteria is the row
  # we just added.
  foreach $record (@records)
  {
    my %rec = %$record;
    my $name = $rec{name};
    my $comment = $rec{comment};
    my $arg_name = $rec{arg_name};

    $stm = "select ft_pk from $table where ft_name = '$name' " .
      " and ft_comments = '$comment' and arg_name = '$arg_name'";
    my $sth = $dbh->prepare( $stm ); 
    $sth->execute(); 
    my $lastkey;
    while (my @row = $sth->fetchrow_array())
    {
      ($lastkey) = @row;
    }
    push(@keys, $lastkey);
  }
  return(\@keys);
} # act_filetype    

sub act_analysis
{
  my ($dbh, $name, $cmdstr, $version, $an_type,$current) = @_; 
  my $stm = "";

  $stm = "insert into analysis (an_name, cmdstr, version, an_type, current) values " . 
    "('$name', '$cmdstr', '$version','$an_type','$current');";

  print "$stm\n" if $debug;
  my $sth = $dbh->prepare( $stm ); 
  $sth->execute();
  $dbh->commit();
} # act_analysis   

sub act_extension
{
  my ($dbh, $ext, $an_pk, $keysref) = @_;    

  my $stm = "";
  my $record;
  my $table="extension";
  my @keys = @$keysref;

  my @records = parse_into_records(@$ext);

  foreach $record (@records)
  {
    my %rec = %$record;
    
    my $filetype = $rec{filetype};
    my $ext = $rec{ext};

    # select the filetypes pk for the filetype
    $stm = $dbh->prepare(
      "select ft_pk from filetypes where ft_name= '$filetype'");
    $stm->execute();

    my $ft_fk = $stm->fetchrow_array();

    if (!defined $ft_fk)
    { 
      warn "Unable to get filetypes key value for $filetype";
    }
    else
    {
      checkValidFields($table, [ "filetype","ext" ],
        ["filetype", "ext"], $record);
      while (! numIn($ft_fk, @keys))
      {
        $ft_fk = $stm->fetchrow_array;
        last if (!defined $ft_fk);
      }

      $stm = $dbh->prepare("select ext_pk from extension where " .
        " ft_fk = $ft_fk and extension = '$ext'");
      $stm->execute();
      my $exists = $stm->fetchrow_array();
      if (!defined $exists)
      {
        $stm = "insert into $table (ft_fk, extension) " . 
          "values ($ft_fk, '$ext');";
        print "$stm\n" if $debug;
        my $sth = $dbh->prepare( $stm ); 
        $sth->execute();
      }
    }
  }
  $dbh->commit();
} # act_extension

sub act_file_links
{
  my ($dbh, $filelist, $name, $version, $keysref) = @_;    

  my $stm = "";
  my $record;
  my $table="analysis_filetypes_link";
  my @keys = @$keysref;

  my @records = parse_into_records(@$filelist);

  # select the analysis pk for the analysis
  $stm = $dbh->prepare("select an_pk from analysis where an_name = '$name' and version = '$version'");
  $stm->execute();

  # get result
  my $an_fk = $stm->fetchrow_array();
  if (!defined $an_fk)
  { 
    warn "Unable to get analysis key value for $name version $version";
    return;
  }
  
  foreach $record (@records)
  {
    my %rec = %$record;
    
    my $filetype = $rec{filetype};
    my $input = $rec{input};

    # select the filetypes pk for the filetype
    $stm = $dbh->prepare(
      "select ft_pk from filetypes where ft_name= '$filetype' ");
    $stm->execute();

    my $ft_pk = $stm->fetchrow_array; 
    if (!defined $ft_pk)
    { 
      warn "Unable to get filetypes key value for $filetype";
    }

    if (defined $ft_pk)
    {
       checkValidFields($table, [ "filetype","input"],
             ["filetype", "input"], $record);
       while (! numIn($ft_pk, @keys))
       {
           $ft_pk = $stm->fetchrow_array; 
           last if (! defined $ft_pk);
       }
       $stm = "insert into $table (an_fk, ft_fk, input) " . 
          "values ('$an_fk', '$ft_pk', '$input');";
       print "$stm\n" if $debug;
       my $sth = $dbh->prepare( $stm ); 
       $sth->execute();
    }
  }
  $dbh->commit();
} # act_file_links

sub act_sysparams
{
  my ($dbh, $sp, $name, $version) = @_; 
  
  my $stm = "";
  my $record;
  my $table="sys_parameter_names"; 
  my @records = parse_into_records(@$sp);

  # select the analysis pk for the analysis
  $stm = $dbh->prepare("select an_pk from analysis where an_name = '$name' and version = '$version'");
  $stm->execute();

  # get result
  my $an_fk = $stm->fetchrow_array();
  if (!defined $an_fk)
  { 
    warn "Unable to get analysis key value for $name version $version";
    return;
  }

  foreach $record (@records)
  {
    my %rec = %$record;
    my $optional=0;

    $optional = $rec{optional} if exists($rec{optional});

    checkValidFields($table, [ "name" ], ["name", "default", "optional"], 
      $record);

    my $name = $rec{name};
    my $default ="NULL";

    $default = "'$rec{default}'" if exists($rec{default});
    $stm = "insert into $table (an_fk, sp_name, sp_default, sp_optional) " .
      "values ('$an_fk', '$name', $default, '$optional');";
    print "$stm\n" if $debug;
    my $sth = $dbh->prepare( $stm ); 
    $sth->execute();
  }

  $dbh->commit();
} # act_sysparams   

sub act_userparams
{
  my ($dbh, $up, $name, $version) = @_; 
  
  my $stm = "";
  my $record;
  my $table="user_parameter_names";

  my @records = parse_into_records(@$up);

  # select the analysis pk for the analysis
  $stm = $dbh->prepare("select an_pk from analysis where an_name = '$name' and version='$version'");
  $stm->execute();

  # get result
  my $an_fk = $stm->fetchrow_array();
  if (!defined $an_fk)
  { 
    warn "Unable to get analysis key value for $name version $version";
    return;
  }

  foreach $record (@records)
  {
    my %rec = %$record;
    my $name = $rec{name};
    my $display_name = $rec{display_name};
    my $type = $rec{type};
    my $default ="NULL";
    my $optional=0;

    $optional = $rec{optional} if exists($rec{optional});

    $default = "'$rec{default}'" if exists($rec{default});

    checkValidFields($table, [ "name", "display_name", "type" ],
      ["name", "display_name", "type", "default", "optional"], $record);
    $stm = "insert into $table (an_fk, up_name, up_display_name, up_type, " .
      "up_optional, up_default) values ('$an_fk', '$name', " .
      "'$display_name', '$type','$optional',$default);";
    print "$stm\n" if $debug;
    my $sth = $dbh->prepare( $stm ); 
    $sth->execute();
  }
  $dbh->commit();
} # act_userparams 

sub checkValidFields
{
  my ($table, $reqref, $fieldsref, $record) = @_;

  my @req = @$reqref;
  my @fields = @$fieldsref;
  my %rec = %$record;

  foreach my $req (@req)
  {
    warn "Incorrect configuration. $table requires $req field.\n" 
      if (!exists $rec{$req});
  }

  foreach my $key (keys(%rec))
  {
    my $found = 0;
    foreach my $field (@fields)
    {
      $found = 1 if ($field eq $key);
    }
    if (! $found)
    {
      warn "Invalid param field: $key.\n";
      warn "Valid field names are: @fields\n";
    }
  }
} # checkValidFields

sub numIn
{
  my ($scalar) = shift;
  my @array = @_;

  my $in = 0;
  foreach my $item (@array)
  {
    if ($item == $scalar)
    {
      $in=1;
    }
  }
  return($in);
}

sub usage
{
      print "Usage: \n";
      print "./geoss_add_analysis.pl --configfile <filename> \n";
      exit ;
} # usage

=head1 NOTES


=head1 AUTHOR

Teela James


