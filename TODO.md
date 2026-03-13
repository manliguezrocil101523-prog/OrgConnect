# Database Error Fix for Mobile App

## Issue
- App works fine in Chrome but shows database errors on sign-in/sign-up when transferred to phone.
- Errors occur during Supabase authentication and database operations.

## Root Cause Analysis
- Likely due to missing network permissions or SSL/network security configurations on Android.
- Android 9+ blocks cleartext traffic by default, and explicit permissions may be needed.

## Changes Made
- [x] Added INTERNET and ACCESS_NETWORK_STATE permissions to AndroidManifest.xml
- [x] Created network_security_config.xml to allow cleartext traffic for Supabase domain
- [x] Referenced network security config in AndroidManifest.xml

## Next Steps
- [ ] Rebuild and test the app on the phone
- [ ] Check device logs for specific error messages
- [ ] Verify Supabase project settings (CORS, authentication)
- [ ] Ensure device has internet connection and can reach Supabase servers
- [ ] If issues persist, check for VPN/firewall blocking requests

## Testing Instructions
1. Clean build: `flutter clean && flutter pub get`
2. Build APK: `flutter build apk --release`
3. Install on phone and test sign-in/sign-up
4. Monitor device logs using `adb logcat` for detailed error messages
