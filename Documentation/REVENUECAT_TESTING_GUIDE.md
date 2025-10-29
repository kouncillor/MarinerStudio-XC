# RevenueCat Testing Guide

This guide explains how to test paywalls and subscriptions with RevenueCat during development.

## Table of Contents
- [Understanding RevenueCat State Management](#understanding-revenuecat-state-management)
- [Debug Menu (Orange Wrench)](#debug-menu-orange-wrench)
- [Testing Workflow](#testing-workflow)
- [Testing Paywall Iterations](#testing-paywall-iterations)
- [Sandbox vs Production Testing](#sandbox-vs-production-testing)
- [Common Issues & Solutions](#common-issues--solutions)

---

## Understanding RevenueCat State Management

### How It Works

RevenueCat manages subscription state **server-side**, which is different from our old `SimpleSubscription` system:

| Old System (SimpleSubscription) | New System (RevenueCat) |
|--------------------------------|-------------------------|
| State stored in UserDefaults (local) | State stored on RevenueCat servers |
| Could fake subscription status locally | Cannot fake - must actually purchase or grant via dashboard |
| Reset by clearing UserDefaults | Reset by logging out from RevenueCat |
| Worked offline | Requires network to check status |

### Why This Matters

When you purchase a subscription in development/sandbox mode, RevenueCat remembers this purchase and associates it with:
1. **Your device/install** - Via an anonymous user ID
2. **Your Apple ID** - Via StoreKit

Simply restarting the app **won't reset this** - RevenueCat will still see the subscription.

---

## Debug Menu (Orange Wrench)

Located in the top-right toolbar of `MainView` (Debug builds only).

### Available Actions

#### 1. Reset for Testing (Logout)
**Purpose:** Clears subscription state to test paywall as a new user

**What it does:**
- Calls `Purchases.shared.logOut()`
- Creates a new anonymous user ID
- Clears all cached subscription data
- Forces RevenueCat to treat you as a brand new user

**When to use:**
- Testing paywall designs and iterations
- Testing first-time user experience
- After making a test purchase and wanting to reset

**Important:** This does NOT cancel your subscription - it just creates a new user identity. Your old subscription still exists tied to your previous user ID.

---

#### 2. Refresh Status
**Purpose:** Re-checks subscription status from RevenueCat servers

**What it does:**
- Queries RevenueCat API for latest subscription state
- Updates local state with server data
- Useful if you suspect local state is out of sync

**When to use:**
- After making a purchase in another device/build
- After manually granting/revoking subscriptions in RevenueCat dashboard
- After subscription expiration

---

#### 3. Restore Purchases
**Purpose:** Syncs purchases from Apple's servers

**What it does:**
- Calls `Purchases.shared.restorePurchases()`
- Queries Apple's StoreKit for all past purchases
- Links found purchases to current RevenueCat user

**When to use:**
- After reinstalling the app
- Testing the "Restore Purchases" user flow
- Switching between different RevenueCat user IDs

---

## Testing Workflow

### Iterating on Paywall Design

When you're making changes to your paywall in the RevenueCat dashboard:

1. **Make changes in RevenueCat Dashboard**
   - Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
   - Navigate to Offerings → default → Paywall
   - Update colors, copy, images, etc.
   - Save changes

2. **Reset your test device**
   - Open app in debug mode
   - Tap orange wrench (top-right)
   - Select "Reset for Testing (Logout)"
   - Force-quit and relaunch app

3. **View updated paywall**
   - App will show paywall as new user
   - See your latest changes
   - Test purchase flow if needed

4. **Repeat** as many times as needed

---

## Testing Paywall Iterations

### Recommended Workflow

```
Make changes in dashboard
    ↓
Reset for Testing (Logout)
    ↓
Force-quit app
    ↓
Relaunch app
    ↓
Paywall appears with changes
    ↓
Test & evaluate
    ↓
Repeat
```

### Why Force-Quit?

RevenueCat caches paywall configurations. Force-quitting ensures:
- Fresh paywall data is fetched
- No stale cached images/copy
- Clean slate for testing

---

## Sandbox vs Production Testing

### Sandbox Testing (Development)

**What:** Testing with Apple's Sandbox environment
**Where:** Xcode builds, TestFlight internal testing
**Subscription behavior:**
- Subscriptions renew every 5 minutes (instead of monthly)
- Subscriptions expire after ~30 minutes
- No real money charged
- Requires sandbox test account

**How to set up:**
1. Create sandbox tester in [App Store Connect](https://appstoreconnect.apple.com/)
   - Users and Access → Sandbox Testers
2. Sign into sandbox account on device
   - Settings → App Store → Sandbox Account
3. Test purchases use this account

### Production Testing

**What:** Testing with real Apple subscriptions
**Where:** App Store builds, TestFlight external testing
**Subscription behavior:**
- Real subscriptions with actual billing
- Normal renewal periods (monthly)
- Real money charged (can refund for testing)

**Not recommended for iterative testing!**

---

## Common Issues & Solutions

### Issue: Paywall won't show after reset

**Symptoms:** Tapped "Reset for Testing" but paywall still doesn't appear

**Solutions:**
1. Force-quit app completely (swipe up from app switcher)
2. Relaunch - fresh start with new user ID
3. If still not working, check console logs for RevenueCat errors
4. Verify you have network connection (RevenueCat needs internet)

---

### Issue: Purchased subscription won't clear

**Symptoms:** Made test purchase, want to reset, but subscription persists

**Solutions:**
1. Use "Reset for Testing (Logout)" - creates NEW user without subscription
2. Don't use "Restore Purchases" right after - that will restore the old subscription
3. For a completely fresh start:
   - Uninstall app
   - Reinstall app
   - Launch (new anonymous user created automatically)

**Why it persists:** Your old purchase is still valid and tied to your Apple ID. "Reset for Testing" creates a new RevenueCat user ID that doesn't have that purchase history.

---

### Issue: Sandbox subscriptions expiring too fast

**Symptoms:** Test subscription expires after 5-30 minutes

**Solution:** This is expected behavior for sandbox subscriptions. Apple accelerates subscription timelines:
- 1 week subscription → 3 minutes
- 1 month subscription → 5 minutes
- 1 year subscription → 1 hour

For longer testing sessions, use the "Refresh Status" button to check current state.

---

### Issue: "Cannot connect to iTunes Store" in sandbox

**Symptoms:** Purchase fails with iTunes Store error

**Solutions:**
1. Verify signed into sandbox tester account (Settings → App Store)
2. Sign OUT of your real Apple ID before testing
3. Make sure running in Debug mode (not Release)
4. Check sandbox tester email/password are correct
5. Create a new sandbox tester if issues persist

---

## Advanced Testing with RevenueCat Dashboard

For more control, use the RevenueCat dashboard:

### Grant Test Subscriptions
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Customers → Search for user (use App User ID from logs)
3. Granted Entitlements → Grant Entitlement
4. Select "Pro" entitlement
5. Set duration or make permanent

### View User Purchase History
1. Customers → Search by App User ID
2. See all purchases, active subscriptions
3. Useful for debugging why state is wrong

### Test Different Scenarios
Dashboard lets you:
- Grant/revoke entitlements manually
- Simulate different subscription states
- Test grace periods, billing retries, etc.

---

## Quick Reference

| Task | Action |
|------|--------|
| Test paywall changes | Reset for Testing → Force-quit → Relaunch |
| Test new user flow | Reset for Testing → Force-quit → Relaunch |
| Re-sync with server | Refresh Status |
| Restore old purchases | Restore Purchases |
| Check subscription expiry | Refresh Status (watch console logs) |
| Debug purchase issues | Check console logs for RevenueCat SDK messages |

---

## Additional Resources

- [RevenueCat Documentation](https://www.revenuecat.com/docs)
- [Testing Guide](https://www.revenuecat.com/docs/test-and-launch)
- [Sandbox Testing](https://www.revenuecat.com/docs/test-and-launch/sandbox)
- [RevenueCat Dashboard](https://app.revenuecat.com/)

---

## Configuration Details

**Project:** Mariner Studio
**RevenueCat API Key:** `appl_owWBbZSrntrBRGfXiVahtAozFrk`
**Product ID:** `mariner_pro_monthly15`
**Entitlement:** `Pro`
**Offering:** `default`
**Package:** `$rc_monthly`
**Price:** $2.99/month with 7-day free trial
