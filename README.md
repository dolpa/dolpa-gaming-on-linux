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

- Shadow of the Tomb Raider benchmark manual:
	- [games/tomb raider/README.md](games/tomb%20raider/README.md)

This includes usage, test/group behavior, profile requirements, result/report formats, and troubleshooting notes for Cyberpunk 2077.

## Python setup (report converter)

The script `src/convert_markdown_reports.py` uses Python + matplotlib.

1. Create a virtual environment (from repo root):
	- `python3 -m venv .venv`
2. Activate it:
	- `source .venv/bin/activate`
3. Install dependencies:
	- `python3 -m pip install -r requirements.txt`

Example usage:

- `python3 src/convert_markdown_reports.py "games/cyberpunk 2077/benchmark/results/cp2077_benchmark_report.md" --format both`

## Notes

- Keep shell scripts/config on LF line endings for Linux compatibility.

## 👨‍💻 Author

Created by **dolpa** - [Website](https://dolpa.me) | [GitHub](https://github.com/dolpa)

### Connect with the Author
- 🌐 **Blog:** [dolpa.me](https://dolpa.me)
- 📡 **RSS Feed:** [Subscribe via RSS](https://dolpa.me/rss)
- 🐙 **GitHub:** [dolpa on GitHub](https://github.com/dolpa)
- 📘 **Facebook:** [Facebook Page](https://www.facebook.com/dolpa79)
- 🐦 **Twitter (X):** [Twitter Profile](https://x.com/_dolpa)
- 💼 **LinkedIn:** [LinkedIn Profile](https://www.linkedin.com/in/paveldolinin/)
- 👽 **Reddit:** [Reddit Profile](https://www.reddit.com/user/Accomplished_Try_928/)
- 💬 **Telegram:** [Telegram Channel](https://t.me/dolpa_me)
- ▶️ **YouTube:** [YouTube Channel](https://www.youtube.com/c/PavelDolinin)

---

**Enjoy Your Gaming on Linux!** 🎉

*Remember: Don't panic, and always have your bash utilities with you!* 🛠️
