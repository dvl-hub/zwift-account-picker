# Feature and validation status

Version: 0.1.0. Updated: 2026-11-15.

The user confirmed remembered account switching in the original integrated
launcher. This standalone extraction uses the same process-scoped WebView2
mechanism, with independent paths and startup code.

Implemented: account labels/addition, separate browser sessions, launcher-path
selection/change, scoped clean restart, verified process startup/retry, CMD
entry, optional EXE, local logs and hosts-override detection.

Automated validation: account persistence, duplicate/path rejection, parent
environment restoration, distinct child-process profile inheritance, syntax,
and hosts guard. Layout preview checked. No real game process needs to be
stopped to run the tests. A first-use check on another PC is still recommended.

Remaining: rename/remove accounts in UI, per-account shortcuts, accessibility
and high-DPI coverage, signed release binaries, additional Windows/launcher
version reports. Zwift can require reauthentication when a session expires.
