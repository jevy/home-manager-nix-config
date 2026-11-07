{
  writeShellApplication,
  qdmr,
  python3,
  usbutils,
  coreutils,
  gnugrep,
  git,
}:
# AnyTone AT-D878UV codeplug wrapper around dmrconf. The codeplug source is
# build.py in $D878_DIR (default ~/radio/anytone-868, its own git repo).
#
# Why this exists: dmrconf only switches the 878's GPS on when a write passes
# --auto-enable-gps (there is no YAML field for it), so a bare
# `dmrconf write` turns GPS OFF and the APRS beacon silently stops.
# `d878 write` always passes it.
writeShellApplication {
  name = "d878";
  runtimeInputs = [
    qdmr
    python3
    usbutils
    coreutils
    gnugrep
    git
  ];
  text = ''
    dir="''${D878_DIR:-$HOME/radio/anytone-868}"
    radio=d878uv
    cd "$dir"

    usage() {
      cat <<EOF
    d878 write     build.py -> verify -> write (GPS on, clock synced) -> read back
    d878 read [f]  read the radio to f (default backup-YYYY-MM-DD-HHMM.yaml)
    d878 verify    build.py -> offline verify only, radio untouched
    d878 db        load the RadioID callsign database (callsigns on screen)
    dir: $dir (override with D878_DIR)
    EOF
    }

    need_radio() {
      lsusb | grep -q 28e9: || { echo "radio not on USB (power on, push the plug in fully)" >&2; exit 1; }
    }

    # The radio reboots after every session and drops off USB for ~15 s.
    wait_radio() {
      sleep 15
      for _ in $(seq 1 20); do lsusb | grep -q 28e9: && { sleep 4; return; }; sleep 3; done
      echo "radio did not come back on USB" >&2; exit 1
    }

    build() {
      python3 build.py
      dmrconf verify --radio=$radio new-codeplug.yaml
    }

    case "''${1:-}" in
      write)
        build
        need_radio
        dmrconf --auto-enable-gps --update-device-clock write --radio=$radio new-codeplug.yaml
        echo "written; waiting for reboot to read back"
        wait_radio
        dmrconf read readback.yaml
        git add -A && git commit -qm "d878 write $(date +%F\ %H:%M)" || true
        echo "done; readback.yaml committed"
        ;;
      read)
        need_radio
        dmrconf read "''${2:-backup-$(date +%F-%H%M).yaml}"
        ;;
      verify) build ;;
      db)
        need_radio
        dmrconf write-db --radio=$radio -i "$(grep -oP 'number: \K\d+' new-codeplug.yaml | head -1)"
        ;;
      *) usage ;;
    esac
  '';
}
