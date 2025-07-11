pub const DecisiveResultReason = enum {
    Checkmate,
    TimeUp,
    Resignation,
    Unknown,
};

pub const DrawResultReason = enum {
    Stalemate,
    InsufficientMaterial,
    ThreefoldRepetition,
    FiftyMoveRule,
    Agreement,
    Unknown,
};

pub const GameResult = union(enum) {
    Win: DecisiveResultReason,
    Draw: DrawResultReason,
    Loss: DecisiveResultReason,
};
