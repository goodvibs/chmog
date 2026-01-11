const Bitboard = @import("./mod.zig").Bitboard;
const Square = @import("./mod.zig").Square;

pub const FILE_A: Bitboard = 0x8080808080808080;
pub const FILE_B = FILE_A >> 1;
pub const FILE_C = FILE_B >> 1;
pub const FILE_D = FILE_C >> 1;
pub const FILE_E = FILE_D >> 1;
pub const FILE_F = FILE_E >> 1;
pub const FILE_G = FILE_F >> 1;
pub const FILE_H = FILE_G >> 1;

pub const RANK_8: Bitboard = 0xFF_00_00_00_00_00_00_00;
pub const RANK_7 = RANK_8 >> 8;
pub const RANK_6 = RANK_7 >> 8;
pub const RANK_5 = RANK_6 >> 8;
pub const RANK_4 = RANK_5 >> 8;
pub const RANK_3 = RANK_4 >> 8;
pub const RANK_2 = RANK_3 >> 8;
pub const RANK_1 = RANK_2 >> 8;

pub const KING_SIDE: Bitboard = FILE_E | FILE_F | FILE_G | FILE_H;
pub const QUEEN_SIDE: Bitboard = FILE_A | FILE_B | FILE_C | FILE_D;
pub const OUTER_EDGES: Bitboard = FILE_A | FILE_H | RANK_1 | RANK_8;

pub const STARTING_WK_WR_GAP_SHORT: Bitboard = RANK_1 & (FILE_F | FILE_G);
pub const STARTING_WK_WR_GAP_LONG: Bitboard = RANK_1 & (FILE_B | FILE_C | FILE_D);
pub const STARTING_BK_BR_GAP_SHORT: Bitboard = RANK_8 & (FILE_F | FILE_G);
pub const STARTING_BK_BR_GAP_LONG: Bitboard = RANK_8 & (FILE_B | FILE_C | FILE_D);

pub const FILES: [8]Bitboard = .{
    FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H,
};

pub const RANKS: [8]Bitboard = .{
    RANK_8, RANK_7, RANK_6, RANK_5, RANK_4, RANK_3, RANK_2, RANK_1,
};

pub const STARTING_WP = RANK_2;
pub const STARTING_WN = Square.B1.mask() | Square.G1.mask();
pub const STARTING_WB = Square.C1.mask() | Square.F1.mask();
pub const STARTING_WR = Square.A1.mask() | Square.H1.mask();
pub const STARTING_WQ = Square.D1.mask();
pub const STARTING_WK = Square.E1.mask();

pub const STARTING_BP = RANK_7;
pub const STARTING_BN = Square.B8.mask() | Square.G8.mask();
pub const STARTING_BB = Square.C8.mask() | Square.F8.mask();
pub const STARTING_BR = Square.A8.mask() | Square.H8.mask();
pub const STARTING_BQ = Square.D8.mask();
pub const STARTING_BK = Square.E8.mask();

pub const STARTING_PAWNS = STARTING_WP | STARTING_BP;
pub const STARTING_KNIGHTS = STARTING_WN | STARTING_BN;
pub const STARTING_BISHOPS = STARTING_WB | STARTING_BB;
pub const STARTING_ROOKS = STARTING_WR | STARTING_BR;
pub const STARTING_QUEENS = STARTING_WQ | STARTING_BQ;
pub const STARTING_KINGS = STARTING_WK | STARTING_BK;

pub const STARTING_WHITE: Bitboard = STARTING_WP | STARTING_WN | STARTING_WB | STARTING_WR | STARTING_WQ | STARTING_WK;
pub const STARTING_BLACK: Bitboard = STARTING_BP | STARTING_BN | STARTING_BB | STARTING_BR | STARTING_BQ | STARTING_BK;
pub const STARTING_ALL: Bitboard = STARTING_WHITE | STARTING_BLACK;
