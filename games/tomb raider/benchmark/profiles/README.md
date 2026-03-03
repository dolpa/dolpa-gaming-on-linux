# Shadow of the Tomb Raider benchmark profiles

Each test uses one profile file consumed by `run_sottr_benchmark.sh`, chosen by launch mode.

- Native preferences snapshot format: `{TEST_NAME}.preferences.xml`
  - Full native Feral `preferences` XML copied into
    `~/.local/share/feral-interactive/Shadow of the Tomb Raider/preferences`
    before each native test.

- Proton preferences snapshot format: `{TEST_NAME}.preferences.user.reg`
  - Wine registry export copied into
    `.../steamapps/compatdata/750920/pfx/user.reg`
    before each Proton test.

Both profile formats are consumed directly by `run_sottr_benchmark.sh`.
