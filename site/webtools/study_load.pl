use strict;
use CGI;
use GEOSS::Database;
use GEOSS::Experiment::Study;
use GEOSS::Experiment::Arraylayout;
use GEOSS::Experiment::Arraymeasurement;
use GEOSS::Session;

require "geoss_session_lib";

main:
{
  my $debug;
  my $q = new CGI;
  my %ch=$q->Vars();
  GEOSS::Session->set_url("webtools/study_load.cgi");
  my $user = GEOSS::Session->user;
  my $error = 0;

  if ($user->type eq "public")
  {
    GEOSS::Session->set_return_message("errmessage", "INVALID_PERMS");
    my $url = index_url($dbh, "webtools");
    print "Location: $url\n\n";
  }
  else
  {
    if ($ch{submit} eq "Load Data")
    {
      my $study = GEOSS::Experiment::Study->new(pk => $ch{select_study})
        or die "Study ($ch{select_study}) does not exist";

      my $file = GEOSS::Fileinfo->new(pk => $ch{data_fi_fk});
      my @layouts = $study->layouts;
      if (-d $file->name)
      {
        my $input = set_data_dir($file, $GEOSS::BuildOptions::USER_DATA_DIR
            . "/" .  $study->owner->login .  "/Data_Files/" . $study->name, 
            $study->owner, $study->group);
        my @verified= $study->verify_study_data_dir($file);
        warn "Loading study from a directory not yet implemented";
        if (0)
        {
          $study->load_from_file($input, @verified);
          GEOSS::Session->set_return_message( "goodmessage", "SUCCESS_LOAD", 
              $study->name);
          $dbh->commit();
        }
      }
      else
      {
#        my $input = set_data_file($file, $GEOSS::BuildOptions::USER_DATA_DIR
#            . "/" .  $study->owner->login .  "/Data_Files/" . $study->name, 
#            $study->owner, $study->group, $layouts[0]);
        eval { $study->verify_study_data_file($file->name) };
        if ($@)
        {
          $dbh->rollback();
          my $url = index_url($dbh, "webtools");
          GEOSS::Session->set_return_message("errmessage", "ERROR_DATA_LOAD", 
            "Unable to verify study data file $file for $study: $@");
        }
        else
        {
          my $url = index_url($dbh, "webtools");
          GEOSS::Session->set_return_message("goodmessage", "SUCCESS_LOAD", 
              $study->name);
          $dbh->commit();
          my $attrib = $dbh->{InactiveDestroy};
          my $pid = fork();
          if ($pid != 0) # parent
          {
            $dbh->{InactiveDestroy} = 1;
            $ses_dbh->{InactiveDestroy} = 1;
            print "Location: $url\n\n";
            exit(0);
          }
          else
          {
            $GEOSS::Session::messages_to_db = 0;
            my $log = "$GEOSS::BuildOptions::USER_DATA_DIR/" .
              $study->owner->login() . "/Data_Files/" . $study->{name} . 
              "/load_log.txt";
            open(STDOUT, '>>', "$log") || die "Can't redirect stdout $log $!";
            open(STDERR, ">&STDOUT") || die "Can't redirect stderr $!";

 
            $GEOSS::Session::messages_to_db = 0;
            $study->set_loading_flag;
            $dbh->commit();
            my $ret = $study->load_from_file($file->name);
            my $content;
            if ($ret==1)
            {
              $content = "Data load for $study: SUCCESS.\n" ;
            }
            else
            {
              warn "Data Load Error: $ret";
              $study->clear_loading_flag;
              $content = "Data load for $study: FAILED.\n" ; 
              use IO::File;
              my $fh = IO::File->new("$log", "r");
              if($fh) {
                while(my $line = $fh->getline()) {
                $content .= $line;
                }
              }
            }
            $dbh->commit();
            $user->send_email("Data load for " . $study->name,
                $content);  
            exit(0);
          }
        }
      }
    }
  }
  draw_study_load_select(\%ch);
  exit(0);
}

sub draw_study_load_select
{
  my ($chref) = @_;

  my $user = GEOSS::Session->user;
  $chref->{htmltitle} = "Choose Array Study";
  $chref->{help} = set_help_url($dbh,"load_a_study");
  $chref->{htmldescription} = "Select array study to load.";
  $chref->{select_study} = select_study_load();
  $chref->{select_file} = select_fi_fk($dbh, $user->pk, "data");

  my ($allhtml) = readfile("study_load_select.html", 
      "/site/webtools/header.html", "/site/webtools/footer.html"); 

  my %ch = %{get_all_subs_vals($dbh, $user->pk, $chref)};
  $allhtml =~ s/{(.*?)}/$ch{$1}/g; 
  $allhtml =~ s/<loop_here>//; 
    print "Content-type: text/html\n\n";
  print "$allhtml\n";
}

sub select_study_load
{
  my $field_name = shift || "select_study";

  return join("\n",
      qq(<select name="$field_name">),
      (map { 
       '<option value="' . $_->pk . '">' . $_->name . '</option>';
       } grep {
       $_->status eq "COMPLETE"
       } reverse (GEOSS::Experiment::Study->new_list())),
      '</select>');
}
