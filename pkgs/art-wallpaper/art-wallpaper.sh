# art-wallpaper: pick a random public-domain painting from the Cleveland
# Museum of Art open-access API and stage it for the quickshell wallpaper.
#
# Writes into $XDG_CACHE_HOME/art-wallpaper:
#   <id>.jpg       the painting (CMA "print" size, ~3400px long edge)
#   current.json   {id,title,artist,date,url,image,file}; quickshell watches
#                  this file, so it is written last and renamed into place
#   history.jsonl  one line per painting shown, to find one you liked again
#
# Why Cleveland: the Art Institute of Chicago's image server sits behind a
# Cloudflare bot challenge (403 to curl, 2026-10), and the Met's API does not
# list image dimensions, so it can't filter for screen-shaped paintings
# without downloading each one. CMA lists width/height in the search result.
#
# `art-wallpaper pin [--new] [FILE]` writes the current painting (or, with
# --new, a fresh random one) plus its hash to FILE, by default the repo's
# pkgs/art-wallpaper/pinned.json, for the art-pinned strategy to fetchurl.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/art-wallpaper"
api="https://openaccess-api.clevelandart.org/api/artworks/"
filter="type=Painting&has_image=1&cc0=1"
ua="art-wallpaper (personal desktop wallpaper)"

fetch() { curl -fsS --retry 3 --retry-all-errors -A "$ua" "$@"; }

next() {
  mkdir -p "$cache"
  total=$(fetch "$api?$filter&limit=1" | jq '.info.total')

  # About 6 in 100 paintings are landscape and big enough, so try a few pages.
  pick=""
  for _ in 1 2 3 4 5; do
    skip=$(shuf -i "0-$((total - 100))" -n 1)
    pick=$(fetch "$api?$filter&limit=100&skip=$skip&fields=id,title,creation_date,creators,culture,images,url" \
      | jq -c '.data[]
          | select(.images.print != null)
          | (.images.print.width | tonumber) as $w
          | (.images.print.height | tonumber) as $h
          | select($w >= 2400 and $w / $h >= 1.25 and $w / $h <= 2.1)
          | {
              id,
              title,
              artist: ((.creators[0].description // .culture[0] // "Unknown artist") | sub(" \\(.*$"; "")),
              date: (.creation_date // ""),
              url,
              image: .images.print.url
            }' \
      | shuf -n 1)
    [ -n "$pick" ] && break
  done
  if [ -z "$pick" ]; then
    echo "art-wallpaper: no landscape painting found in 5 pages" >&2
    exit 1
  fi

  id=$(jq -r '.id' <<<"$pick")
  fetch -o "$cache/$id.jpg.tmp" "$(jq -r '.image' <<<"$pick")"
  mv "$cache/$id.jpg.tmp" "$cache/$id.jpg"

  jq --arg file "$id.jpg" '. + {file: $file}' <<<"$pick" >"$cache/current.json.tmp"
  mv "$cache/current.json.tmp" "$cache/current.json"
  jq -c --arg at "$(date -Iseconds)" '. + {shown: $at}' "$cache/current.json" >>"$cache/history.jsonl"

  # Keep the current and previous image; quickshell crossfades between them.
  find "$cache" -maxdepth 1 -name '*.jpg' -printf '%T@ %p\n' \
    | sort -rn | tail -n +3 | cut -d' ' -f2- | xargs -r rm -f

  info
}

info() {
  jq -r '"\(.title)\n\(.artist)\(if .date != "" then ", \(.date)" else "" end)\n\(.url)"' "$cache/current.json"
}

pin() {
  if [ "${1:-}" = "--new" ]; then
    next >/dev/null
    shift
  fi
  out="${1:-$HOME/.config/nixpkgs/pkgs/art-wallpaper/pinned.json}"
  # Same bytes fetchurl will download, so this hash is the one it checks.
  hash=$(nix hash file --type sha256 --sri "$cache/$(jq -r '.file' "$cache/current.json")")
  jq --arg hash "$hash" '{id, title, artist, date, url, image, hash: $hash}' \
    "$cache/current.json" >"$out"
  echo "pinned to $out:"
  info
}

case "${1:-next}" in
  next) next ;;
  info) info ;;
  pin)
    shift
    pin "$@"
    ;;
  open) xdg-open "$(jq -r '.url' "$cache/current.json")" ;;
  *)
    echo "usage: art-wallpaper [next|info|open|pin [--new] [FILE]]" >&2
    exit 2
    ;;
esac
