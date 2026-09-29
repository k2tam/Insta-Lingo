# Insta Lingo

A macOS menu bar app for quick lookups.

## Run from Xcode

Requires Xcode 26 or later and macOS 26 or later. Open `InstaLingo.xcodeproj`, select the shared **InstaLingo** scheme and **My Mac**, then choose **Product → Run** (⌘R). Xcode builds, signs, and launches the native app bundle with the debugger attached. **Product → Archive** creates an app archive.

The project contains the **InstaLingo** app, the **LookupCore** static library, and **LookupCoreTests**. Source files are organized into Xcode groups with explicit target membership. When adding a Swift file, select its corresponding target in the File inspector. Run the tests with **Product → Test** (⌘U).

Signing defaults to an installed **Apple Development** certificate. If needed, configure your team and signing identity under the app and test targets' **Signing & Capabilities** settings. Keep the same identity and bundle identifier (`com.k2tam.InstaLingo`) across rebuilds so macOS can recognize the app's permission grants.

The app uses a book symbol in the menu bar and has no Dock icon. Click the menu bar symbol to open the lookup panel, or press ⌘⌥L.

## Build an app bundle

Run `sh scripts/build-app.sh`, then open `build/Insta Lingo.app` in Finder. The script uses the same native Xcode project in Release configuration. To select a particular certificate, pass `CODE_SIGN_IDENTITY` as an environment variable. The full Xcode installation must be selected with `xcode-select`, or supplied through `DEVELOPER_DIR`.

For screen-region lookup, enable **Insta Lingo** in System Settings → Privacy & Security → Screen & System Audio Recording, then quit the app completely and reopen it. Grant Accessibility separately for selected-text lookup. Use the same app location after granting permission. After switching from an older ad-hoc build, remove its stale entry in System Settings and grant each permission once to the signed build.

## Run tests from the command line

The app, core library, and tests are all native targets in `InstaLingo.xcodeproj`. Run the test suite with:

```sh
xcodebuild -project InstaLingo.xcodeproj -scheme InstaLingo -destination 'platform=macOS' test
```

## Groq

Groq with `openai/gpt-oss-120b` is the default lookup source. Open the app's settings, choose the **Groq (GPT-OSS 120B)** tab, and save a Groq API key. The key is stored in macOS Keychain and is not written to lookup history or UserDefaults.

When Groq is selected, the lookup text, result language, and selected professional context are sent to Groq. Apple Foundation Models and Apple Translation remain available as the **Apple on-device** source.
