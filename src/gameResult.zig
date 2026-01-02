pub const GameResult = enum(u4) {
    LossByCheckmate = 0,
    LossByResignation = 1,
    LossByTimeUp = 2,
    LossByAbandonment = 3,
    LossByUnknownCause = 4,
    WinByResignation = 5,
    WinByUnknownCause = 6,
    DrawByStalemate = 7,
    DrawByInsufficientMaterial = 8,
    DrawByTimeUpVsInsufficientMaterial = 9,
    DrawByThreefoldRepetition = 10,
    DrawByFiftyMoveRule = 11,
    DrawByAgreement = 12,
    DrawByUnknownCause = 13,

    pub fn int(self: GameResult) u4 {
        return @as(u4, self);
    }

    pub fn isLoss(self: GameResult) bool {
        return self.int() <= GameResult.LossByUnknownCause;
    }

    pub fn isWin(self: GameResult) bool {
        return !self.isLoss() and self.int() <= GameResult.WinByUnknownCause;
    }

    pub fn isDraw(self: GameResult) bool {
        return self.int() >= GameResult.DrawByStalemate;
    }
};
