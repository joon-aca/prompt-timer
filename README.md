# Prompt Timer

Prompt Timer is a native macOS timer utility built in four layers:

1. an AppKit agent app that owns timer state
2. a local socket IPC layer
3. a `timer` CLI for keyboard-first control
4. an Alfred workflow wrapper that forwards raw input to the CLI

The app works on its own from the menu bar. The CLI is the main keyboard interface. Alfred is only a transport layer over the CLI.

Start timers by typing.

A fast Mac timer that starts from a typed prompt.

## Architecture

- `PromptTimerApp/`: agent app UI, socket server, notifications, wake handling, and menu bar behavior
- `TimerCLI/`: terminal client, CLI parser, socket client, and agent launch retry logic
- `PromptTimerTests/`: parser, store, timer manager, CLI parser, and IPC protocol tests
- `Alfred/PromptTimer.alfredworkflow-src/`: lightweight workflow source that calls the installed CLI

The agent is the only owner of timer state. The CLI sends one JSON request per socket connection and receives one JSON response. Alfred does not own state and does not duplicate timer logic.

## Runtime pieces

### Agent app

Responsibilities:

- manage active and recent timers
- persist state atomically
- reconcile overdue timers on launch and wake
- schedule in-process timer completion
- show a menu bar UI
- send native local notifications
- expose a local IPC socket

### CLI

Responsibilities:

- parse terminal input
- validate duration and control commands
- connect to the agent socket
- launch the agent if the socket is unavailable
- print concise terminal output

### Alfred

Responsibilities:

- accept keyword input
- call `timer --alfred "$1"`
- nothing else

## Terminal usage

```bash
timer 10
timer 25 deep work
timer 30s tea
timer 1h30m writing
timer 10:30am team call launch zoom
timer 10am call with Zo on zoom
timer 12m send message to jack on email
timer 23m open zoom for call with team
timer 10:30am team call fire up zoom
timer start zoom in 30min for team call
timer list
timer ls
timer status
timer cancel
timer cancel all
timer cancel abc123
timer test
timer open
timer help
```

Bare integers are treated as minutes.

Time-of-day input is supported, so `timer 10:30am team call` creates a timer that runs until the next 10:30 AM. App launch actions can be attached with trailing verbs like `launch`, `start`, `open`, or `fire up`, for example `timer 10:30am team call launch zoom`. Natural phrasing like `timer 10am call with Zo on zoom`, `timer 12m send message to jack on email`, and `timer 23m open zoom for call with team` is also supported. Action-first prompts like `timer start zoom in 30min for team call` work too.

## Build and install

### Current local setup

This repository includes a Swift package and an XcodeGen project spec. The package lets core logic and the CLI be built and tested from the command line. The AppKit app target is also defined for local compilation, but a proper `.xcodeproj` still depends on a working local Xcode install.

### Once Xcode is available

1. Point `xcode-select` at `/Applications/Xcode.app`
2. Install `xcodegen` if needed
3. Run `make install`

If you want the project generated without installing, run `make project`.

For manual Xcode work:

1. Run `xcodegen generate`
2. Open `PromptTimer.xcodeproj`
3. Set signing and bundle identifiers
4. Build `PromptTimerApp`

For a local install on your own Mac, prefer a consistent Apple Development signing identity in Xcode and copy the built app into `/Applications`. The `scripts/install.sh` helper does that for a Release build and preserves the existing signature instead of re-signing ad hoc.

## Alfred setup

The Alfred workflow source lives in `Alfred/PromptTimer.alfredworkflow-src/`.

The workflow is intentionally thin:

- keyword: `timer`
- action: run shell script
- shell script: call the installed `timer` CLI with the raw query

See `Alfred/PromptTimer.alfredworkflow-src/README.md` for setup details.

## Known limitations

- `PromptTimer.xcodeproj` is represented here by the XcodeGen spec because local Xcode tooling has been unstable during setup.
- launch at login is a placeholder hook, not a complete implementation
- the Alfred workflow source is lightweight and expects the CLI to be installed separately
