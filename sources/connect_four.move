module connectfour::connect_four {

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};

    use std::vector::{Self};

    const YellowTurn: u8 = 0;
    const RedTurn: u8 = 1;
    const YellowWon: u8 = 2;
    const RedWon: u8 = 3;

    const EmptySquare: u8 = 0;
    const YellowSquare: u8 = 1;
    const RedSquare: u8 = 2;

    const EInvalidMove: u64 = 0;
    const ENotYourTurn: u64 = 1;
    const EOpponentSelf: u64 = 2;
    const EIncorrectPerms: u64 = 3;
    const ENotYetTiemout: u64 = 4;
    const ENotOpponentsTurn: u64 = 5;

    struct RevokeChallengeCap has key {
        id: UID,
        challenge: address
    }

    struct AcceptChallengeCap has key {
        id: UID,
        challenge: address
    }

    struct Challenge has key {
        id: UID,
        stake: Coin<SUI>,
        from: address
    }

    struct YellowParticipation has key {
        id: UID,
        game: address
    }

    struct RedParticipation has key {
        id: UID,
        game: address
    }

    struct ConnectFourGame has key {
        id: UID,
        board: vector<vector<u8>>,
        game_status: u8,
        last_move: u64,
        stake: Coin<SUI>
    }

    public fun revoke_challenge(challenge: &mut Challenge, revoke_cap: RevokeChallengeCap, ctx: &mut TxContext) {
        let chall_address = object::id_to_address(&object::id(challenge));
        assert!(revoke_cap.challenge == chall_address, EIncorrectPerms);

        let RevokeChallengeCap {
            id,
            challenge: _
        } = revoke_cap;
        object::delete(id);

        let bal_mut = coin::value(&challenge.stake);
        let return_stake = coin::split(&mut challenge.stake, bal_mut, ctx);

        transfer::public_transfer(return_stake, tx_context::sender(ctx));
    }

    public fun challenge(to: address, stake: Coin<SUI>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender != to, EOpponentSelf);

        let id = object::new(ctx);
        let challenge_address = object::id_to_address(object::uid_as_inner(&id));
        let challenge = Challenge {
            id,
            stake,
            from: sender
        };
        transfer::share_object(challenge);

        let accept_cap = AcceptChallengeCap {
            id: object::new(ctx),
            challenge: challenge_address
        };
        transfer::transfer(accept_cap, to);

        let revoke_cap = RevokeChallengeCap {
            id: object::new(ctx),
            challenge: challenge_address
        };
        transfer::transfer(revoke_cap, sender);
    }

    public fun accept_challenge(challenge: &mut Challenge, accept_cap: AcceptChallengeCap, clock: &Clock, ctx: &mut TxContext) {
        assert!(accept_cap.challenge == object::id_to_address(object::uid_as_inner(&challenge.id)), EIncorrectPerms);

        let i =  0;
        let rows = vector<vector<u8>>[];
        while (i < 6) {
            let j = 0;
            let cols = vector<u8>[];
            while (j < 7) {
                vector::push_back(&mut cols, EmptySquare);
                j = j + 1;
            };
            vector::push_back(&mut rows, cols);
            i = i + 1;
        };

        let AcceptChallengeCap {
            id,
            challenge: _
        } = accept_cap;
        object::delete(id);

        let bal_mut = coin::value(&challenge.stake);
        let new_stake = coin::split(&mut challenge.stake, bal_mut, ctx);

        let game_id = object::new(ctx);
        let game_address = object::id_to_address(object::uid_as_inner(&game_id));
        let game = ConnectFourGame {
            id: game_id,
            board: rows,
            game_status: YellowTurn,
            last_move: clock::timestamp_ms(clock),
            stake: new_stake
        };
        transfer::share_object(game);

        let red_participation = RedParticipation {
            id: object::new(ctx),
            game: game_address
        };
        transfer::transfer(red_participation, challenge.from);

        transfer::transfer(YellowParticipation {
            id: object::new(ctx),
            game: game_address
        }, tx_context::sender(ctx))
    }

    public fun claim_timeout_red(game: ConnectFourGame, clock: &Clock): Coin<SUI> {
        assert!(clock::timestamp_ms(clock) - game.last_move > 1000 * 60 * 60, ENotYetTiemout);
        assert!(game.game_status == YellowTurn, ENotOpponentsTurn);
        let ConnectFourGame {
            id,
            board: _,
            stake,
            game_status: _,
            last_move: _
        } = game;
        object::delete(id);
        stake
    }

    public fun claim_timeout_yellow(game: ConnectFourGame, clock: &Clock): Coin<SUI> {
        assert!(clock::timestamp_ms(clock) - game.last_move > 1000 * 60 * 60, ENotYetTiemout);
        assert!(game.game_status == RedTurn, ENotOpponentsTurn);
        let ConnectFourGame {
            id,
            board: _,
            stake,
            game_status: _,
            last_move: _
        } = game;
        object::delete(id);
        stake
    }

    public fun get_mark_at(game: &ConnectFourGame, row: u64, col: u64): u8 {
        assert!(row < 6, 12);
        assert!(col < 7, 13);
        assert!(vector::length(&game.board) == 6, 11);
        let row_vec = vector::borrow(&game.board, row);
        assert!(vector::length(row_vec) == 7, 10);
        *vector::borrow(row_vec, col)
    }

    public fun check_win_in_direction(game: &ConnectFourGame, row: u64, col: u64, horiz: u8, vert: u8, yellow: bool): bool {
        let i = 0;
        let next_row = row;
        let next_col = col;
        while (i < 4) {
            let mark = get_mark_at(game, next_row, next_col);

            if (vert == 2) {
                next_row = next_row + 1;
            } else if (vert == 0) {
                if (next_row > 0) {
                    next_row = next_row - 1;
                };
            };

            if (horiz == 2) {
                next_col = next_col + 1;
            } else if (horiz == 0) {
                if (next_col > 0) {
                    next_col = next_col - 1;
                };
            };


            if (yellow) {
                if (mark != YellowSquare) {
                    return false
                };
            } else {
                if (mark != RedSquare) {
                    return false
                };
            };

            i = i + 1;
        };
        return true
    }

    public fun make_move_yellow(participation: &YellowParticipation, game: &mut ConnectFourGame, col: u64, ctx: &mut TxContext): bool {
        assert!(participation.game == object::id_to_address(object::uid_as_inner(&game.id)), EIncorrectPerms);
        let retval = make_move(game, true, col);
        if (game.game_status == YellowWon) {
            let bal_mut = coin::value(&game.stake);
            let return_stake = coin::split(&mut game.stake, bal_mut, ctx);
            transfer::public_transfer(return_stake, tx_context::sender(ctx));
        } else {
            game.game_status = RedTurn
        };
        retval
    }
    public fun make_move_red(participation: &RedParticipation, game: &mut ConnectFourGame, col: u64, ctx: &mut TxContext): bool {
        assert!(participation.game == object::id_to_address(object::uid_as_inner(&game.id)), EIncorrectPerms);
        let retval = make_move(game, false, col);
        if (game.game_status == RedWon) {
            let bal_mut = coin::value(&game.stake);
            let return_stake = coin::split(&mut game.stake, bal_mut, ctx);
            transfer::public_transfer(return_stake, tx_context::sender(ctx));
        } else {
            game.game_status = YellowTurn
        };
        retval
    }

    public fun make_move(game: &mut ConnectFourGame, is_yellow: bool, col: u64): bool {
        // Ensure move is within bounds and valid
        assert!(col < 7, EInvalidMove);
        let top_row = vector::borrow(&game.board, 5);
        assert!(*vector::borrow(top_row, col) == EmptySquare, EInvalidMove);

        // Ensure game is not already won and it is your turn
        assert!(game.game_status == if (is_yellow) { YellowTurn } else { RedTurn }, ENotYourTurn);

        // add move to gameboard
        let i = 0;
        while (i < 6) {
            let row = vector::borrow_mut(&mut game.board, i);
            let mark = vector::borrow_mut(row, col);
            if (*mark == EmptySquare) {
                *mark = if (is_yellow) {
                    YellowSquare
                } else {
                    RedSquare
                };
                break
            };
            i = i + 1;
        };

        // check if player wins
        // Check all vertical wins
        let i = 0;
        while (i < 3) {
            let j = 0;
            while (j < 7) {
                if (check_win_in_direction(game, i, j, 1, 2, is_yellow)) {
                    game.game_status = if (is_yellow) { YellowWon } else { RedWon };
                };
                j = j + 1;
            };
            i = i + 1;
        };

        // Check horizontal wins
        let i = 0;
        while (i < 6) {
            let j = 0;
            while (j < 4) {
                if (check_win_in_direction(game, i, j, 2, 1, is_yellow)) {
                    game.game_status = if (is_yellow) { YellowWon } else { RedWon };
                };
                j = j + 1;
            };
            i = i + 1;
        };

        // Check up and right
        let i = 0;
        while (i < 3) {
            let j = 0;
            while (j < 4) {
                if (check_win_in_direction(game, i, j, 2, 2, is_yellow)) {
                    game.game_status = if (is_yellow) { YellowWon } else { RedWon };
                };
                j = j + 1;
            };
            i = i + 1;
        };

        // Check down and right
        let i = 3;
        while (i < 6) {
            let j = 0;
            while (j < 4) {
                if (check_win_in_direction(game, i, j, 2, 0, is_yellow)) {
                    game.game_status = if (is_yellow) { YellowWon } else { RedWon };
                };
                j = j + 1;
            };
            i = i + 1;
        };

        if (is_yellow) {
            return game.game_status == YellowWon
        } else {
            return game.game_status == RedWon
        }
    }
}
