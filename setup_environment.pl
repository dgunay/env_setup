# This script sets up a command line Linux environment the way I usually like
# it.

use File::Copy;
use File::Basename;
use English;

die "Script only works in Linux/WSL" unless $OSNAME eq 'linux';

# Environment stuff
my $bin_dir = $ENV{'HOME'} . '/.local/bin';

##############
# CLI args
##############
# Global, determines whether any changes actually happen
my $dry_run = grep { /^(?:-d|--dry-run)$/ } @ARGV; 

# If flag is set, does not prompt before overwriting a file
my $overwrite_all = grep { /^(?:-o|--overwrite-all)$/ } @ARGV;

# See later for -w|--winhome arg

##############
# Script
##############
# Copy .vimrc into home
print "Copying .vimrc to ~/.vimrc...\n";
install_vimrc();

# Install tealdeer properly
print "Installing tldr...\n";
install_tealdeer($bin_dir);

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
die "No Windows home provided (-w|--winhome=/mnt/c/Users/...)" unless $winhome;
die "$winhome is not a directory or doesn't exist" unless -d $winhome;

symlink_windows_libraries_to_home($winhome, $home);

exit 0;

################
# Subroutines
################
sub symlink_windows_libraries_to_home {
  my $winhome  = shift;
  my $wsl_home = shift;

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

sub install_vimrc {
  # If .vimrc is already there, prompt the user
  if (-e $ENV{'HOME'} . '/.vimrc' and not $overwrite_all) {
    return unless user_says_yes_to("~/.vimrc found. Overwrite? (y/n)");
    print "Overwriting ~/.vimrc...\n";
  }

  copy(dirname(__FILE__) . '/.vimrc', $ENV{'HOME'} . '/.vimrc') unless $dry_run;
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