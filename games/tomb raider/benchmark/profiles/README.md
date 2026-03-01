# Shadow of the Tomb Raider benchmark profiles

Each test now uses one native preferences profile consumed by `run_sottr_benchmark.sh`.

- Native preferences snapshot format: `{TEST_NAME}.preferences.xml`
  - Full native Feral `preferences` XML copied into
    `~/.local/share/feral-interactive/Shadow of the Tomb Raider/preferences`
    before each native test.

All `.preferences.xml` files are consumed directly by `run_sottr_benchmark.sh`.
