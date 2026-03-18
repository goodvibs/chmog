//! Pseudo-random number generator for magic bitboard generation.

const Bitboard = @import("../mod.zig").Bitboard;

/// Returned when Prng.init receives seed 0.
pub const PrngError = error{ ZeroSeed };

/// Xorshift-style PRNG producing Bitboard values.
pub const Prng = struct {
    s: Bitboard,

    /// Creates a PRNG. Returns ZeroSeed if seed is 0.
    pub fn init(seed: Bitboard) PrngError!Prng {
        if (seed == 0) return PrngError.ZeroSeed;
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
