#!/usr/bin/env bash
#
# PrivaClip Feature Screen Recording Script
# Uses macOS native screencapture utility to record a clean feature walkthrough video.
#

set -euo pipefail

OUTPUT_VIDEO="${1:-PrivaClip-Feature-Demo.mp4}"
DURATION="${2:-15}" # Default 15 seconds recording

echo "=========================================================="
echo "🎬 PrivaClip Native macOS Feature Demo Recorder"
echo "=========================================================="
echo
echo "This script uses native macOS 'screencapture' to record a demo video."
echo "Target output: $OUTPUT_VIDEO"
echo "Duration:      $DURATION seconds"
echo
echo "💡 Preparation Checklist:"
echo "  1. Make sure PrivaClip is running: (open build/PrivaClip.app)"
echo "  2. Open a text editor (e.g. TextEdit or Notes) in the background."
echo "  3. When the countdown ends, press ⌥V to open the PrivaClip panel."
echo "  4. Use ↑ / ↓ arrow keys to select items, switch tabs, or search."
echo "  5. Press Return to auto-paste into your editor."
echo
echo "Populating sample clipboard items for the demo..."
echo "https://gitlab.com/privaclip/demo" | pbcopy
sleep 0.5
echo "#3B82F6" | pbcopy
sleep 0.5
echo "func secureHash(data: Data) -> String { SHA256.hash(data: data).description }" | pbcopy
sleep 0.5
echo "hello@privaclip.local" | pbcopy
echo "✅ Sample clips ready!"
echo

for i in 5 4 3 2 1; do
    echo "Starting screen recording in $i seconds... (Switch to your window now)"
    sleep 1
done

echo "🔴 RECORDING STARTED! Press ⌥V and showcase PrivaClip now..."
# -v records video; -V specifies recording duration in seconds
screencapture -v -V "$DURATION" "$OUTPUT_VIDEO"

echo
echo "=========================================================="
echo "🎉 Recording finished successfully!"
echo "   Saved video to: $(pwd)/$OUTPUT_VIDEO"
echo "=========================================================="
echo
echo "Tip: To convert this MP4 to an animated GIF for GitLab README:"
echo "  ffmpeg -i \"$OUTPUT_VIDEO\" -vf \"fps=15,scale=800:-1:flags=lanczos\" -c:v gif privaclip-demo.gif"
