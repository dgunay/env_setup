# This script sets up a command line Linux environment the way I usually like
# it.

use File::Copy;
use File::Basename;

# Environment stuff
my $bin_dir = $ENV{'HOME'} . '/.local/bin';

# CLI args
my $dry_run = grep { /^(?:-d|--dry-run)$/ } @ARGV;
my $overwrite_all = grep { /^(?:-o|--overwrite-all)$/ } @ARGV;

# Copy .vimrc into home
print "Copying .vimrc to ~/.vimrc...\n";
install_vimrc();

# Install tealdeer properly
print "Installing tldr...\n";
install_tealdeer($bin_dir);

# Detect if WSL
my $wsl = grep { /Microsoft/i } `uname -a`;
exit 0 unless $wsl;
print "Windows Subsystem for Linux detected.\n";

# Symlink Documents, Music, Videos, etc to home
my $home = $ENV{'HOME'};
my $winhome = ''; # TODO: figure out how to get this or ask the user
symlink_windows_folders_to_home($winhome);


sub symlink_windows_folders_to_home {
  my $winhome = shift;

  return unless $dry_run;

  symlink();
}

sub install_vimrc {
  # If .vimrc is already there, prompt the user
  if (-e $ENV{'HOME'} . '/.vimrc' and not $overwrite_all) {
    print "~/.vimrc found. Overwrite? (y/n)";

    if (user_says_yes()) {
      print "Overwriting ~/.vimrc...\n";
      copy(dirname(__FILE__) . '/.vimrc', $ENV{'HOME'} . '/.vimrc') unless $dry_run;
      return;
    }
  }

  copy(dirname(__FILE__) . '/.vimrc', $ENV{'HOME'} . '/.vimrc') unless $dry_run;
}

sub user_says_yes {
  my $response = <STDIN>;
  chomp $response;
  return $response =~ /y/i;
}

sub install_tealdeer {
  my $bin_dir = shift;

  die "$bin_dir doesn't exist or is not a directory" unless -d $bin_dir;

  if (-e "$bin_dir/tldr") {
    print "tldr binary already present at $bin_dir/tldr. Overwrite? (y/n)";
    return 0 unless user_says_yes();
  }

  # Return early if dry run
  return 0 if $dry_run;

  # Download the binary (v1.1.0) using wget
  my $url = 'https://github.com/dbrgn/tealdeer/releases/download/v1.1.0/tldr-x86_64-musl';
  my $return_code = system("wget -q -O $bin_dir/tldr $url");
  die "Downloading tldr with wget returned $return_code" if $return_code != 0;
  return $return_code;
}