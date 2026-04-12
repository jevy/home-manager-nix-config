# steam-playtime: dump owned Steam games ranked by total playtime.
#
# Reads sops secrets `steam_api_key` and `steam_id` at runtime.
# Usage:
#   steam-playtime            # pretty table: hours  last_played  name
#   steam-playtime --csv      # CSV with appid, suitable for LLM recs
#   steam-playtime --json     # raw Steam Web API response
{ ... }:
{
  flake.modules.homeManager.steamPlaytime =
    { config, pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "steam-playtime";
          runtimeInputs = with pkgs; [ curl jq gawk ];
          text = ''
            KEY=$(cat "${config.sops.secrets.steam_api_key.path}")
            SID=$(cat "${config.sops.secrets.steam_id.path}")

            json=$(curl -sfG "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/" \
              --data-urlencode "key=$KEY" \
              --data-urlencode "steamid=$SID" \
              --data-urlencode "include_appinfo=1" \
              --data-urlencode "include_played_free_games=1" \
              --data-urlencode "format=json")

            if ! printf '%s' "$json" | jq -e '.response.games' >/dev/null 2>&1; then
              echo "steam-playtime: unexpected API response" >&2
              printf '%s\n' "$json" >&2
              exit 1
            fi

            case "''${1:-}" in
              --csv)
                printf '%s' "$json" | jq -r '
                  ["hours","last_played","appid","name"],
                  (.response.games
                    | map(select(.playtime_forever > 0))
                    | sort_by(-.playtime_forever)[]
                    | [
                        (.playtime_forever/60 | . * 10 | floor / 10),
                        (if .rtime_last_played > 0
                           then (.rtime_last_played | strftime("%Y-%m-%d"))
                           else "never" end),
                        .appid,
                        .name
                      ]) | @csv'
                ;;
              --json)
                printf '%s' "$json" | jq
                ;;
              -h|--help)
                cat <<HELP
            Usage: steam-playtime [--csv|--json|--help]

            Fetches owned Steam games sorted by total playtime (descending).
            Credentials are read from sops (stream_api_key, steam_id).

              (no args)  Pretty table: hours | last_played | name
              --csv      CSV with header, includes appid
              --json     Raw Steam Web API response
              --help     This message
            HELP
                ;;
              "")
                printf '%s' "$json" | jq -r '
                  .response.games
                  | map(select(.playtime_forever > 0))
                  | sort_by(-.playtime_forever)[]
                  | [
                      ((.playtime_forever/60 | floor | tostring) + "h"),
                      (if .rtime_last_played > 0
                         then (.rtime_last_played | strftime("%Y-%m-%d"))
                         else "never" end),
                      .name
                    ] | @tsv' \
                | awk -F'\t' '{printf "%-7s  %-12s  %s\n", $1, $2, $3}'
                ;;
              *)
                echo "steam-playtime: unknown option: $1" >&2
                echo "try: steam-playtime --help" >&2
                exit 1
                ;;
            esac
          '';
        })
      ];
    };
}
