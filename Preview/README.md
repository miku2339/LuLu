# LuLu Interface Preview

An independent, native AppKit / Objective-C design prototype for LuLu. Requires macOS 11 or later and Apple's command-line developer tools. The production app retains its macOS 10.15 deployment target.

```sh
./script/build_and_run.sh           # Traditional Chinese
./script/build_and_run.sh --english # English
./script/test_preview.sh
```

The bundle is created at `outputs/LuLu Interface Preview.app`, with identifier `org.local.lulu.interface-preview`. The Codex Run action starts this preview.

## Experience

- Overview: disconnected service status, sample rule counts and quick navigation.
- App rules: search by name, path or destination; filter by action or disabled status; inspect, add, change, disable and delete sample rules. Undo / redo use Command-Z / Shift-Command-Z.
- Connection alert: app, destination, scope, duration, expandable details and a visible sample decision. Custom duration accepts 1–1440 whole minutes.
- Settings: grouped, labelled native switches. State remains in memory while the preview is open.
- Command-1 through Command-4 navigate between pages. All form fields and switches have accessibility labels. System controls, semantic text colors and Auto Layout support light and dark appearances.

## Scope

This is a UI prototype with six fictitious/sample rule records. It does not connect to a firewall service, inspect live network activity, create firewall rules, install a system extension or change system settings. The setting switches and alert decisions modify preview state only. Alert decisions do not enforce networking or create timed rules. Quitting resets all sample state.

The production UI changes are in the existing Rules, Preferences and Alert controllers and their NIBs. The sidebar and overview in this prototype are separate design work; they are not yet integrated into the production app. Existing production features such as profiles, lists, signing inspection and VirusTotal remain in the original controllers.

## Design

Spacing uses 4 / 8 / 12 / 16 / 20 / 28 pt increments. System typography uses 28 pt page titles, 21–23 pt status / dialog titles, 13–15 pt primary labels and 11–12 pt supporting details. The navigation sidebar uses the native material; content surfaces use system background colors with 12 pt corners. SF Symbols complement visible text; allow / block remain understandable without color.

Search includes an explicit empty state. Invalid forms keep their input and show inline errors. Decision buttons have no default Return action. The prototype contains no artificial loading screen or continuous animation.

## Provenance and license

Based on [Objective-See/LuLu](https://github.com/objective-see/LuLu), commit `7d2669ed32e5b195d5863dc9695441d3301ba7b0`, marketing version 4.5.1. LuLu's original copyright and [GPL-3.0 license](../LICENSE.md) are retained. This modified interface prototype was added on 2026-09-29 and is also distributed under GPL-3.0. It is not an official Objective-See release.
