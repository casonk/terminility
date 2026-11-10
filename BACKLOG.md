# BACKLOG.md

Portfolio backlog for this repository. Pending items are candidates for execution —
manually or via crew-chief. Entries sourced from archility audit are tagged
`[archility:YYYY-MM-DD]`; manual entries use `[manual:YYYY-MM-DD]`.

The archility twice-weekly job populates this file automatically via `archility audit --write-backlog`.
To execute a backlog item with crew-chief: `crew-chief agent "Work on item: <item text>"`.
Mark items `[x]` when complete and move them to Done.

## Pending

- [ ] [manual:2026-11-10] **Regenerate the architecture diagram PNGs** — the
  `docs/diagrams/repo-architecture.puml.png` and `.drawio.png` renders still show
  the old hardcoded workspace path; the sources and SVGs now say `$GIT_BASE`.
  Run `./setup.sh` on a host with PlantUML and draw.io installed (neither is
  present on the main workstation), then commit the refreshed images. Also check
  `docs/contributor-architecture-blueprint.md` and the `sessions.sh` default
  `GIT_BASE` for the same path if a portable default is wanted.

- [ ] [manual:2026-10-15] **Ask GitHub Support to purge pre-rewrite commits** — this
  repository's published history was rewritten (most recently on 2026-10-15,
  to remove per-commit AI attribution trailers). GitHub keeps serving the old
  commits to anyone with a hash, and through the read-only `refs/pull/*` refs
  of earlier pull requests, until Support garbage-collects them. The request
  is filed once for the whole portfolio from traction-control's backlog; mark
  this done when an old hash returns 404 here. Never push an old clone's
  history back.

## In Progress

## Done
