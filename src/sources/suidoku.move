module suidoku::suidoku {
    use std::vector;

    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::package::{Self, Publisher};
    use sui::table::{Self, Table};

    use suidoku::pseudorandom::{Self, Counter};

    const SEED: vector<u8> = vector<u8>[6, 9, 4, 2, 0];
    const LENGTH: u8 = 9;
    const BLANK_BOARD: vector<vector<u8>> = vector<vector<u8>>[
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
        vector<u8>[0, 0, 0, 0, 0, 0, 0, 0, 0],
    ];

    const ERR_PLAYER_NOT_REGISTERED: u64 = 1;
    const ERR_PLAYER_ALREADY_REGISTERED: u64 = 2;
    const ERR_INVALID_BOARD: u64 = 3;
    const ERR_INVALID_SOLUTION: u64 = 4;

    struct Game has store {
        board: vector<vector<u8>>,
        creator: address,
        attempts: u64,
        completed: u64,
    }

    struct GamesHolder has key {
        id: UID,
        games: vector<Game>,
        players: Table<address, ID>
    }

    struct GamesInfo has key {
        id: UID,
        games_addr: Publisher,
    }

    struct Player has key {
        id: UID,
        current_game_id: u64,
        attempts: u64,
        completed: u64,
    }

    struct SUIDOKU has drop {}

    fun init(witness: SUIDOKU, ctx: &mut TxContext) {
        transfer::share_object(
            GamesInfo {
                id: object::new(ctx),
                games_addr: package::claim(witness, ctx)
            }
        );
        transfer::share_object(
            GamesHolder {
                id: object::new(ctx),
                games: vector::singleton<Game>(
                    Game {
                        board: BLANK_BOARD,
                        creator: @dev,
                        attempts: 0,
                        completed: 0,
                    }
                ),
                players: table::new<address, ID>(ctx)
            }
        );
    }

    public fun register(holder: &mut GamesHolder, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(!registered(holder, sender), ERR_PLAYER_ALREADY_REGISTERED);
        let player = Player {
                        id: object::new(ctx),
                        current_game_id: 0,
                        attempts: 0,
                        completed: 0
                    };
        let player_id = object::id(&player);
        table::add(&mut holder.players, sender, player_id);
        transfer::transfer(player, sender);
    }

    public fun add(
        holder: &mut GamesHolder,
        board: vector<vector<u8>>,
        solution: vector<vector<u8>>,
        ctx: &mut TxContext
    )  {
        let creator_addr = tx_context::sender(ctx);
        assert!(registered(holder, creator_addr), ERR_PLAYER_NOT_REGISTERED);
        
        check_solution(&board, &solution);
        internal_add(holder, creator_addr, board);
    }

    public fun solve(
        player: &mut Player,
        holder: &mut GamesHolder,
        counter: &mut Counter,
        solution: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let player_addr = tx_context::sender(ctx);
        assert!(registered(holder, player_addr), ERR_PLAYER_NOT_REGISTERED);

        internal_solve(player, holder, counter, &solution);
    }

    public fun pass(
        player: &mut Player,
        holder: &mut GamesHolder,
        counter: &mut Counter,
        ctx: &mut TxContext
    ) {
        let player_addr = tx_context::sender(ctx);
        assert!(registered(holder, player_addr), ERR_PLAYER_NOT_REGISTERED);

        internal_pass(player, holder, counter);
    }

    fun internal_add(
        holder: &mut GamesHolder,
        creator: address,
        board: vector<vector<u8>>
    ) {
        let games = &mut holder.games;

        vector::push_back<Game>(
            games,
            Game {
                board: board,
                creator: creator,
                attempts: 0,
                completed: 0,
            }
        );
    }

    fun internal_solve(
        player: &mut Player,
        holder: &mut GamesHolder,
        counter: &mut Counter,
        solution: &vector<vector<u8>>
    ) {
        let games = &mut holder.games;
        let game = vector::borrow_mut<Game>(
            games,
            player.current_game_id
        );
        let board = &game.board;

        check_solution(board, solution);
        post_solution_check(player, game);
        new_game(player, games, counter);
    }

    fun internal_pass(
        player: &mut Player,
        holder: &mut GamesHolder,
        counter: &mut Counter,
    ) {
        let games = &mut holder.games;

        new_game(player, games, counter);
    }

    fun check_solution(
        board: &vector<vector<u8>>,
        solution: &vector<vector<u8>>
    ) {
        check_boards_validity(board, solution);
        check_rows(solution);
        check_cols(solution);
        check_sub_squares(solution);
    }

    fun check_boards_validity(
        board: &vector<vector<u8>>,
        solution: &vector<vector<u8>>
    ) {
        assert!(vector::length<vector<u8>>(board) == (LENGTH as u64), ERR_INVALID_BOARD);
        assert!(vector::length<vector<u8>>(solution) == (LENGTH as u64), ERR_INVALID_BOARD);

        let row = 0;
        let col = 0;
        while (row < vector::length<vector<u8>>(board)) {
            let board_row = vector::borrow<vector<u8>>(board, row); 
            let solution_row = vector::borrow<vector<u8>>(solution, row);
            assert!(vector::length<u8>(board_row) == (LENGTH as u64), ERR_INVALID_BOARD);
            assert!(vector::length<u8>(solution_row) == (LENGTH as u64), ERR_INVALID_BOARD);
            while (col < vector::length<u8>(board_row)) {
                let board_cell = *vector::borrow<u8>(board_row, col);
                let solution_cell = *vector::borrow<u8>(solution_row, col);
                assert!(board_cell == solution_cell || board_cell == 0, ERR_INVALID_BOARD);
                col = col + 1;
            };
            row = row + 1;
        };
    }

    fun check_rows(
        solution: &vector<vector<u8>>
    ) {
        let row = 0;
        while (row < (LENGTH as u64)) {
            check_values(vector::borrow<vector<u8>>(solution, row));
            row = row + 1;
        };
    }

    fun check_cols(
        solution: &vector<vector<u8>>
    ) {
        let col = 0;
        let row = 0;

        while (col < (LENGTH as u64)) {
            let col_vec = vector::empty<u8>();
            while (row < (LENGTH as u64)) {
                vector::push_back<u8>(
                    &mut col_vec,
                    *vector::borrow<u8>(
                        vector::borrow<vector<u8>>(
                            solution,
                            row
                        ),
                        col
                    )
                );
                row = row + 1;
            };
            check_values(&col_vec);
            col = col + 1;
        };
    }
    
    fun check_sub_squares(
        solution: &vector<vector<u8>>
    ) {
        let row = 0;
        let col = 0;
        let sub_row = 0;
        let sub_col = 0;

        while (row < (LENGTH as u64)) {
            while (col < (LENGTH as u64)) {
                let sub_square_vec = vector::empty<u8>();
                while (sub_row < 3) {
                    while (sub_col < 3) {
                        vector::push_back(
                            &mut sub_square_vec,
                            *vector::borrow<u8>(
                                vector::borrow<vector<u8>>(
                                    solution,
                                    col + sub_col
                                ),
                                row + sub_row
                            )
                        );
                        sub_col = sub_col + 1;
                    };
                    sub_row = sub_row + 1;
                };
                check_values(&sub_square_vec);
                col = col + 3;
            };
            row = row + 3;
        };
    }

    fun check_values(values: &vector<u8>) {
        let i: u8 = 1;
        while (i <= LENGTH) {
            assert!(vector::contains<u8>(values, &i), ERR_INVALID_SOLUTION);
            i = i + 1;
        };
    }

    fun post_solution_check(
        player: &mut Player,
        game: &mut Game
    ) {
        player.completed =  player.completed + 1;
        game.completed = game.completed + 1;
    }

    fun new_game(
        player: &mut Player,
        games: &mut vector<Game>,
        counter: &mut Counter
    ) {
        let game_id = pseudorandom::rand_u64_range_with_counter(
            counter, 
            1, 
            vector::length<Game>(games)
        );

        let game = vector::borrow_mut<Game>(games, game_id);
        game.attempts = game.attempts + 1;
        
        player.current_game_id = game_id;
        player.attempts = player.attempts + 1;
    }

    fun registered(holder: &GamesHolder, account: address): bool {
        let player_list = &holder.players;
        table::contains(player_list, account)
    }

    //////////////////////////////
    // TESTS
    //////////////////////////////

    #[test_only]
    fun setup(
        holder: &mut GamesHolder,
        witness: SUIDOKU,
        ctx: &mut TxContext
    ): vector<vector<u8>> {
        init(witness, ctx);

        let board: vector<vector<u8>> = vector<vector<u8>>[
            vector<u8>[0, 0, 0, 0, 0, 0, 2, 0, 0],
            vector<u8>[0, 8, 0, 0, 0, 7, 0, 9, 0],
            vector<u8>[6, 0, 2, 0, 0, 0, 5, 0, 0],
            vector<u8>[0, 7, 0, 0, 6, 0, 0, 0, 0],
            vector<u8>[0, 0, 0, 9, 0, 1, 0, 0, 0],
            vector<u8>[0, 0, 0, 0, 2, 0, 0, 4, 0],
            vector<u8>[0, 0, 5, 0, 0, 0, 6, 0, 3],
            vector<u8>[0, 9, 0, 4, 0, 0, 0, 7, 0],
            vector<u8>[0, 0, 6, 0, 0, 0, 0, 0, 0],
        ];
        let solution: vector<vector<u8>> = vector<vector<u8>>[
            vector<u8>[9, 5, 7, 6, 1, 3, 2, 8, 4],
            vector<u8>[4, 8, 3, 2, 5, 7, 1, 9, 6],
            vector<u8>[6, 1, 2, 8, 4, 9, 5, 3, 7],
            vector<u8>[1, 7, 8, 3, 6, 4, 9, 5, 2],
            vector<u8>[5, 2, 4, 9, 7, 1, 3, 6, 8],
            vector<u8>[3, 6, 9, 5, 2, 8, 7, 4, 1],
            vector<u8>[8, 4, 5, 7, 9, 2, 6, 1, 3],
            vector<u8>[2, 9, 1, 4, 3, 6, 8, 7, 5],
            vector<u8>[7, 3, 6, 1, 8, 5, 4, 2, 9],
        ];

        register(holder, ctx);
        add(holder, board, solution, ctx);

        solution
    }
}