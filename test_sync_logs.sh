#!/bin/bash

# Script to monitor sync logs for testing Last Modified Wins strategy

echo "🔍 Finding most recent DebugConsole.log..."

# Find the most recent log file
LOG_FILE=$(find ~/Library/Developer/CoreSimulator -name "DebugConsole.log" -exec ls -t {} + 2>/dev/null | head -1)

if [ -z "$LOG_FILE" ]; then
    echo "❌ No DebugConsole.log found. Make sure app is running in simulator."
    exit 1
fi

echo "📄 Monitoring: $LOG_FILE"
echo "🧪 Testing Instructions:"
echo "1. Open Mariner Studio app in simulator"
echo "2. Navigate to Tide Favorites"
echo "3. Tap the orange 'TEST' button to run conflict resolution test"
echo "4. Or manually favorite/unfavorite stations and tap sync"
echo "5. Watch this terminal for sync logs"
echo ""
echo "🔍 Key log patterns to watch for:"
echo "   🔧🌊 CONFLICT: - Conflict resolution details"
echo "   📤🌊 UPLOAD: - Local to remote uploads"
echo "   📥🌊 DOWNLOAD: - Remote to local downloads"
echo "   ✅🔧🌊 CONFLICT: - Successful resolutions"
echo ""
echo "📊 Starting log monitor..."
echo "----------------------------------------"

# Monitor the log file for sync-related entries
tail -f "$LOG_FILE" | grep --line-buffered -E "(🌊|TEST:|SYNC|CONFLICT|UPLOAD|DOWNLOAD|TideStationSyncService)"