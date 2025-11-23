{pkgs, ...}: {
  programs.zsh = {
    initContent = ''
      export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).
      [[ :$PATH: == *":$HOME/go/bin:"* ]] || PATH+=":$HOME/go/bin"; export PATH
      export LOCAL_BIN="$HOME/.local/bin"; [[ :$PATH: == *":$LOCAL_BIN:"* ]] || PATH+=":$LOCAL_BIN"
      if [[ -f /Users/jevin/secrets/node_auth ]]; then
        export NODE_AUTH_TOKEN=$(< /Users/jevin/secrets/node_auth)
      fi
      if [[ -f /Users/jevin/secrets/localstack ]]; then
        export LOCALSTACK_AUTH_TOKEN=$(< /Users/jevin/secrets/localstack)
      fi
      # Clear API keys to avoid using personal keys at work
      unset ANTHROPIC_API_KEY
      unset OPENAI_API_KEY
      unset GEMINI_API_KEY
    '';
  };
  home.shellAliases = {
    pomodoro = "${pkgs.termdown}/bin/termdown 25m -s -b";
  };
}
