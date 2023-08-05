module connectfour::connect_four {

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use std::vector::{Self};

    const NotWon: u8 = 0;
    const YellowWon: u8 = 1;
    const RedWon: u8 = 2;

    const EmptySquare: u8 = 0;
    const YellowSquare: u8 = 1;
    const RedSquare: u8 = 2;

    const EInvalidMove: u64 = 0;
    const EGameAlreadyWon: u64 = 1;
    const EOpponentSelf: u64 = 2;

    struct ConnectFourGame has key, store {
        id: UID,
        board: vector<vector<u8>>,
        game_status: u8,
        yellow: address,
        red: address
    }

    public entry fun start_game_with(opponent: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender != opponent, EOpponentSelf);

        let i = 0;
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

        let game = ConnectFourGame {
            id: object::new(ctx),
            board: rows,
            game_status: NotWon,
            yellow: tx_context::sender(ctx),
            red: opponent
        };

        transfer::transfer(game, sender);
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

    public entry fun stop_playing(game: ConnectFourGame) {
        let ConnectFourGame {
            id,
            board: _,
            red: _,
            yellow: _,
            game_status: _
        } = game;
        object::delete(id);
    }

    public entry fun make_move(game: ConnectFourGame, col: u64, ctx: &mut TxContext) {
        let yellow = game.yellow;
        let is_yellow = tx_context::sender(ctx) == yellow;
        // Ensure move is within bounds and valid
        assert!(col < 7, EInvalidMove);
        let top_row = vector::borrow(&game.board, 5);
        assert!(*vector::borrow(top_row, col) == EmptySquare, EInvalidMove);

        // Ensure game is not already won
        assert!(game.game_status == NotWon, EGameAlreadyWon);

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
                if (check_win_in_direction(&game, i, j, 1, 2, is_yellow)) {
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
                if (check_win_in_direction(&game, i, j, 2, 1, is_yellow)) {
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
                if (check_win_in_direction(&game, i, j, 2, 2, is_yellow)) {
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
                if (check_win_in_direction(&game, i, j, 2, 0, is_yellow)) {
                    game.game_status = if (is_yellow) { YellowWon } else { RedWon };
                };
                j = j + 1;
            };
            i = i + 1;
        };

        // transfer board to opponent
        let opponent = if (tx_context::sender(ctx) == game.yellow) {
            game.red
        } else {
            game.yellow
        };
        transfer::transfer(game, opponent);
    }
}
