# Rise native benchmark profiles

Each file in this directory maps one benchmark test name to launch arguments used by `run_rottr_benchmark.sh`.

- Filename format: `{TEST_NAME}.profile.conf.sh`
- Variables consumed by script:
  - `profile_mode`
  - `profile_resolution`
  - `profile_quality`
  - `profile_ray_tracing`
  - `profile_frame_generation`
  - `profile_launch_args` (bash array)

This directory is the preferred format for Rise of the Tomb Raider benchmark profiles.
