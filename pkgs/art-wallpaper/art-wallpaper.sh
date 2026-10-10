# art-wallpaper: pick a random public-domain painting from the Cleveland
# Museum of Art open-access API and stage it for the quickshell wallpaper.
#
# Writes into $XDG_CACHE_HOME/art-wallpaper:
#   <id>.jpg       the painting (CMA "print" size, ~3400px long edge)
#   <id>.full.jpg  the full-resolution scan (up to ~12000px), converted from
#                  CMA's TIFF because quickshell's Qt has no TIFF reader;
#                  quickshell loads it only while you zoom in
#   current.json   {id,title,artist,date,size,url,image,webImage,fullImage,
#                  description,did_you_know,technique,tombstone,file
#                  [,guide,guideModel][,full]}; quickshell watches this file,
#                  so it is renamed into place, once with the small image and
#                  again as each of `guide` and `full` arrives
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
#
# Guide: an OpenRouter model ($model, ~$0.0005 and ~6 s per painting) gets
# the museum record plus the 900px image and returns a structured guide
# (hook, 3 why-it-matters points, 3 details to find by zooming, a longer
# "deeper" write-up) for the quickshell caption bubble. Laid out for quick
# scanning: short, fixed shape, no repeats of the museum text. The key file
# is baked in by default.nix from sops; without it, paintings just have the
# museum text.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/art-wallpaper"
api="https://openaccess-api.clevelandart.org/api/artworks/"
filter="type=Painting&has_image=1&cc0=1"
ua="art-wallpaper (personal desktop wallpaper)"
keyfile="${ART_WALLPAPER_KEY_FILE:-@keyfile@}"
model="${ART_WALLPAPER_MODEL:-z-ai/glm-5.3-flash}"

fetch() { curl -fsS --retry 3 --retry-all-errors -A "$ua" "$@"; }

