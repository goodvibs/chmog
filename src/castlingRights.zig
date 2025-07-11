pub const CastlingRights = packed struct {
    white_kingside: bool,
    white_queenside: bool,
    black_kingside: bool,
    black_queenside: bool,

    pub fn none() CastlingRights {
        return CastlingRights{
            .white_kingside = false,
            .white_queenside = false,
            .black_kingside = false,
            .black_queenside = false,
        };
    }

    pub fn all() CastlingRights {
        return CastlingRights{
            .white_kingside = true,
            .white_queenside = true,
            .black_kingside = true,
            .black_queenside = true,
        };
    }

    pub fn mask(self: CastlingRights) u4 {
        return @bitCast(self);
    }

    pub fn fromMask(mask_: u4) CastlingRights {
        return @bitCast(mask_);
    }
};
