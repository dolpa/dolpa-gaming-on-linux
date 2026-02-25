# dolpa-gaming-on-linux

Automation and documentation for game benchmarking workflows on Linux.

## Repository layout

- `games/`
	- Game-specific tooling and manuals.
- `etc/`
	- Supporting configuration templates.
- `results/`
	- Repository-level generated artifacts (if any).
- `dolpa-bash-utils/` (git submodule)
	- Shared shell utility modules used by scripts.

## Game manuals

- Cyberpunk 2077 benchmark manual:
	- [games/cyberpunk 2077/README.md](games/cyberpunk%202077/README.md)

This includes usage, test/group behavior, profile requirements, result/report formats, and troubleshooting notes for Cyberpunk 2077.

## Notes

- Keep shell scripts/config on LF line endings for Linux compatibility.