next() {
  mkdir -p "$cache"
  total=$(fetch "$api?$filter&limit=1" | jq '.info.total')

  # About 11 in 100 paintings are landscape and big enough, so try a few pages.
  # Of those ~450, 36% are Chinese, Japanese or Korean (handscrolls and album
  # leaves are wide), so they kept coming up: keep 1 in 5 of them, for about
  # 1 wallpaper in 10. That check runs after picking, not before, because
  # search pages come in accession order and one page can hold a dozen
  # scrolls, one of which would survive a per-item cut. Paintings already in
  # history.jsonl are skipped.
  seen=$(jq -sc 'map(.id)' "$cache/history.jsonl" 2>/dev/null || echo '[]')
  pick=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    skip=$(shuf -i "0-$((total - 100))" -n 1)
    pick=$(fetch "$api?$filter&limit=100&skip=$skip&fields=id,title,creation_date,creators,culture,images,url,description,did_you_know,technique,tombstone" \
      | jq -c --argjson seen "$seen" '.data[]
          | select(.images.print != null)
          | select(.id as $id | $seen | index($id) | not)
          | (.images.print.width | tonumber) as $w
          | (.images.print.height | tonumber) as $h
          | select($w >= 2400 and $w / $h >= 1.25 and $w / $h <= 2.1)
          | {
              id,
              title,
              artist: ((.creators[0].description // .culture[0] // "Unknown artist") | sub(" \\(.*$"; "")),
              date: (.creation_date // ""),
              culture: (.culture[0] // ""),
              url,
              image: .images.print.url,
              webImage: (.images.web.url // ""),
              # Size of the painting itself, not its mount or album page:
              # first label that matches, in this order, else the first
              # measurement in cm.
              size: ((.tombstone // "") as $t
                | first(("image", "each painting", "painting", "unframed", "sheet", "overall")
                    | . as $l | $t | capture($l + ": (?<d>[0-9.]+ x [0-9.]+ cm)").d)
                  // first($t | capture("(?<d>[0-9.]+ x [0-9.]+ cm)").d) // ""),
              fullImage: (.images.full.url // ""),
              description: ((.description // "") | gsub("<[^>]*>"; "")),
              did_you_know: ((.did_you_know // "") | gsub("<[^>]*>"; "")),
              technique: (.technique // ""),
              tombstone: (.tombstone // "")
            }' \
      | shuf -n 1 \
      | awk -v seed="$RANDOM" 'BEGIN { srand(seed) } !/"culture":"(China|Japan|Korea)/ || rand() < 0.2')
    [ -n "$pick" ] && break
  done
  if [ -z "$pick" ]; then
    echo "art-wallpaper: no landscape painting found in 10 pages" >&2
    exit 1
  fi

  id=$(jq -r '.id' <<<"$pick")
  fetch -o "$cache/$id.jpg.tmp" "$(jq -r '.image' <<<"$pick")"
  mv "$cache/$id.jpg.tmp" "$cache/$id.jpg"
  wall=$(wall_colour "$cache/$id.jpg")
  backdrop=""
  if dark_on_light "$cache/$id.jpg"; then
    backdrop=$wall
    fill_backdrop "$cache/$id.jpg" "$backdrop"
  fi

  jq --arg file "$id.jpg" --arg wall "$wall" '. + {file: $file, wall: $wall}' <<<"$pick" >"$cache/current.json.tmp"
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

  # The wallpaper is already up; the guide and the full scan are extras, so
  # a failure in either is logged, not fatal. The guide first: it's quicker
  # (~5 s) than a big scan. Typical scan: 126 MB TIFF, ~3 s download, <1 s
  # to convert, 12 MB JPEG.
  if ! fetch_guide "$id"; then
    echo "art-wallpaper: guide failed for $id" >&2
  fi
  if ! fetch_full "$id" "$backdrop"; then
    echo "art-wallpaper: full-resolution download failed for $id" >&2
  fi
}

# The gallery wall a painting hangs on when it doesn't fill a screen (the
# ultrawide), and the fill for a dark painting's light backdrop: the most
# common of 5 colour clusters in the centre 60% (so museum backdrops and
# mounts don't win), saturation x0.6, lightness fixed at 22% so every wall
# reads as the same muted tone whatever the painting.
wall_colour() {
  local dom
  dom=$(magick "$1" -gravity center -crop 60%x60%+0+0 +repage -scale 200x200 -colors 5 -depth 8 \
    -format %c histogram:info: | sort -rn | awk 'NR == 1 { print $3 }')
  magick xc:"$dom" -colorspace HSL -channel G -evaluate multiply 0.6 -channel B -evaluate set 22% \
    +channel -colorspace sRGB -depth 8 -format '#%[hex:p{0,0}]' info:
}

# A dark painting photographed on the museum's light backdrop (an oval canvas,
# a panel with margins) gets a bright frame around a dark wallpaper: true if
# the centre is dark and all four corners light. One corner is not enough: a
# white paint chip in the top left of an edge-to-edge canvas (CMA 133151,
# 2026-10) passed that test and the fill then flooded the whole painting.
dark_on_light() {
  local f=$1 centre corners
  centre=$(magick "$f" -gravity center -crop 50%x50%+0+0 -colorspace Gray -format '%[fx:mean]' info:)
  corners=$(for g in NorthWest NorthEast SouthWest SouthEast; do
    magick "$f" -gravity "$g" -crop 2%x2%+0+0 -colorspace Gray -format '%[fx:mean]\n' info:
  done)
  awk -v m="$centre" 'BEGIN { min = 1 } { if ($1 < min) min = $1 } END { exit !(m < 0.35 && min > 0.6) }' <<<"$corners"
}

# Flood the backdrop in one pass from a 1px frame in the corner colour, which
# joins all four corners. Filling corner by corner breaks: the second fill
# starts on the dark colour the first one laid down and spreads into the
# painting. 40% fuzz also takes the grey shadow ring an oval canvas casts.
# If the fill leaves a near-flat image it has eaten the painting, so the
# original is kept.
fill_backdrop() {
  local f=$1 colour=$2 sd
  magick "$f" -bordercolor '%[pixel:p{0,0}]' -border 1 -fuzz 40% -fill "$colour" \
    -draw 'color 0,0 floodfill' -shave 1 -quality 90 "${f%.jpg}.fill.jpg"
  sd=$(magick "${f%.jpg}.fill.jpg" -scale 400x400 -colorspace Gray -format '%[fx:standard_deviation]' info:)
  if awk -v s="$sd" 'BEGIN { exit !(s < 0.02) }'; then
    echo "art-wallpaper: backdrop fill flattened ${f##*/} (sd $sd), keeping the original" >&2
    rm -f "${f%.jpg}.fill.jpg"
    return 0
  fi
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
  set_current "$id" full "$id.full.jpg"
}

# Add key=value to current.json (--arg for a string, --argjson for JSON),
# unless another `next` has replaced the painting meanwhile.
set_current() {
  local id=$1 key=$2 value=$3 kind=${4:---arg}
  jq --argjson id "$id" --arg key "$key" "$kind" value "$value" \
    'if .id == $id then .[$key] = $value else . end' \
    "$cache/current.json" >"$cache/current.json.tmp"
  mv "$cache/current.json.tmp" "$cache/current.json"
}

fetch_guide() {
  local id=$1 record image content body guide
  if [ ! -r "$keyfile" ]; then
    echo "art-wallpaper: no OpenRouter key at $keyfile, skipping the guide" >&2
    return 0
  fi
  record=$(jq '{title, artist, date, size, technique, tombstone, description, did_you_know}' "$cache/current.json")
  image=$(jq -r '.webImage // ""' "$cache/current.json")
  # With the image the model can point at details that are really there.
  content=$(jq -n --arg rec "$record" --arg img "$image" \
    '[{type: "text", text: $rec}] + (if $img != "" then [{type: "image_url", image_url: {url: $img}}] else [] end)')
  body=$(jq -n --arg model "$model" --arg sys "$guide_prompt" --argjson content "$content" \
    --argjson schema "$guide_schema" \
    '{model: $model, max_tokens: 2000, reasoning: {effort: "low"},
      response_format: {type: "json_schema", json_schema: {name: "guide", strict: true, schema: $schema}},
      messages: [{role: "system", content: $sys}, {role: "user", content: $content}]}')
  # Key goes in via a header file so it never shows up in `ps`.
  guide=$(curl -fsS --retry 2 https://openrouter.ai/api/v1/chat/completions \
    -H @<(printf 'Authorization: Bearer %s\n' "$(<"$keyfile")") \
    -H 'Content-Type: application/json' -H 'X-Title: art-wallpaper' -d "$body" \
    | jq -c '.choices[0].message.content // "" | fromjson? // empty
        | select(.hook and .why and .find and .deeper)
        | .why |= .[:3] | .find |= .[:3]')
  [ -n "$guide" ] || return 1
  set_current "$id" guide "$guide" --argjson
  set_current "$id" guideModel "$model"
}

guide_prompt='You are a museum docent writing a quick guide for a smart reader with ADHD who has this painting as their desktop wallpaper and can zoom into it. You get the museum record and the image.

Rules: plain English, concrete, no puffery, no em dashes. Ground facts in the museum record and what is visible in the image. You may add well-established general context about the tradition, period or artist, but never invent specifics about this object (dates, provenance, owners, attributions); if uncertain, say so.

Fields:
- hook: one sentence, under 20 words, the single most interesting thing about this painting.
- why: exactly 3 items. lead is 1 to 3 words naming the point; text is under 15 words.
- find: exactly 3 visible details worth zooming into, each under 15 words, saying where to look (e.g. "upper left"). Only details you can see in the image.
- deeper: 150 to 250 words of markdown for going further: the tradition and period, how this work fits, what the museum text says that the bullets left out. No headings. 3 or 4 short paragraphs, each starting with a bold lead-in of 2 to 4 words. Do not repeat the bullets.'

guide_schema='{
  "type": "object",
  "additionalProperties": false,
  "required": ["hook", "why", "find", "deeper"],
  "properties": {
    "hook": {"type": "string"},
    "why": {"type": "array", "minItems": 3, "maxItems": 3, "items": {
      "type": "object", "additionalProperties": false, "required": ["lead", "text"],
      "properties": {"lead": {"type": "string"}, "text": {"type": "string"}}}},
    "find": {"type": "array", "minItems": 3, "maxItems": 3, "items": {"type": "string"}},
    "deeper": {"type": "string"}
  }
}'

about() {
  info
  jq -r '[
      (.guide // empty | "\n\(.hook)",
        "\nWHY IT MATTERS", (.why[] | "- \(.lead): \(.text)"),
        "\nFIND IT", (.find[] | "- \(.)"),
        "\nGOING DEEPER (AI)", .deeper),
      (if .did_you_know != "" then "\nDid you know: \(.did_you_know)" else empty end),
      (if .description != "" then "\n\(.description)" else empty end)
    ] | join("\n")' "$cache/current.json"
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
  jq --arg hash "$hash" '{id, title, artist, date, size, wall, url, image, webImage, description, did_you_know, technique, tombstone, guide, guideModel, hash: $hash}' \
    "$cache/current.json" >"$out"
  echo "pinned to $out:"
  info
}

case "${1:-next}" in
  next) next ;;
  info) info ;;
  about) about ;;
  guide) fetch_guide "$(jq -r '.id' "$cache/current.json")" && about ;;
  pin)
    shift
    pin "$@"
    ;;
  open) xdg-open "$(jq -r '.url' "$cache/current.json")" ;;
  *)
    echo "usage: art-wallpaper [next|info|about|guide|open|pin [--new] [FILE]]" >&2
    exit 2
    ;;
esac
