const Bitboard = @import("mod.zig").Bitboard;

pub const Prng = struct {
    s: Bitboard,

    pub fn init(seed: Bitboard) !Prng {
        if (seed == 0) return error.ZeroSeed;
        return Prng{ .s = seed };
    }

    fn randBitboard(self: *Prng) Bitboard {
        self.s ^= self.s >> 12;
        self.s ^= self.s << 25;
        self.s ^= self.s >> 27;
        return self.s *% 2685821657736338717; // Use *% for wrapping multiply
    }

    pub fn rand(self: *Prng, comptime T: type) T {
        return @truncate(self.randBitboard());
    }

    // Special generator for magic number generation
    // Output values only have 1/8th of their bits set on average
    pub fn sparseRand(self: *Prng, comptime T: type) T {
        return @truncate(self.randBitboard() & self.randBitboard() & self.randBitboard());
    }
};
