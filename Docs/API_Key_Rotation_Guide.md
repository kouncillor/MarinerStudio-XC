# 🔄 **API Key Rotation Guide**
## Mariner Studio XC - Security Maintenance

---

## 📋 **Overview**

This guide explains how to safely rotate API keys in Mariner Studio XC after implementing the secure configuration system. Use this when keys have been exposed or for regular security maintenance.

---

## 🔑 **RevenueCat API Key Rotation**

### **When to Rotate:**
- **Regular maintenance**: Every 6-12 months
- **Security breach**: Immediately if exposed
- **Team changes**: When developers leave

### **Step-by-Step Process:**

1. **Generate New Key in RevenueCat Dashboard:**
   - Log into [RevenueCat Dashboard](https://app.revenuecat.com)
   - Navigate to **Settings** → **API Keys**
   - Click **"+ New"** or **"Generate New Key"**
   - Select:
     - **Key Type**: Public SDK Key
     - **Environment**: Production (same as current)
     - **API Version**: V1
   - **Copy the new key** (starts with `appl_`)

2. **Update Info.plist Configuration:**
   - Open `/Mariner-Studio-Info.plist`
   - Find the `REVENUECAT_API_KEY` entry
   - Replace the old key with your new key:
   ```xml
   <key>REVENUECAT_API_KEY</key>
   <string>appl_YOUR_NEW_KEY_HERE</string>
   ```

3. **Test the New Configuration:**
   - Build and run in Xcode (Debug mode)
   - Verify RevenueCat initialization in logs:
     ```
     🎫 RevenueCat Configuration:
        Environment: DEBUG
        Log Level: debug
        API Key: appl_YOUR_NEW_KEY...
     ```
   - Test subscription flows
   - Verify authentication works

4. **Deploy and Cleanup:**
   - Deploy to TestFlight first
   - Test with TestFlight build
   - Deploy to App Store
   - **Delete old key** from RevenueCat dashboard once confirmed working

### **Important Notes:**
- ✅ **No code changes needed** - just swap the key value
- ✅ **Zero downtime** - new key works immediately  
- ✅ **Same functionality** - all products/entitlements remain the same
- ⚠️ **Test thoroughly** before deleting old key

---

## 🔗 **Supabase Keys Rotation**

### **When to Rotate:**
- **Regular maintenance**: Every 3-6 months
- **Security breach**: Immediately if exposed
- **Suspected compromise**: Better safe than sorry

### **⚠️ Critical Warning:**
Supabase key rotation causes **immediate downtime** - old keys stop working instantly when new ones are generated.

### **Step-by-Step Process:**

1. **Plan the Rotation:**
   - **Schedule maintenance window** (low usage time)
   - **Notify users** if necessary
   - **Have rollback plan** ready
   - **Backup current configuration**

2. **Generate New Keys in Supabase Dashboard:**
   - Log into [Supabase Dashboard](https://supabase.com/dashboard)
   - Go to your project
   - Navigate to **Settings** → **API**
   - **Regenerate** the anon/public key
   - Copy both:
     - **Project URL**: `https://YOUR_PROJECT.supabase.co`
     - **Anon Key**: `eyJhbGciOiJIUzI1NiIs...`

3. **Update Info.plist Configuration:**
   - Open `/Mariner-Studio-Info.plist`
   - Update both entries:
   ```xml
   <key>SUPABASE_URL</key>
   <string>https://YOUR_NEW_PROJECT_URL.supabase.co</string>
   
   <key>SUPABASE_ANON_KEY</key>
   <string>YOUR_NEW_JWT_TOKEN_HERE</string>
   ```

4. **Test Immediately:**
   - Build and run in Xcode
   - Test user authentication
   - Verify database connections
   - Check all Supabase-dependent features

5. **Deploy Quickly:**
   - **Old keys are now invalid**
   - Deploy to production ASAP
   - Monitor error rates closely

### **Rollback Plan:**
If new keys don't work:
1. **Revert Info.plist** to old values
2. **Regenerate keys again** in Supabase (this restores old keys)
3. **Investigate the issue**
4. **Try rotation again**

---

## 📋 **Key Rotation Checklist**

### **Pre-Rotation Preparation:**
- [ ] **Backup current Info.plist file**
- [ ] **Document current key values** (securely)
- [ ] **Plan deployment strategy**
- [ ] **Schedule maintenance window** (for Supabase)
- [ ] **Notify team members**
- [ ] **Test in development environment first**

### **During Rotation:**
- [ ] **Generate new keys** in respective dashboards
- [ ] **Update Info.plist** with new values
- [ ] **Build and test locally**
- [ ] **Verify logs show new keys loading**
- [ ] **Test all authentication flows**
- [ ] **Deploy to TestFlight** for verification
- [ ] **Monitor error rates and logs**

### **Post-Rotation Verification:**
- [ ] **Verify user authentication works**
- [ ] **Check RevenueCat subscription flows**
- [ ] **Test Supabase database operations**
- [ ] **Monitor app crash rates**
- [ ] **Check customer support tickets**
- [ ] **Delete old keys** from dashboards (after 24-48 hours)
- [ ] **Document the rotation** with date and reason

---

## 🎯 **Best Practices**

### **Regular Maintenance Schedule:**
- **RevenueCat API Key**: Rotate every 6-12 months
- **Supabase Keys**: Rotate every 3-6 months
- **Emergency Rotation**: Immediately upon suspected compromise

### **Security Improvements for Future:**
1. **Environment-Specific Keys**: Use different keys for Debug/TestFlight/Production
2. **CI/CD Integration**: Automate key injection during builds
3. **Key Management Service**: Consider AWS Secrets Manager or similar
4. **Monitoring**: Set up alerts for authentication failures
5. **Documentation**: Keep this guide updated with any changes

### **Team Coordination:**
- **Key rotation should be done by senior developers**
- **Always have a second person review changes**
- **Test on multiple devices/accounts**
- **Have customer support ready for issues**

---

## 🚨 **Emergency Key Rotation**

If you discover keys have been compromised or exposed:

### **Immediate Actions (Within 1 Hour):**
1. **🔥 Rotate Supabase keys immediately** (critical - database access)
2. **🔥 Rotate RevenueCat key immediately** (medium risk - subscription fraud)
3. **📱 Prepare emergency app update**
4. **📊 Monitor for suspicious activity**

### **Short-term Actions (Within 24 Hours):**
1. **📈 Monitor authentication error rates**
2. **👥 Check user accounts for suspicious activity**
3. **💰 Review RevenueCat for fraudulent subscriptions**
4. **📱 Force app update if keys are in production builds**

### **Follow-up Actions (Within 1 Week):**
1. **🔍 Investigate how keys were exposed**
2. **📝 Update security practices**
3. **👨‍💻 Educate team on secure practices**
4. **📋 Review and update this guide**

---

## 📞 **Emergency Contacts**

- **RevenueCat Support**: [RevenueCat Help Center](https://www.revenuecat.com/help/)
- **Supabase Support**: [Supabase Support](https://supabase.com/support)
- **Apple Developer Support**: [Apple Developer Support](https://developer.apple.com/support/)

---

## 📝 **Rotation Log**

Keep track of key rotations for security auditing:

| Date | Key Type | Reason | Performed By | Notes |
|------|----------|--------|--------------|-------|
| 2025-07-29 | All Keys | Initial security implementation | Claude Code Assistant | Moved from hardcoded to secure config |
| | | | | |
| | | | | |

---

## 🔧 **Technical Details**

### **Current Configuration Location:**
- **File**: `/Mariner-Studio-Info.plist`
- **Keys**: `REVENUECAT_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Loading**: `AppConfiguration.swift` handles secure loading

### **Validation:**
The app automatically validates configuration on startup. Check logs for:
```
✅ Configuration validation: PASSED
```

If you see validation failures, check that all required keys are present in Info.plist.

---

**Last Updated**: July 29, 2025  
**Version**: 1.0  
**Next Review**: January 29, 2026

---

*Keep this guide updated as your security practices evolve. Regular key rotation is essential for maintaining app security.*