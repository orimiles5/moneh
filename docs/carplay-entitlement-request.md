# CarPlay entitlement request (Driving Task)

Submitted at <https://developer.apple.com/contact/carplay/> by the account holder, once the Apple Developer Program membership is active. Apple decides; approval is not guaranteed. Until then the CarPlay scene is compiled out (`CARPLAY_ENABLED = NO` in `ios/Config/App.xcconfig`) and the fare reaches the car through the Live Activity on the CarPlay Dashboard, which needs no entitlement.

## Requested entitlement

`com.apple.developer.carplay-driving-task` (Driving Task category).

## Answers for the form

**App name:** Moneh (מונה)

**App description**
Moneh is a taxi meter assistant for taxi drivers in Israel. While the driver is on a hired trip, it calculates the running fare from the official tariffs published by the Israeli Ministry of Transport (starting fare, time and distance charges, time-of-day tariff bands and extras) using the phone's location.

**Why the app belongs in CarPlay (Driving Task)**
The running fare is information the driver needs while driving: it changes with distance, time and the time-of-day tariff, and the passenger must be able to see it throughout the trip. Today drivers have to glance at a phone mounted on the dashboard. On the car's screen, the fare is in the driver's normal line of sight and visible to the passenger, while the phone stays free for navigation and dispatch apps.

**What the CarPlay interface does**
One information template, read-only while driving:
- the running fare, in large type;
- the current tariff band (A, B or C);
- trip time and distance;
- at most two actions, Pause and Stop, so the driver can end a trip without touching the phone. Starting a trip, extras and settings stay on the phone and are not available while driving.

No text entry, no lists to scroll, no media, no maps. The layout follows the Driving Task template limits and the CarPlay App Programming Guide.

**Driver distraction**
The screen updates no more often than the fare changes, has no animation beyond the system's, and needs no interaction during a trip. All actions are single large buttons.

**Data and privacy**
Location is used only while a trip is running, to measure distance, and stays on the device. There is no account, no backend and no analytics.

**Regulatory note**
The app is not a certified taxi meter and says so in the app. It does not replace the meter installed in the taxi.

**Markets:** Israel first; other countries later through new tariff files.

## After approval

1. Add the entitlement to the App ID in the developer portal and regenerate the provisioning profile.
2. Set `CARPLAY_ENABLED = YES` in `ios/Config/App.xcconfig`, which compiles in the CarPlay scene and signs with `Moneh-CarPlay.entitlements`.
3. Test in the CarPlay Simulator (Xcode → Open Developer Tool → CarPlay Simulator, or Simulator → I/O → External Displays → CarPlay).
