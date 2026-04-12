# REFS-PUBLIC.md - Public References

> Record external public repositories, datasets, documentation, APIs, or other
> public resources that this repository utilizes or depends on.
> This file is tracked and intentionally kept free of private or local-only details.

## Public Repositories

- https://github.com/tmux-plugins/tpm - tmux plugin manager installed by the setup flow
- https://github.com/tmux-plugins/tmux-resurrect - session save and restore plugin
- https://github.com/tmux-plugins/tmux-continuum - automatic tmux session persistence plugin

## Public Datasets and APIs

- No standing public data APIs are required; the repo configures local tmux sessions and shell aliases.

## Documentation and Specifications

- https://github.com/tmux/tmux/wiki - tmux usage and configuration reference
- https://plantuml.com/ - PlantUML render reference used by setup.sh
- https://github.com/jgraph/drawio - draw.io desktop/AppImage source used by setup.sh

## Notes

- The repo scans local git checkouts but does not depend on any public dataset or remote control-plane API.
