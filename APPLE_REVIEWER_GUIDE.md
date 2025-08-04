# Apple App Store Review Guide - Mariner Studio v12.1

**Submission ID:** 42ae42fa-134b-4146-b9ad-797fecfc960b  
**App Version:** 12.1  
**Date:** August 04, 2025

---

## Quick Access Guide for Apple Reviewers

### 🔍 How to Access In-App Purchases (Subscriptions)

**The app now allows subscription purchase WITHOUT requiring authentication first.**

1. **Launch the app** - No sign-in required
2. **Tap any feature** from the main menu (Weather, Tides, Currents, etc.)
3. **RevenueCat paywall will appear automatically** showing subscription options:
   - Weekly: $0.99/week
   - Monthly: $2.99/month  
   - Yearly: $24.99/year
4. **Complete purchase** using your sandbox test account

**Alternative path:**
- Launch app → Settings (gear icon, top right) → Any feature will trigger paywall

---

## 📋 Apple App Store Guideline Compliance

### ✅ Guideline 3.1.2 - Business - Payments - Subscriptions

**Required Links Now Available:**

**Privacy Policy:**
- **Location:** Settings → Legal → Privacy Policy
- **URL:** https://marinerstudio.com/privacy/
- **Access:** Tap opens in Safari (external browser)
- **Available:** Without authentication required

**Terms of Use:**  
- **Location:** Settings → Legal → Terms of Use
- **URL:** https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ (Apple Standard EULA)
- **Access:** Tap opens in Safari (external browser)
- **Available:** Without authentication required

**Step-by-step access:**
1. Launch app
2. Tap Settings (gear icon in top-right corner)
3. Scroll to "Legal" section
4. Tap "Privacy Policy" or "Terms of Use"
5. Links open in Safari browser

---

### ✅ Guideline 2.1 - Information Needed - In-App Purchases Access

**Subscription Products Configuration:**

All subscriptions are now accessible WITHOUT authentication:

| Product | Price | Duration | Product ID |
|---------|-------|----------|------------|
| Weekly | $0.99 | 1 Week | com.ospreyapplications.MarinerStudio.weekly2 |
| Monthly | $2.99 | 1 Month | com.ospreyapplications.MarinerStudio.monthlypro2 |
| Yearly | $24.99 | 1 Year | com.ospreyapplications.MarinerStudio.yearlypro2 |

**How to trigger subscription flow:**
1. Launch app (no sign-in required)
2. Tap any main menu item (Weather, Tides, Currents, Map, etc.)
3. RevenueCat paywall appears immediately
4. All three subscription options are displayed
5. Proceed with sandbox purchase

---

### ✅ Guideline 2.1 - Performance - App Completeness

**Trial Information Display:**
- Free trial information is now properly displayed in the subscription interface
- Trial periods are configured in App Store Connect
- RevenueCat displays trial details during purchase flow

**Receipt Validation:**
- Updated to handle both production and sandbox environments
- Proper error handling for receipt validation issues

---

### ✅ Guideline 5.1.1(v) - Data Collection - Account Deletion

**Account Deletion Functionality:**

**Access Path:**
1. Launch app
2. Sign in (create account or use existing)
3. Tap Settings (gear icon)
4. Scroll to "Account" section  
5. Tap "Delete Account"
6. Follow confirmation process

**Deletion Process:**
- Requires typing "DELETE MY ACCOUNT" confirmation
- Shows warning about permanent data loss
- Explains subscription cancellation requirements
- Final confirmation dialog
- Permanently removes all user data from Supabase
- Signs out from RevenueCat

**Important:** Users must separately cancel subscriptions in iOS Settings → Apple ID → Subscriptions

---

### ✅ Guideline 5.1.1 - Legal - Data Collection (Optional Registration)

**Registration is now OPTIONAL:**

**Previous Issue:** App forced authentication before allowing subscription purchase

**Current Behavior:** 
- App launches directly to main menu (no authentication wall)
- Users can purchase subscriptions without creating accounts
- Registration is presented as optional for enhanced features
- Benefits of registration clearly explained (sync across devices, favorites, etc.)

**Authentication Flow:**
- **Without Account:** Full app access, subscription purchase allowed
- **With Account:** Additional features like cloud sync, favorites backup

---

## 🧪 Testing Instructions for Reviewers

### Subscription Purchase Test (Primary Issue)

1. **Fresh App Install**
2. **Do NOT sign in** - verify app opens directly to main menu
3. **Tap "Weather"** (or any menu item)
4. **Verify paywall appears** with all subscription options
5. **Complete test purchase** in sandbox
6. **Verify app functions** with active subscription

### Privacy Policy & Terms Access Test

1. **Launch app** (no sign-in needed)
2. **Tap gear icon** (top-right corner)
3. **Tap "Privacy Policy"** → verify opens https://marinerstudio.com/privacy/
4. **Tap "Terms of Use"** → verify opens Apple's standard EULA
5. **Confirm both links work** without errors

### Account Deletion Test

1. **Create test account** (sign up with test email)
2. **Access Settings** → Account section
3. **Tap "Delete Account"**
4. **Follow confirmation process**
5. **Verify account is deleted** and user is signed out

---

## 📱 Device Testing

**Tested On:**
- iPhone 15 Pro (iOS 18.6)
- iPad Air (5th generation, iPadOS 18.6)
- iPhone SE (iOS 18.6)

**All Features Work:**
- Subscription purchase without authentication ✅
- Privacy Policy & Terms links accessible ✅
- Account deletion functionality ✅
- Settings accessible from main menu ✅

---

## 🔧 Technical Implementation Summary

### Changes Made to Address Rejection:

1. **Modified ContentView.swift:** Removed authentication requirement gate
2. **Created AppSettingsView.swift:** Added Privacy Policy and Terms links
3. **Added AccountDeletionView.swift:** Comprehensive account deletion flow
4. **Updated SupabaseManager.swift:** Added deleteAccount() method
5. **Modified MainView.swift:** Added settings navigation
6. **Created AuthenticationPromptView.swift:** Optional authentication explanation

### Architecture:
- **Entry Point:** App launches → MainView (no auth wall)
- **Paywall:** Triggered when accessing premium features
- **Settings:** Always accessible via gear icon
- **Authentication:** Optional, presented as enhancement

---

## 📞 Support Information

**For Apple Review Team Questions:**
- All functionality is accessible without authentication
- Privacy Policy and Terms links work in Safari
- Account deletion permanently removes user data
- Subscriptions available immediately upon app launch

**This implementation fully addresses all 6 guideline violations identified in the rejection notice.**

---

*Document prepared for Apple App Store Review Team*  
*Mariner Studio v12.1 - August 2025*