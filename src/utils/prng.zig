//! Pseudo-random number generator for magic bitboard generation.

const assert = @import("std").debug.assert;
const Bitboard = @import("../root.zig").Bitboard;

/// Xorshift-style PRNG producing Bitboard values.
pub const Prng = struct {
    s: Bitboard,

    /// Creates a PRNG. Asserts seed is non-zero.
    pub fn init(seed: Bitboard) Prng {
        assert(seed != 0);
        return Prng{ .s = seed };
    }

    fn randBitboard(self: *Prng) Bitboard {
        self.s ^= self.s >> 12;
        self.s ^= self.s << 25;
        self.s ^= self.s >> 27;
        return self.s *% 2685821657736338717;
    }

    /// Returns a sparse random bitboard (AND of three rand outputs).
    pub fn sparseRandBitboard(self: *Prng) Bitboard {
        return self.randBitboard() & self.randBitboard() & self.randBitboard();
    }
};
