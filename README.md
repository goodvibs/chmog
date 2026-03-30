# chmog

A chess move generator written in Zig. Intended for use in high performance chess software, like chess engines.

Priorities, in order:

- Correct
- Fast
- Lightweight
- Simple

Promised features:

- Bitboard-based state representation
- Direct legal move generation (no pseudolegal step)
- Forward-backward move application
- Magic bitboards for sliding piece attacks
- Precomputed attacks for knights and kings
- Zobrist hashing for position repetition detection
- PGN parsing and generation with infinite variation support
- FEN parsing and generation
- UCI move format support
- Comprehensive perft correctness tests
- Comprehensive perft performance tests

Very similar to the [bunnies](https://github.com/goodvibs/bunnies) project. Still a work in progress.

## Profiling perft tests (macOS)

The `profile` build step runs Apple’s **Instruments** time profiler (`xcrun xctrace record --template 'Time Profiler'`) against the same perft test binary as `perft-test`, so you never hardcode paths under `.zig-cache`.

Requirements: macOS with Xcode / command-line tools so `xcrun xctrace` is available.

Typical usage (release-like optimization):

```sh
zig build profile -Doptimize=ReleaseFast
```

This writes a `.trace` bundle. By default the path is **`perft-profile.trace` under the install prefix** (same place as `zig build install` / `zig build docs`: typically `zig-out/perft-profile.trace` when using the default prefix). Open it with **Instruments** or `open zig-out/perft-profile.trace` (adjust if you use `-p`).

Options:

- `-Dprofile-trace=path` — output path for the trace (default: `perft-profile.trace` under the install prefix).
- `-Dprofile-time-limit=90s` — passed to `xctrace record --time-limit`. Set this **longer** than the perft run duration; if the limit fires before tests finish, `xctrace` may exit with a non-zero code even after saving a trace.

On non-macOS hosts, `zig build profile` fails with a short message so CI does not silently skip profiling.
