{
  writeShellApplication,
  dix,
  coreutils,
  gawk,
  git,
  stdenv,
}:
writeShellApplication {
  name = "nixdiff";
  runtimeInputs = [
    dix
    coreutils
    gawk
    git
  ];
  text = ''
    flake="''${NIXDIFF_FLAKE:-$HOME/.config/nixpkgs}"
    profiles=/nix/var/nix/profiles
    explicit=0
    if [ "''${1:-}" = -e ] || [ "''${1:-}" = --explicit ]; then
      explicit=1
      shift
    fi

    usage() {
      cat <<EOF
    nixdiff                 build this host from $flake, diff vs running system
    nixdiff update          nix flake update, then the above
    nixdiff last            what the last switch changed (previous gen -> current)
    nixdiff gen N [M]       generation N -> M (default: current)
    nixdiff gens            list system generations
    nixdiff OLD NEW         diff two store paths / result links

    -e, --explicit          (before any of the above) only packages you listed in
                            home.packages / environment.systemPackages
    EOF
    }

    target() {
      ${
        if stdenv.hostPlatform.isDarwin then
          ''echo "$flake#darwinConfigurations.''${NIXDIFF_HOST:-mac-work}.system"''
        else
          ''echo "$flake#nixosConfigurations.''${NIXDIFF_HOST:-$(uname -n)}.config.system.build.toplevel"''
      }
    }

    explicit_names() {
      for root in "$@"; do
        nix-store -qR "$root" | grep -E -- '-(home-manager|system)-path$' || true
      done | xargs nix-store -q --references \
        | sed -E 's|^/nix/store/[a-z0-9]{32}-||; s/-[0-9].*$//' | sort -u
    }

    run_dix() {
      if [ "$explicit" = 0 ]; then
        dix "$1" "$2"
        return
      fi
      names="$(explicit_names "$1" "$2" | tr '\n' ' ')"
      dix --color always "$1" "$2" | awk -v names="$names" '
        BEGIN { n = split(names, a, " "); for (i = 1; i <= n; i++) keep[a[i]] = 1 }
        { plain = $0; gsub(/\033\[[0-9;]*m/, "", plain) }
        plain !~ /^\[/ { print; next }
        { split(plain, f, /[ \t]+/); if (f[2] in keep) print }
      '
    }

    gen_numbers() {
      for l in "$profiles"/system-*-link; do
        n="''${l##*/system-}"
        echo "''${n%-link}"
      done | sort -n
    }

    current_gen() {
      n="$(readlink "$profiles/system")"
      n="''${n#system-}"
      echo "''${n%-link}"
    }

    pending() {
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      echo "building $(target)" >&2
      nix build "$(target)" --out-link "$tmp/new" --log-format bar
      if [ "$(readlink -f /run/current-system)" = "$(readlink -f "$tmp/new")" ]; then
        echo "nothing pending: config matches the running system. try: nixdiff last (or -e last)" >&2
        return
      fi
      run_dix /run/current-system "$tmp/new"
    }

    case "''${1:-}" in
      "") pending ;;
      update)
        nix flake update --flake "$flake"
        git -C "$flake" --no-pager diff --stat -- flake.lock
        pending
        ;;
      last)
        cur="$(current_gen)"
        prev="$(gen_numbers | awk -v c="$cur" '$1 < c' | tail -n1)"
        [ -n "$prev" ] || { echo "no generation before $cur" >&2; exit 1; }
        echo "generation $prev -> $cur" >&2
        run_dix "$profiles/system-$prev-link" "$profiles/system-$cur-link"
        ;;
      gen)
        [ -n "''${2:-}" ] || { usage; exit 1; }
        run_dix "$profiles/system-$2-link" "$profiles/system-''${3:-$(current_gen)}-link"
        ;;
      gens)
        cur="$(current_gen)"
        for n in $(gen_numbers); do
          mark=" "; [ "$n" = "$cur" ] && mark="*"
          printf '%s %4s  %s\n' "$mark" "$n" "$(stat -c '%y' "$profiles/system-$n-link" | cut -c1-16)"
        done
        ;;
      -h | --help | help) usage ;;
      *)
        [ $# -eq 2 ] || { usage; exit 1; }
        run_dix "$1" "$2"
        ;;
    esac
  '';
}
