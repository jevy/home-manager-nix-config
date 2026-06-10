# Ghostty terminal emulator (cross-platform)
{ ... }:
{
  flake.modules.homeManager.ghostty =
    { pkgs, lib, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
        enableZshIntegration = true;
        systemd.enable = pkgs.stdenv.isLinux;
        installVimSyntax = true;
        settings = {
          shell-integration-features = "sudo,ssh-env,ssh-terminfo";
          font-family = "MesloLGS Nerd Font";
          font-size = 11;
          keybind =
            [
              "ctrl+,=unbind"
              "ctrl+a>c=new_tab"
              "ctrl+a>ctrl+c=new_tab"
              # ctrl+h/l navigate Ghostty's own splits. Neovim window nav lives on
              # Alt (<A-hjkl>, see nixvim.nix) precisely to avoid this overlap —
              # Ghostty won't reliably forward ctrl+h to a program (performable:
              # passthrough is broken on 1.3.x, ghostty #9566), so the two layers
              # use different modifiers instead of fighting over Ctrl.
              "ctrl+h=goto_split:left"
              "ctrl+l=goto_split:right"
              "ctrl+a>h=new_split:left"
              "ctrl+a>ctrl+h=new_split:left"
              "ctrl+a>l=new_split:right"
              "ctrl+a>ctrl+l=new_split:right"
              "ctrl+a>f=toggle_split_zoom"
              "ctrl+a>ctrl+f=toggle_split_zoom"
              "ctrl+a>n=next_tab"
              "ctrl+a>ctrl+n=next_tab"
              "ctrl+a>p=previous_tab"
              "ctrl+a>ctrl+p=previous_tab"
              # Page-scroll moved off alt+j/k → ctrl+shift+j/k, freeing alt+j/k so
              # Neovim's <A-j>/<A-k> window-nav reaches it (Ghostty would otherwise
              # consume them before the program).
              "ctrl+shift+k=scroll_page_up"
              "ctrl+shift+j=scroll_page_down"
              # Make Ctrl+Backspace (kanata nav: e+u) delete a word in the shell.
              # Terminals can't distinguish C-bspc from bspc, so readline never
              # sees it as delete-word. Translate it to ESC+DEL (what Alt+Bspc
              # would emit), which readline binds to backward-kill-word.
              "ctrl+backspace=text:\\x1b\\x7f"
            ]
            ++ (lib.optionals pkgs.stdenv.isDarwin [
              "super+a>c=new_tab"
              "super+a>ctrl+c=new_tab"
              "super+h=goto_split:left"
              "super+l=goto_split:right"
              "super+a>h=new_split:left"
              "super+a>ctrl+h=new_split:left"
              "super+a>l=new_split:right"
              "super+a>ctrl+l=new_split:right"
              "super+a>f=toggle_split_zoom"
              "super+a>ctrl+f=toggle_split_zoom"
              "super+a>n=next_tab"
              "super+a>ctrl+n=next_tab"
              "super+a>p=previous_tab"
              "super+a>ctrl+p=previous_tab"
            ]);
        }
        // lib.optionalAttrs pkgs.stdenv.isDarwin {
          # Make Option emit Meta so Neovim's <A-hjkl> window-nav works on macOS.
          # Tradeoff: Option no longer types special glyphs (é, etc.) in the
          # terminal. Drop this if you'd rather keep Option-as-compose on the Mac.
          macos-option-as-alt = true;
        };
      };
    };
}
