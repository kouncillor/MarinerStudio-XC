# Real-Time Log Streaming Setup

## Overview
This document outlines the complete setup and usage of real-time log streaming for the Mariner Studio iOS application using Logflare, enabling efficient remote debugging and collaboration.

## System Architecture

### Components
- **iOS App**: Mariner Studio application with integrated DebugLogger
- **Logflare**: Real-time log aggregation and viewing service
- **Public URL**: Shareable link for viewing logs without authentication

### Data Flow
```
iOS App (DebugLogger) → Logflare API → Logflare Dashboard → Public URL
```

## Current Configuration

### Logflare Account Details
- **Service**: Logflare (owned by Supabase)
- **Source Name**: MarinerStudio.all
- **Source ID**: `cbbeb35e-1ddd-4ad5-8fe0-fb80e859351b`
- **API Key**: `6BeJRu7WWywv`
- **Dashboard URL**: https://logflare.app/dashboard
- **Source URL**: https://logflare.app/sources/35709
- **Public URL**: https://logflare.app/sources/public/aRjXAXyUU10ZNVGL

### API Endpoint Configuration
- **Endpoint**: `https://api.logflare.app/logs/json`
- **Method**: POST
- **Content-Type**: `application/json; charset=utf-8`
- **Authentication**: X-API-KEY header
- **Rate Limit**: 5 events/second average (free tier)

## Implementation Details

### iOS Integration
The `DebugLogger` class automatically streams all log events to Logflare:

```swift
// Location: Services/DebugLogger.swift
private func sendToLogflare(message: String, category: String) {
    // Sends structured JSON to Logflare API
    // Includes: message, category, timestamp, app_version, device_name
}
```

### Log Data Structure
Each log entry includes:
- **message**: The actual log message
- **category**: Log category (APP_INIT, DATABASE_*, etc.)
- **timestamp**: ISO8601 formatted timestamp
- **app_version**: Bundle version from Info.plist
- **device_name**: Physical device name

### Automatic Streaming
- **Trigger**: Every `DebugLogger.shared.log()` call
- **Frequency**: Real-time (immediate POST request)
- **Scope**: Debug builds only (#if DEBUG)
- **Reliability**: Silent failure to prevent logging loops

## Usage Workflow

### For Development
1. **Start App**: Logs automatically begin streaming to Logflare
2. **Reproduce Issue**: Use app normally, all debug info streams live
3. **Share with Claude**: Provide public URL for real-time analysis
4. **Debug Collaboratively**: Remote assistance without copy-paste

### Command for Claude Assistance
```
"Check my logs at https://logflare.app/sources/public/aRjXAXyUU10ZNVGL"
```

## Public Sharing Setup

### Current Status
- ✅ **Logs streaming to Logflare**: Confirmed working
- ✅ **Public access configured**: Successfully enabled
- ✅ **Public URL accessible**: Working without authentication

### Required Setup Steps
1. **Enable Public Access**:
   - Navigate to Logflare source settings
   - Look for "Make Public" or "Share Source" option
   - Enable public viewing without authentication

2. **Configure Public URL**:
   - Generate shareable public link
   - Test accessibility without login
   - Update documentation with working public URL

### Expected Public URL Features
- **No Authentication Required**: Direct access to logs
- **Real-time Updates**: Live streaming log display
- **Filtering Options**: Category-based log filtering
- **Search Capability**: Find specific log entries
- **Export Options**: Download logs if needed

## Free Tier Limitations

### Logflare Free Plan
- **Events**: 12,960,000 per month (~432,000 per day)
- **Rate Limit**: 5 events per second average
- **Retention**: 3 days of log history
- **Sources**: Unlimited
- **Fields**: Up to 50 different log fields

### Practical Impact
- **Daily Debugging**: Can log ~300 lines/minute for 24 hours
- **Intensive Sessions**: Support for heavy debug logging
- **Retention Window**: 3 days perfect for active development
- **Cost**: Free for typical development usage

## Troubleshooting

### Common Issues

**1. Logs Not Appearing**
- Check network connectivity on device
- Verify API key in DebugLogger.swift
- Confirm source ID matches Logflare dashboard
- Check rate limiting (max 5 events/second)

**2. Public URL Not Working**
- Ensure public access is enabled in Logflare
- Check source permissions and sharing settings
- Verify URL format and source ID

**3. Missing Log Data**
- Confirm app is running in DEBUG mode
- Check DebugLogger integration in app startup
- Verify JSON serialization of log entries

### Debug Commands

**Test Log Streaming**:
```swift
DebugLogger.shared.sendTestLogToLogflare()
```

**Check Integration**:
```bash
# Test via curl
curl -X "POST" "https://api.logflare.app/logs/json?source=cbbeb35e-1ddd-4ad5-8fe0-fb80e859351b" \
     -H 'Content-Type: application/json; charset=utf-8' \
     -H 'X-API-KEY: 6BeJRu7WWywv' \
     -d '[{"message": "Test from curl", "category": "TEST"}]'
```

## Security Considerations

### Data Privacy
- **Log Content**: Contains app debug information, no user PII
- **Device Information**: Device name and app version included
- **Authentication**: API key embedded in app (acceptable for debug builds)
- **Public Access**: Logs visible to anyone with URL (when public)

### Best Practices
- **Debug Only**: Streaming disabled in release builds
- **Sensitive Data**: Avoid logging passwords, tokens, or PII
- **API Key Management**: Consider environment-based configuration
- **Public URL**: Share only during active debugging sessions

## Benefits

### Developer Experience
- **No Copy-Paste**: Eliminates manual log extraction from Xcode
- **Real-time Debugging**: See logs as app runs on physical device
- **Remote Collaboration**: Share live logs with team or AI assistance
- **Complete Context**: Full log history available during debug sessions

### Workflow Improvements
- **Faster Debugging**: Immediate access to comprehensive logs
- **Better Collaboration**: Shareable URLs for remote assistance
- **Historical Analysis**: 3-day retention for post-issue investigation
- **Multi-device Testing**: Logs from any iOS device stream to same location

## Future Enhancements

### Potential Improvements
- **Environment Configuration**: Dev/staging/prod log separation
- **Log Levels**: Error, warning, info, debug classification
- **Structured Logging**: Enhanced metadata for better filtering
- **Performance Monitoring**: Response time and error rate tracking

### Integration Options
- **CI/CD Pipeline**: Automated log analysis during builds
- **Alert System**: Email/SMS notifications for critical errors
- **Dashboard Creation**: Custom views for specific log categories
- **Export Automation**: Scheduled log exports for archival

---

**Last Updated**: January 8, 2025  
**Version**: 1.0  
**Status**: Implementation Complete, Public Access Pending