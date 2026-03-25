# Prompt Timer Alfred Workflow

This workflow is intentionally thin. It does not own timer state and it does not duplicate parsing logic.

## Setup

1. Install the Prompt Timer app and bundled `timer` CLI
2. In Alfred, create or import a workflow with keyword `timer`
3. Point the Run Script action at `scripts/run.sh`
4. If the CLI is not in `/Applications/Prompt Timer.app/Contents/MacOS/timer`, edit the `TIMER_BIN` path in the script

## Behavior

The workflow passes the raw Alfred query directly to the CLI:

```bash
timer --alfred "$1"
```

Examples:

- `timer 10`
- `timer 25 deep work`
- `timer list`
- `timer cancel all`

That is all the workflow should do.
