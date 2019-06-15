set PATH ~/bin $PATH

# (WSL) If the directory we started up in is System32, go home instead
if grep -q Microsoft /proc/version; and test "$PWD" = '/mnt/c/Windows/System32'
  cd ~
end
