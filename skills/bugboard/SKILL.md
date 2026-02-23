# BugBoard — Ambient Bug Tracking

BugBoard adds bug tracking to AI coding sessions. Mention a bug mid-flow, and
a self-contained agent investigates, plans, and files it — zero disruption.

## Commands

### `/bugboard:new <description>`
Create a new bug. The agent automatically:
1. Creates a structured entry in `.bugboard/bugs/BUG-XXXX/`
2. Investigates root cause via code analysis
3. Writes a TDD implementation plan
4. Updates the board registry

**Examples:**
```
/bugboard:new The login form doesn't validate email format
/bugboard:new P1 critical: database connection pool exhausted under load
/bugboard:new low priority: the footer alignment is off on mobile
```

### `/bugboard:status`
Show the current state of all tracked bugs as a summary table.

### `/bugboard:list [filter]`
List bugs with optional filter:
```
/bugboard:list ready        # bugs ready for pickup
/bugboard:list investigating # bugs still being investigated
/bugboard:list P1           # critical bugs only
```

### `/bugboard:close <id>`
Archive a resolved bug:
```
/bugboard:close BUG-0001
```

## Priority Keywords

Default priority is P3. Override with keywords in your description:

| Priority | Keywords |
|----------|----------|
| **P1** | critical, blocker, urgent, "production down" |
| **P2** | high, important, "affecting users" |
| **P3** | medium, normal, (default) |
| **P4** | low, minor, cosmetic, "nice to have" |

You can also use explicit priority: `P1`, `P2`, `P3`, `P4`.

## Directory Structure

```
.bugboard/
├── board.md              # Registry — all bugs at a glance
├── config.json           # Settings (auto-investigate, priority rules)
├── bugs/
│   └── BUG-0001/
│       ├── report.md         # Your description + captured context
│       ├── investigation.md  # Root cause analysis
│       ├── plan.md           # TDD implementation plan
│       └── metadata.json     # Machine-readable status
└── archive/              # Closed bugs moved here
```

## Reading Outputs

### `investigation.md`
Contains the code path traced, root cause analysis, affected components,
blast radius, and constraints for fixing. Use this to understand the bug
before picking it up.

### `plan.md`
Contains a TDD implementation plan: tests first, implementation second,
validation third. Each task has a specific file, location, and change
description. Execute tasks in order.

### `metadata.json`
Machine-readable status. Fields:
- `status`: new, investigating, ready, closed
- `priority`: P1-P4
- `investigation.status`: pending, in_progress, complete
- `plan.status`: pending, in_progress, complete

## Initialisation

BugBoard auto-initialises `.bugboard/` on first use. To manually initialise:
```bash
bash scripts/bugboard-init.sh
```

## Configuration

Edit `.bugboard/config.json`:
```json
{
  "auto_investigate": true,
  "auto_plan": true,
  "default_priority": "P3",
  "id_prefix": "BUG",
  "id_digits": 4
}
```

## Manual Editing

`board.md` is a plain markdown table — you can edit it by hand if needed.
The agent reads it to determine the next bug ID and current state. Keep the
table format intact (pipe-separated columns).
