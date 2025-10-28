# Paywall Testing System - Usage Guide

## Overview
This system provides a clean, repeatable way to test your paywall flow during development. It automatically disables in release builds, so you don't need to worry about accidentally shipping debug code.

## How to Access the Debug Menu

### Method 1: Secret Tap Gesture (Recommended)
1. Launch your app in debug mode
2. On the main screen, tap quickly in the **top-left corner** 5 times within 2 seconds
3. The debug menu will appear

### Method 2: Direct Integration
If you want a more obvious way to access it during development, you can add a visible button temporarily.

## Debug Menu Functions

### 🔄 Reset & Show Paywall (Primary Function)
- **What it does**: Clears all subscription data and forces the app to show the paywall
- **Use case**: Testing the first-time user experience and paywall flow
- **Result**: App will behave as if it's the first launch with no subscription

### 🔄 Restore Normal Operation
- **What it does**: Restores normal subscription detection (honors real subscriptions)
- **Use case**: Return to normal app behavior after testing
- **Result**: App will recognize your sandbox/real subscriptions again

### ✅ Enable Sub / ❌ Disable Sub
- **What they do**: Temporarily override subscription status without clearing usage data
- **Use case**: Quick testing of subscribed vs non-subscribed states
- **Result**: Instantly toggle between subscriber and non-subscriber experience

## Typical Testing Workflow

1. **Start Testing**: Tap 5 times in top-left corner → Tap "Reset & Show Paywall"
2. **Test Paywall**: Go through your subscription flow, test UI, test purchase
3. **Test Variations**: Use Enable/Disable Sub buttons to test different states quickly
4. **Reset Again**: Tap "Reset & Show Paywall" to test the flow fresh
5. **End Session**: Tap "Restore Normal Operation" when done testing

## Automatic Safety Features

### Debug Build Only
- All debug functionality is wrapped in `#if DEBUG` blocks
- **Release builds will have ZERO debug code included**
- No risk of shipping debug functionality to customers

### Automatic Reset Protection
- The system automatically ignores sandbox subscriptions when testing paywall
- Clears all usage tracking to ensure clean test state
- Detailed logging helps you understand what's happening

## For Deployment

### Zero Action Required! 
When you build for release:
- All debug code is automatically excluded
- No debug menus, no secret gestures, no debug functions
- Your app will behave exactly as intended for customers

### Optional: Remove Debug Files
If you want to be extra clean, you can remove these files before release:
- `DebugSubscriptionView.swift` (but it's already debug-only)

## Troubleshooting

### "Still showing as subscribed after reset"
- Make sure you're in a Debug build (not Release)
- Try "Restore Normal Operation" then "Reset & Show Paywall" again
- Check the console logs for debug messages

### "Can't find the debug menu"
- Tap quickly 5 times in the very top-left corner
- Make sure you're tapping within 2 seconds
- Only works in Debug builds

### "Want to test real purchases"
- Use "Restore Normal Operation" to honor real StoreKit subscriptions
- Remember: sandbox purchases in development, real purchases in production

## Console Logs
Look for these categories in your console:
- `DEBUG`: Debug menu operations  
- `TEST_CORE_STATUS`: Subscription status changes
- `SUBSCRIPTION`: Purchase flow details

This system gives you complete control over testing while being completely safe for production deployment.