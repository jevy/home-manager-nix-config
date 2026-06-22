# Ghostty terminal emulator (cross-platform)
{ ... }:
{
  flake.modules.homeManager.ghostty =
    { pkgs, lib, ... }:
    {
      programs.ghostty = {
        enable = true;
        # TODO: monitor for a ghostty release > 1.3.1 in nixpkgs, then bump.
        # File drag-and-drop from GTK sources (ripdrag/Nautilus) silently fails
        # into Ghostty on Hyprland: the compositor pre-selects the "move" DnD
        # action, but Ghostty 1.3.1's drop target only accepts "copy", so GTK4
        # rejects the drop before Ghostty sees it (works into kitty/Firefox).
        # Fixed upstream by PR #11182 (commit c920a88, "add 'move' to the drop
        # target actions") — merged to main 2026-03-05 but NOT in the v1.3.1 tag,
        # so it's absent from nixos-unstable AND master (both build refs/tags/v1.3.1
        # as of 2026-06). Not backporting; just bump once a tagged release carries
        # it. Refs: https://github.com/ghostty-org/ghostty/issues/11175 (PR #11182).
        # Workaround until then: hold Ctrl while dragging to force the copy action.
        package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
        enableZshIntegration = true;
        systemd.enable = pkgs.stdenv.isLinux;
        installVimSyntax = true;
        settings = {
          # Draw window decorations from ghostty's own (stylix) theme instead of
          # the GTK/libadwaita system theme, which otherwise renders a white
          # titlebar on Linux even though the terminal colors are dark. No-op on
          # macOS.
          window-theme = "ghostty";
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
