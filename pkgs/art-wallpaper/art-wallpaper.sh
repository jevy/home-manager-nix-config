# art-wallpaper: pick a random public-domain painting from the Cleveland
# Museum of Art open-access API and stage it for the quickshell wallpaper.
#
# Writes into $XDG_CACHE_HOME/art-wallpaper:
#   <id>.jpg       the painting (CMA "print" size, ~3400px long edge)
#   <id>.full.jpg  the full-resolution scan (up to ~12000px), converted from
#                  CMA's TIFF because quickshell's Qt has no TIFF reader;
#                  quickshell loads it only while you zoom in
#   current.json   {id,title,artist,date,url,image,fullImage,file[,full]};
#                  quickshell watches this file, so it is renamed into place,
#                  once with the small image and again when `full` is ready
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
              image: .images.print.url,
              fullImage: (.images.full.url // "")
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
  backdrop=$(backdrop_fill "$cache/$id.jpg")
  if [ -n "$backdrop" ]; then
    fill_backdrop "$cache/$id.jpg" "$backdrop"
  fi

  jq --arg file "$id.jpg" '. + {file: $file}' <<<"$pick" >"$cache/current.json.tmp"
  mv "$cache/current.json.tmp" "$cache/current.json"
  jq -c --arg at "$(date -Iseconds)" '. + {shown: $at}' "$cache/current.json" >>"$cache/history.jsonl"

  # Keep the current and previous painting's files; quickshell crossfades
  # from the previous one.
  keep=$(tail -n 2 "$cache/history.jsonl" | jq -r '.id')
  for f in "$cache"/*.jpg "$cache"/*.tif; do
    [ -e "$f" ] || continue
    name=${f##*/}
    grep -qx "${name%%.*}" <<<"$keep" || rm -f "$f"
  done

  info

  # The wallpaper is already up; the full scan is a bonus for zooming, so a
  # failure here is logged, not fatal. Typical: 126 MB TIFF, ~3 s download,
  # <1 s to convert, 12 MB JPEG.
  if ! fetch_full "$id" "$backdrop"; then
    echo "art-wallpaper: full-resolution download failed for $id" >&2
  fi
}

# A dark painting photographed on the museum's light backdrop (an oval canvas,
# a panel with margins) gets a bright frame around a dark wallpaper. If the
# centre is dark and the corner light, print the painting's most common colour
# (5 clusters, measured on the centre so the backdrop can't win); otherwise
# print nothing and leave the image alone.
backdrop_fill() {
  local f=$1 centre corner
  centre=$(magick "$f" -gravity center -crop 50%x50%+0+0 -colorspace Gray -format '%[fx:mean]' info:)
  corner=$(magick "$f" -crop 2%x2%+0+0 -colorspace Gray -format '%[fx:mean]' info:)
  awk -v m="$centre" -v c="$corner" 'BEGIN { exit !(m < 0.35 && c > 0.6) }' || return 0
  magick "$f" -gravity center -crop 50%x50%+0+0 +repage -scale 200x200 -colors 5 -depth 8 \
    -format %c histogram:info: | sort -rn | awk 'NR == 1 { print $3 }'
}

# Flood the backdrop in one pass from a 1px frame in the corner colour, which
# joins all four corners. Filling corner by corner breaks: the second fill
# starts on the dark colour the first one laid down and spreads into the
# painting. 40% fuzz also takes the grey shadow ring an oval canvas casts.
fill_backdrop() {
  local f=$1 colour=$2
  magick "$f" -bordercolor '%[pixel:p{0,0}]' -border 1 -fuzz 40% -fill "$colour" \
    -draw 'color 0,0 floodfill' -shave 1 -quality 90 "${f%.jpg}.fill.jpg"
  mv "${f%.jpg}.fill.jpg" "$f"
}

fetch_full() {
  local id=$1 backdrop=$2 url
  url=$(jq -r '.fullImage // ""' "$cache/current.json")
  [ -n "$url" ] || return 0
  fetch -o "$cache/$id.full.tif" "$url"
  vips colourspace "$cache/$id.full.tif" "$cache/$id.full.part.jpg[Q=90,optimize_coding]" srgb
  # A GPU texture tops out at 16384px a side; quickshell can't show more.
  if [ "$(vipsheader -f width "$cache/$id.full.part.jpg")" -gt 16384 ] \
    || [ "$(vipsheader -f height "$cache/$id.full.part.jpg")" -gt 16384 ]; then
    vips thumbnail "$cache/$id.full.part.jpg" "$cache/$id.full.small.jpg[Q=90,optimize_coding]" 16384 --size down
    mv "$cache/$id.full.small.jpg" "$cache/$id.full.part.jpg"
  fi
  rm -f "$cache/$id.full.tif"
  if [ -n "$backdrop" ]; then
    fill_backdrop "$cache/$id.full.part.jpg" "$backdrop"
  fi
  mv "$cache/$id.full.part.jpg" "$cache/$id.full.jpg"
  # Another `next` may have replaced the painting meanwhile.
  jq --argjson id "$id" --arg full "$id.full.jpg" \
    'if .id == $id then . + {full: $full} else . end' \
    "$cache/current.json" >"$cache/current.json.tmp"
  mv "$cache/current.json.tmp" "$cache/current.json"
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
