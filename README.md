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
