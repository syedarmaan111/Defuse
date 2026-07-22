# Milestone 3: Internet Gate and Google Play Games Sign-In

> Deferred during base-game development. The implementation and its tests are
> retained, but `defuse/online_gate/enabled` is currently `false`, so Android
> and desktop builds can launch without internet. Re-enable and complete
> device-level acceptance testing after the base game is complete.

## Implemented

- Added `NetworkManager` as the single owner of connection state and new-run eligibility.
- Android builds query the active network through Godot's built-in `AndroidRuntime` and `JavaClassWrapper` bridge.
- Production eligibility requires both `NET_CAPABILITY_INTERNET` and `NET_CAPABILITY_VALIDATED`; platform-bridge failures fail closed so offline launch cannot bypass the gate.
- Added a one-second Android capability refresh, diagnostic status, and the required transport, availability, live-run loss, and live-run restore signals.
- Added `CloudSaveManager` with Google Play Games automatic-authentication checks and manual sign-in retry support. Sign-in is non-blocking until a real Play Console game ID and Gradle export are configured.
- Integrated the Godot Foundation-hosted `GodotPlayGameServices` v3.3.0 release and its upstream license.
- Added responsive Network Required and Play Games Sign-In screens using the Milestone 2 visual language and shared buttons.
- Added a non-blocking connection-status overlay. A live run remains visible after internet loss; Home, replay, and new-run entry remain gated.
- Added Android export permissions for internet and network-state access.
- Kept an explicit `defuse/development/bypass_online_gate` setting for deliberate desktop testing, with the bypass disabled by default and unavailable on Android.

## Automated Validation

- Godot 4.6.2 headless editor import completes with exit code 0 and no parse errors.
- The configured main scene starts headlessly with exit code 0 and no runtime errors.
- Android debug export completes and the generated APK manifest contains both `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE`.
- `Tests/Milestone3Smoke.tscn` passes production-like state transitions:
  - disconnected launch -> Network Required;
  - Wi-Fi without validated internet -> Network Required;
  - a platform bridge failure -> Network Required;
  - validated cellular data with non-blocking Play Games -> Home;
  - required Play Games authentication -> Sign-In;
  - Wi-Fi or cellular data plus authentication -> Home;
  - an eligible new run -> Gameplay;
  - internet loss during Gameplay emits the live-run warning without leaving Gameplay.
- `git diff --check` passes.

## Android Configuration Required Before Enabling Mandatory Play Games Sign-In

The debug APK can use Godot's prebuilt Android template. Mandatory Google Play Games sign-in remains disabled because the project does not contain a Gradle build template, Play Console game-services project ID, or production signing credentials. Those external values must not be invented or committed.

Before the Android acceptance test:

1. Install the Godot 4.6.2 Gradle build template and configure the Android SDK/JDK.
2. Enable Gradle Build in the Android export preset.
3. Set the preset's `godot_play_game_services/game_id` to the real Play Games Services project ID.
4. Configure the package name and signing certificate to match the linked Play Console credential.
5. Publish or add the tester account in Play Console, install the signed build on an Android test device, and then set `defuse/play_games/require_sign_in` to `true`.

## Manual Android Acceptance Checklist

1. Launch on working Wi-Fi and confirm Home becomes available.
2. Launch on cellular data only and confirm Home becomes available.
3. Disconnect both Wi-Fi and cellular data and confirm Network Required remains visible.
4. Confirm unavailable or unconfigured Play Games authentication does not block Home while `require_sign_in` is `false`.
5. Start a run, disable both Wi-Fi and cellular data, and confirm the run stays visible with the connection warning.
6. Finish the run while disconnected and confirm Play Again/new-run entry routes to Network Required.
7. Restore Wi-Fi or cellular data during a live run and confirm the restored notification appears without restarting the run.
