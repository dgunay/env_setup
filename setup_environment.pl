# This script sets up a command line Linux environment the way I usually like
# it.

use File::Copy;
use File::Basename;
use English;

die "Script only works in Linux/WSL\n" unless $OSNAME eq 'linux';

# I usually like to install my own binaries here
my $bin_dir = $ENV{'HOME'} . '/bin';

##############
# CLI args
##############
# Global, determines whether any changes actually happen
my $dry_run = grep { /^(?:-d|--dry-run)$/ } @ARGV; 

# If flag is set, does not prompt before overwriting a file
my $overwrite_all = grep { /^(?:-o|--overwrite-all)$/ } @ARGV;

# If flag is set, all installations are run.
my $install_all = grep { /^(?:-a|--install-all)$/ } @ARGV;

# TODO: alternate home dir (easier to test)

# See later for -w|--winhome arg

##############
# Script
##############

# Copy .vimrc into home
install_vimrc() if grep { /^(?:-v|--vimrc)$/ } @ARGV or $install_all;

# Copy .nanorc and nano stuff into home
install_nanorc() if grep { /^(?:-n|--nanorc)$/ } @ARGV or $install_all;

# Install tealdeer properly
install_tealdeer($bin_dir) if grep { /^(?:-t|--tldr)$/ } @ARGV or $install_all;

# Install fish shell and set to default
install_fish() if grep { /^(?:-f|--fish)$/ } @ARGV or $install_all;

# Does the user want to do WSL symlinking?
exit 0 unless grep { /^(-s|--symlink)$/ } @ARGV or $install_all;

# Detect if WSL or exit
my $wsl = grep { /Microsoft/i } `uname -a`;
exit 0 unless $wsl;
print "Windows Subsystem for Linux detected.\n";

# Symlink Documents, Music, Videos, etc to home
my $home = $ENV{'HOME'};

# Find the user-provided windows home dir
my $winhome = 0; 
for (@ARGV) {
  $winhome = $1 if $_ =~ /-w=(.+)$/;
  $winhome = $1 if $_ =~ /--winhome=(.+)$/;
  last if $winhome;
}

# Default winhome in WSL
$winhome = '/mnt/c/Users/' . $ENV{'LOGNAME'} unless $winhome;

die "No Windows home provided (-w=|--winhome=/mnt/c/Users/...)" unless $winhome;
die "$winhome is not a directory or doesn't exist" unless -d $winhome;

symlink_windows_libraries_to_home($winhome, $home);

exit 0;

################
# Subroutines
################
sub symlink_windows_libraries_to_home { my ($winhome, $wsl_home) = @_;

  # rtrim slashes from winhome
  $winhome =~ s/\/+$//g;

  my @libraries = qw(Documents Music Pictures Videos);
  foreach my $lib (@libraries) {
    die "$winhome/$lib does not exist" unless -e "$winhome/$lib";

    next unless (
      $overwrite_all
      or user_says_yes_to("Symlink $winhome/$lib to $wsl_home/$lib? (y/n)")
    );

    print "Symlinking $winhome/$lib to $wsl_home/$lib...\n";
    symlink("$winhome/$lib", "$wsl_home/$lib") unless $dry_run;
  }
}

sub install_rc_file { my ($rc) = @_;
  print "Copying $rc to ~/$rc...\n";

  # If it's already there, prompt the user
  if (-e $ENV{'HOME'} . "/$rc" and not $overwrite_all) {
    return unless user_says_yes_to("~/$rc found. Overwrite? (y/n)");
    print "Overwriting ~/$rc...\n";
  }

  copy(dirname(__FILE__) . "/$rc", $ENV{'HOME'} . "/$rc") unless $dry_run;
}

sub install_vimrc {
  install_rc_file('.vimrc');
}

sub install_nanorc {
  install_rc_file('.nanorc');

  # Also install the .nano folder for syntax highlighting
  my $dot_nano_dir = $ENV{'HOME'} . "/.nano";
  if (-e $dot_nano_dir and not $overwrite_all) {
    return unless user_says_yes_to("~/.nano found. Overwrite? (y/n)");
    print "Overwriting ~/.nano...\n";
    system("rm -rf $dot_nano_dir");
  }

  system("git clone --quiet https://github.com/scopatz/nanorc.git $dot_nano_dir") 
    unless $dry_run;
}

sub user_says_yes_to {
  my $prompt = shift;
  die unless $prompt;

  print $prompt;
  my $response = <STDIN>;
  chomp $response;
  return $response =~ /y/i;
}

sub install_tealdeer {
  my $bin_dir = shift;

  print "Installing tldr...\n";

  die "$bin_dir doesn't exist or is not a directory" unless -d $bin_dir;

  if (-e "$bin_dir/tldr") {
    return 0 unless user_says_yes_to(
      "tldr binary already present at $bin_dir/tldr. Overwrite? (y/n)"
    );
  }

  return 0 if $dry_run;

  # Download the binary (v1.1.0) using wget
  my $url = 'https://github.com/dbrgn/tealdeer/releases/download/v1.1.0/tldr-x86_64-musl';
  my $return_code = system("wget -q -O $bin_dir/tldr $url");
  die "Downloading tldr with wget returned $return_code" if $return_code != 0;
  return $return_code;
}

sub install_fish {
  my $bashrc_location = $ENV{'HOME'} . '/.bashrc';
  die "no .bashrc found" unless -e $bashrc_location;

  if (user_says_yes_to('Install fish shell v3? (y/n)')) {
    # Add fish
    unless ($dry_run) {
      my $return_code = system("sudo apt-add-repository -y ppa:fish-shell/release-3");
      die "Failed to add fish v3 repo" if $return_code != 0;
    }
    else {
      print "This is where we would add the fish repository, but it's a dry run.\n";
    }

    # Update packages
    $return_code = system("sudo apt-get --quiet update");
    die "Updating failed (return code was $return_code)" if $return_code != 0;

    # Pass simulate to apt-get if it's a dry run.
    my $simulate = $dry_run ? '--simulate' : '';
    # Install fish.
    $return_code = system("sudo apt-get --quiet $simulate install fish");

    # Install config.fish
    copy(dirname(__FILE__) . '/config.fish', $ENV{'HOME'} . '/.config/fish/config.fish') 
      unless $dry_run;
  }

  if (user_says_yes_to('Set fish as default shell? (y/n)')) {
    # Grab our bashrc contents
    my $custom_bashrc_contents = slurp_file('./.bashrc');

    # Make sure the contents are not already in the file
    $return_code = system("grep --quiet 'ADDED BY setup_environment.pl' $bashrc_location");
    if ($return_code == 0) {
      print "$bashrc_location has already been modified, skipping...\n";
    }
    else {
      print "Appending ./.bashrc to $bashrc_location...\n";
      open (my $fh, '>>', $bashrc_location) or die "Couldn't open $bashrc_location for appending";
      print $fh $custom_bashrc_contents unless $dry_run;
      close $fh;
    }    
  }
}

sub slurp_file {
  my $filename = shift;

  open my $fh, '<', $filename or die "Couldn't open $filename for reading";
  $/ = undef;
  my $data = <$fh>;
  close $fh;

  return $data;
}
