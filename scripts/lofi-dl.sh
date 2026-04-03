#!/usr/bin/env bash
# Download YouTube audio to ~/Music/lofi/ for mpd playback
# Usage: lofi-dl <youtube-url> [url2 ...]

export MPD_HOST="/run/user/1000/mpd.sock"
LOFI_DIR="$HOME/Music/lofi"

mkdir -p "$LOFI_DIR"

if [ $# -eq 0 ]; then
    echo "Usage: lofi-dl <youtube-url> [url2 ...]"
    exit 1
fi

for url in "$@"; do
    echo "Downloading: $url"
    yt-dlp \
        --extract-audio \
        --audio-format opus \
        --audio-quality 0 \
        --output "$LOFI_DIR/%(title)s.%(ext)s" \
        --restrict-filenames \
        --no-playlist \
        "$url"
done

echo "Updating mpd database..."
mpc update --wait "lofi" 2>/dev/null
echo "Done. $(mpc ls lofi 2>/dev/null | wc -l) tracks in lofi library."
