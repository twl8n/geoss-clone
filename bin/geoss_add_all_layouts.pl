use strict;

sub die_usage {
  print STDERR <<'EOF';
Usage: geoss_add_all_layouts <user_name> <dir> [subset|remainder|chip name]
EOF
  exit 1;
}

main:
{
  my $exit = 0;
  my $uid = shift or die_usage();
  my $layout_dir = shift or die_usage();
  my $load_type = shift || 'all';
  my $rmdir = 0;

  my %ccost;

  $ccost{"ARABIDOPSIS"} = 300;
  $ccost{"DROSOPHILA"} = 300;
  $ccost{"E_COLI"} = 300;
  $ccost{"HG-U133A"} = 400;
  $ccost{"HG-U133B"} = 400;
  $ccost{"HG-U133_Plus_2"} = 450;
  $ccost{"HG_U95Av2"} = 	  400;
  $ccost{"HG_U95B"} = 	  400;
  $ccost{"HG_U95C"} = 	  400;
  $ccost{"HG_U95D"} = 	  400;
  $ccost{"HG_U95E"} = 	  400;
  $ccost{"HUFL"} = 		  300;
  $ccost{"MG_U74Av2"} = 	  0;
  $ccost{"MG_U74Bv2"} = 	  400;
  $ccost{"MG_U74Cv2"} = 	  400;
  $ccost{"MOE430A"} = 	  400;
  $ccost{"MOE430B"} = 	  400;
  $ccost{"Mouse430_2"} = 	  450;
  $ccost{"Mu11KA"} = 		  300;
  $ccost{"Mu11KB"} = 		  300;
  $ccost{"Pae_G1a"} = 	  300;
  $ccost{"RAE230A"} = 	  375;
  $ccost{"RAE230B"} = 	  375;
  $ccost{"Rat230_2"} = 	  425;
  $ccost{"RG_U34A"} = 	  375;
  $ccost{"RG_U34B"} = 	  375;
  $ccost{"RG_U34C"} = 	  375;
  $ccost{"RN_U34"} = 		  250;
  $ccost{"RT_U34"} = 		  250;
  $ccost{"YG_S98"} = 		  300;

  my %cspecies;
  $cspecies{"ARABIDOPSIS"} =    6;
  $cspecies{"DROSOPHILA"} =     44;
  $cspecies{"E_COLI"} =         4;
  $cspecies{"HG-U133A"} =       50;
  $cspecies{"HG-U133B"} =       50;
  $cspecies{"HG-U133_Plus_2"} = 50;
  $cspecies{"HG_U95Av2"} =      50;
  $cspecies{"HG_U95B"} = 	  50;
  $cspecies{"HG_U95C"} = 	  50;
  $cspecies{"HG_U95D"} = 	  50;
  $cspecies{"HG_U95E"} = 	  50;
  $cspecies{"HUFL"} = 	  50;
  $cspecies{"MG_U74Av2"} = 	  41;
  $cspecies{"MG_U74Bv2"} = 	  41;
  $cspecies{"MG_U74Cv2"} = 	  41;
  $cspecies{"MOE430A"} = 	  41;
  $cspecies{"MOE430B"} = 	  41;
  $cspecies{"Mouse430_2"} = 	  41;
  $cspecies{"Mu11KA"} = 	  41;
  $cspecies{"Mu11KB"} = 	  41;
  $cspecies{"Pae_G1a"} =   108;
  $cspecies{"RAE230A"} = 	  53;
  $cspecies{"RAE230B"} = 	  53;
  $cspecies{"Rat230_2"} = 	  53;
  $cspecies{"RG_U34A"} = 	  53;
  $cspecies{"RG_U34B"} = 	  53;
  $cspecies{"RG_U34C"} = 	  53;
  $cspecies{"RN_U34"} = 	  53;
  $cspecies{"RT_U34"} = 	  53;
  $cspecies{"YG_S98"} = 	  5;

#
# We could loop over the whole %ccost hash, but the default
# is only to load a few popular chips.
# 
# Put the new standardized chip name into $ac, then call
# add_layout() as shown.
#

  if ($layout_dir =~ /\.tar(\.gz)?$/) {
    system('tar', '-x', ($1 ? '-z' : ()), '-f', $layout_dir, '-C', '/tmp')
      and die "tar returned failure: $?";
    $layout_dir = '/tmp/geoss_layouts';
    print "Unpacked layout directory: $layout_dir\n";
    $rmdir = 1;
  }

  if (-r $layout_dir)
  { 
    my @chips_to_load;
    if ($load_type eq "all")
    {
      @chips_to_load = (
          "ARABIDOPSIS",
          "DROSOPHILA",
          "E_COLI",
          "HG-U133A",
          "HG-U133B",
          "HG-U133_Plus_2",
          "HG_U95Av2",
          "HG_U95B",
          "HG_U95C",
          "HG_U95D",
          "HG_U95E",
          "HUFL",
          "MG_U74Av2",
          "MG_U74Bv2",
          "MG_U74Cv2",
          "MOE430A",
          "MOE430B",
          "Mouse430_2",
          "Mu11KA",
          "Mu11KB",
          "Pae_G1a",
          "RAE230A",
          "RAE230B",
          "Rat230_2",
          "RG_U34A",
          "RG_U34B",
          "RG_U34C",
          "RN_U34",
          "RT_U34",
          "YG_S98")
    }
    elsif ($load_type eq "subset")
    {
      @chips_to_load = 
        ("HG-U133A", 
         "HG_U95Av2",
         "HG-U133_Plus_2",
         "MG_U74Av2",
         "MOE430A",
         "RAE230A",
         "Pae_G1a");
    }
    elsif ($load_type eq "remainder")
    {
      @chips_to_load = (
          "ARABIDOPSIS",
          "DROSOPHILA",
          "E_COLI",
          "HG-U133B",
          "HG_U95B",
          "HG_U95C",
          "HG_U95D",
          "HG_U95E",
          "HUFL",
          "MG_U74Bv2",
          "MG_U74Cv2",
          "MOE430A",
          "MOE430B",
          "Mouse430_2",
          "Mu11KA",
          "Mu11KB",
          "RAE230B",
          "Rat230_2",
          "RG_U34A",
          "RG_U34B",
          "RG_U34C",
          "RN_U34",
          "RT_U34",
          "YG_S98")
    }
    elsif (
        ($load_type eq "ARABIDOPSIS") ||
        ($load_type eq "DROSOPHILA") ||
        ($load_type eq "E_COLI") ||
        ($load_type eq "HG-U133A") ||
        ($load_type eq "HG-U133B") ||
        ($load_type eq "HG-U133_Plus_2") ||
        ($load_type eq "HG_U95Av2") ||
        ($load_type eq "HG_U95B") ||
        ($load_type eq "HG_U95C") ||
        ($load_type eq "HG_U95D") ||
        ($load_type eq "HG_U95E") ||
        ($load_type eq "HUFL") ||
        ($load_type eq "MG_U74Av2") ||
        ($load_type eq "MG_U74Bv2") ||
        ($load_type eq "MG_U74Cv2") ||
        ($load_type eq "MOE430A") ||
        ($load_type eq "MOE430B") ||
        ($load_type eq "Mouse430_2") ||
        ($load_type eq "Mu11KA") ||
        ($load_type eq "Mu11KB") ||
        ($load_type eq "Pae_G1a") ||
        ($load_type eq "RAE230A") ||
        ($load_type eq "RAE230B") ||
        ($load_type eq "Rat230_2") ||
        ($load_type eq "RG_U34A") ||
        ($load_type eq "RG_U34B") ||
        ($load_type eq "RG_U34C") ||
        ($load_type eq "RN_U34") ||
        ($load_type eq "RT_U34") ||
        ($load_type eq "YG_S98") 
        )
        {
          @chips_to_load = ("$load_type");
        }
    else
    { 
      die "Unrecognized load_type: $load_type\n";
    }
    my $ac;
    foreach $ac (@chips_to_load)
    {  
      add_layout($ac, $uid, $ccost{$ac}, $cspecies{$ac}, $layout_dir);
    }
  }
  else
  {
    die "Unable to read layout directory $layout_dir\n";
  }
  if ($rmdir)
  {
    unlink <$layout_dir/*> or warn "Unable to remove $layout_dir/* :$!";
    rmdir $layout_dir or warn "Unable to remove $layout_dir: $!";
  }
}

sub add_layout
{
  my $which_chip = $_[0];
  my $uid = $_[1];
  my $cost = $_[2];
  my $species = $_[3];
  my $layout_dir = $_[4];

  my $rc;
  print "Adding $which_chip layout\n";
  $rc = system "$BIN_DIR/geoss_loadaffylayout --name=$which_chip --input=$layout_dir/$which_chip.txt  --speciesid=$species --login=$uid --dbname=$DB_NAME --chipcost=$cost";
#
# Don't die on errors here. Some layouts may be loaded, and we'd like
# to try to load the others even though there will be a duplicate record error
# on the already loaded layout.
# 
  if ($rc != 0)
  {
    print "Unable to add $which_chip layout $!\n";
  }
}

