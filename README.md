# TransAtGlance

A macOS menu bar app for quick lookups.

## Run from Xcode

Open `Package.swift` in Xcode, select the **TransAtGlance** executable scheme with **My Mac** as the destination, then choose **Product → Run** (⌘R). The shared scheme signs the executable with an Apple Development certificate after each build so macOS can retain Accessibility and Screen Recording grants. The **TransAtGlance-Package** scheme builds the package but does not launch the app. Building alone will not place an icon in the menu bar.

The app uses a book symbol in the menu bar and has no Dock icon. Click the menu bar symbol to open the lookup panel, or press ⌘⌥L.

## Build an app bundle

Run `sh scripts/build-app.sh`, then open `build/TransAtGlance.app` in Finder. This bundle includes `App/Info.plist`, which marks TransAtGlance as a menu bar app.

For screen-region lookup, enable **TransAtGlance** in System Settings → Privacy & Security → Screen & System Audio Recording, then quit the app completely and reopen it. Grant Accessibility separately for selected-text lookup. Xcode Run and `build/TransAtGlance.app` are separate launch paths; use the same one after granting permission. Both build paths use an available Apple Development signing identity. If several are installed, set `CODESIGN_IDENTITY` to the SHA-1 hash of the identity you want to keep using (find it with `security find-identity -v -p codesigning`). Signing fails when no development identity is available instead of creating a build whose permission grant expires on the next rebuild. After switching from an older ad-hoc build, remove its stale entry in System Settings and grant each permission once to the signed build.

## Groq

Groq with `openai/gpt-oss-120b` is the default lookup source. Open the app's settings, choose the **Groq (GPT-OSS 120B)** tab, and save a Groq API key. The key is stored in macOS Keychain and is not written to lookup history or UserDefaults.

When Groq is selected, the lookup text, result language, and selected professional context are sent to Groq. Apple Foundation Models and Apple Translation remain available as the **Apple on-device** source.
