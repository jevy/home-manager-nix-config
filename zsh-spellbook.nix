{pkgs, ...}: {
  programs.zsh = {
    initExtra = ''
      export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).
      export LOCAL_BIN="$HOME/.local/bin"; [[ :$PATH: == *":$LOCAL_BIN:"* ]] || PATH+=":$LOCAL_BIN"
      if [[ -f /Users/jevin/secrets/node_auth ]]; then
        export NODE_AUTH_TOKEN=$(< /Users/jevin/secrets/node_auth)
      fi
      if [[ -f /Users/jevin/secrets/anthropic ]]; then
        export ANTHROPIC_API_KEY=$(< /Users/jevin/secrets/anthropic)
      fi
    '';
  };
  home.shellAliases = {
    pomodoro = "${pkgs.termdown}/bin/termdown 25m -s -b";
  };
}
