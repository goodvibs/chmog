const Bitboard = @import("../mod.zig").Bitboard;

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
        return self.s *% 2685821657736338717;
    }

    pub fn sparseRandBitboard(self: *Prng) Bitboard {
        return self.randBitboard() & self.randBitboard() & self.randBitboard();
    }
};
