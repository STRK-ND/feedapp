# Curated Feeds R8 rules (release builds are minified + shrunk).
# Flutter handles its own shrink rules; these cover reflection surfaces
# the default rules may miss.

# Firebase Messaging: background-message entrypoint is reflectively
# instantiated from AndroidManifest metadata.
-keep class com.curatedfeeds.** { *; }

# Google Play Billing / in_app_purchase AIDL surface.
-keep class com.android.vending.billing.** { *; }

# flutter_local_notifications uses reflection for scheduled-notification
# receivers on some OEM builds.
-keep class com.dexterous.** { *; }
