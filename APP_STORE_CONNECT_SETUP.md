# App Store Connect Setup - Premium Tier 2

## Overview
This document contains instructions for setting up the new Premium Tier 2 subscription products in App Store Connect for the "Rev Cat Template" offering.

## RevenueCat Configuration (Already Complete)

- **Offering Name:** Rev Cat Template
- **Lookup Key:** `rev_cat_template`
- **Offering ID:** `ofrng51007efdeb`

### Products Created in RevenueCat
1. Premium Tier 2 Monthly - ID: `prod0454a50879`
2. Premium Tier 2 Annual - ID: `prod151b25a745`

### Packages Created
- `$rc_monthly` - Premium Tier 2 Monthly (position 1)
- `$rc_annual` - Premium Tier 2 Annual (position 0)

### Entitlements
Both products are linked to the "Pro" entitlement (`entlc0bc58606d`)

---

## Action Required: Create Products in App Store Connect

### Step 1: Navigate to Subscriptions
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app: **Mariner Studio**
3. Go to **Subscriptions**
4. Select subscription group: **"Pro Subscription Plans"** (ID: 29165EBC)

### Step 2: Create Monthly Subscription

Click **"Add Subscription"** and enter the following details:

**Basic Information:**
- **Product ID:** `com.ospreyapplications.MarinerStudio.premiumtier2_monthly`
- **Reference Name:** Premium Tier 2 Monthly
- **Subscription Duration:** 1 Month

**Pricing:**
- **Price:** $4.99 (or $5.00 depending on your preference)
- **Territory:** All territories (or select specific ones)

**Localization (English - US):**
- **Subscription Display Name:** Premium Tier 2 Monthly
- **Description:** Add your own description here

### Step 3: Create Annual Subscription

Click **"Add Subscription"** and enter the following details:

**Basic Information:**
- **Product ID:** `com.ospreyapplications.MarinerStudio.premiumtier2_annual`
- **Reference Name:** Premium Tier 2 Annual
- **Subscription Duration:** 1 Year

**Pricing:**
- **Price:** $35.99 (or $36.00 depending on your preference)
- **Territory:** All territories (or select specific ones)

**Localization (English - US):**
- **Subscription Display Name:** Premium Tier 2 Annual
- **Description:** Add your own description here

### Step 4: Submit for Review
Once both subscriptions are created, submit them for Apple's review.

---

## After App Store Connect Setup

### Configure Paywall Template in RevenueCat Dashboard

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Navigate to **Paywalls**
3. Create a new paywall for the "Rev Cat Template" offering
4. Select your desired paywall template
5. Customize as needed
6. Publish the paywall

### Using the New Offering in Your App

To display this offering in your app:

```swift
// Fetch the specific offering
if let offering = try await Purchases.shared.offerings().offering(identifier: "rev_cat_template") {
    // Display PaywallView with this offering
    PaywallView(offering: offering)
}
```

Or to make it the default offering, go to RevenueCat Dashboard → Offerings → "Rev Cat Template" → Set as Current

---

## Product ID Reference

Use these exact Product IDs when creating subscriptions in App Store Connect:

```
Monthly: com.ospreyapplications.MarinerStudio.premiumtier2_monthly
Annual:  com.ospreyapplications.MarinerStudio.premiumtier2_annual
```

## Subscription Group

Both products should be added to:
- **Subscription Group Name:** Pro Subscription Plans
- **Subscription Group ID:** 29165EBC

---

## Troubleshooting

If products don't appear in RevenueCat after creating them in App Store Connect:
1. Wait 15-30 minutes for Apple to sync
2. Check that Product IDs match exactly (case-sensitive)
3. Verify products are in "Ready to Submit" or "Approved" state
4. Try refreshing the RevenueCat dashboard

## Enabling Automatic Product Creation (Optional)

To allow RevenueCat (and the MCP server) to automatically create products in App Store Connect for you, you need to configure App Store Connect API credentials:

### Required Information

1. **App Store Connect API Key** (.p8 file)
2. **Issuer ID**
3. **Vendor Number**

### Setup Steps

**Step 1: Create API Key in App Store Connect**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Integrations** → **App Store Connect API**
3. Click **Generate API Key** or **+ (plus icon)**
4. Enter a name (e.g., "RevenueCat API")
5. Select access level: **App Manager** (minimum required)
6. Click **Generate**
7. **Download the .p8 file immediately** (can only be downloaded once!)
8. Note the **Key ID** and **Issuer ID** displayed on the page

**Step 2: Get Your Vendor Number**
1. In App Store Connect, go to **Payments and Financial Reports**
2. Your **Vendor Number** is displayed in the top left corner

**Step 3: Configure in RevenueCat Dashboard**
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Navigate to your **Mariner Studio** app settings
3. Select the **App Store Connect API** tab
4. Upload the **.p8 file** you downloaded
5. Enter your **Issuer ID**
6. Enter your **Vendor Number**
7. Click **Save**

### Benefits

Once configured, RevenueCat (and I via the MCP server) can:
- Automatically create products in App Store Connect
- Push pricing changes
- Sync subscription groups
- Import product metadata

This eliminates the manual step of creating products in App Store Connect.

## Notes

- Products are already configured in RevenueCat and linked to the "Pro" entitlement
- Once App Store Connect products are created, they will automatically sync with RevenueCat
- The paywall template selection must be done through the RevenueCat Dashboard UI
