#!/bin/bash
# Convert a screen recording to GIF for the README
# Usage: bash assets/make-gif.sh <input.mov>
#
# Requires ffmpeg: brew install ffmpeg

set -e

INPUT="${1:?Usage: bash assets/make-gif.sh <input.mov>}"
OUTPUT="assets/demo.gif"

echo "Converting $INPUT to $OUTPUT..."
ffmpeg -i "$INPUT" \
  -vf "fps=12,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  -loop 0 \
  "$OUTPUT" -y

echo "Done! GIF saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
