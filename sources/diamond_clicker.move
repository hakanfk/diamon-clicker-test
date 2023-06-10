module diamond_clicker::game {
    use std::signer;
    use std::vector;

    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    /*
    Errors
    DO NOT EDIT
    */
    const ERROR_GAME_STORE_DOES_NOT_EXIST: u64 = 0;
    const ERROR_UPGRADE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE: u64 = 2;

    /*
    Const
    DO NOT EDIT
    */
    const POWERUP_NAMES: vector<vector<u8>> = vector[b"Bruh", b"Aptomingos", b"Aptos Monkeys"];
    // cost, dpm (diamonds per minute)
    const POWERUP_VALUES: vector<vector<u64>> = vector[
        vector[5, 5],
        vector[25, 30],
        vector[250, 350],
    ];

    /*
    Structs
    DO NOT EDIT
    */
    struct Upgrade has key, store, copy {
        name: vector<u8>,
        amount: u64
    }

    struct GameStore has key {
        diamonds: u64,
        upgrades: vector<Upgrade>,
        last_claimed_timestamp_seconds: u64,
    }

    /*
    Functions
    */

    public fun initialize_game(account: &signer) {
        // move_to account with new GameStore
        let game_store = GameStore{
            diamonds: 0,
            upgrades: Vector::empty<Upgrade>(),
            last_claimed_timestamp_seconds: Timestamp::now_seconds()
        };

        move_to(account, game_store);
    }

    public entry fun click(account: &signer) acquires GameStore {
        // check if GameStore does not exist - if not, initialize_game
        let account_addr = Signer::address_of(account);
        if(!(exists<GameStore>(account_addr))){
            initialize_game(account);
        }

        // increment game_store.diamonds by +1
        let users_game_store = borrow_global_mut<GameStore>(account_addr);
        users_game_store.diamonds = users_game_store + 1;
    }

    fun get_unclaimed_diamonds(account_address: address, current_timestamp_seconds: u64): u64 acquires GameStore {
        // loop over game_store.upgrades - if the powerup exists then calculate the dpm and minutes_elapsed to add the amount to the unclaimed_diamonds
        let game_store = borrow_global<GameStore>(account_address);
        let minutes_elapsed = (current_timestamp_seconds - game_store.last_claimed_timestamp_seconds)/60;
        
        let mut unclaimed_diamonds = 0;
        let length = Vector::length(&game_store.upgrades);
        let i = 0;
        while(i < length){
            let upgrade = *Vector::borrow(&game_store.upgrades, i);
            let mut index = 0;

            let powerup_length = Vector::length(&POWERUP_NAMES);
            while(index < powerup_length){
                if(Vector::borrow(&POWERUP_NAMES, powerup_index) == &upgrade.name) break;
                index = index+1;
            }

            if(powerup_index < powerup_length){
                let powerup_value = *Vector::borrow(&POWERUP_VALUES, powerup_index);
                let dpm = *Vector::borrow(&powerup_value, 1)
                unclaimed_diamonds = unclaimed_diamonds + (dpm * upgrade.amount * minutes_elapsed);
            }

        }
        // return unclaimed_diamonds
        unclaimed_diamonds;
    }

    fun claim(account_address: address) acquires GameStore {
        // set game_store.diamonds to current diamonds + unclaimed_diamonds
        let game_store = borrow_global_mut<GameStore>(account_address);
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, Timestamp::now_seconds());
        game_store.diamonds = game_store.diamonds + unclaimed_diamonds;
        // set last_claimed_timestamp_seconds to the current timestamp in seconds
        game_store.last_claimed_timestamp_seconds = Timestamp::now_seconds();
    }

    public entry fun upgrade(account: &signer, upgrade_index: u64, upgrade_amount: u64) acquires GameStore {
        // check that the game store exists
        let addr = Signer::address_of(account);
        if(!(exists<GameStore>(addr))){
            initialize_game(account);
        }
       
        // check the powerup_names length is greater than or equal to upgrade_index
        let powerup_names_length = Vector::length(&POWERUP_NAMES);
        assert(upgrade_index <= powerup_names_length, ERROR_UPGRADE_DOES_NOT_EXIST);

        // claim for account address
        claim(addr);

        // check that the user has enough coins to make the current upgrade
        let upgrade_cost = *Vector::borrow(&POWERUP_VALUES[upgrade_index], 0) * upgrade_amount;
        let users_game_store = borrow_global_mut<GameStore>(addr);
        assert(users_game_store.diamonds >= upgrade_cost, ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE);

        // loop through game_store upgrades - if the upgrade exists then increment but the upgrade_amount
        let length_of_upgrades = Vector::length(&users_game_store.upgrades);
        let mut upgrade_existed = false;

        let index = 0;
        while(index < length_of_upgrades){
            let upgrade = Vector::borrow_mut(&users_game_store.upgrades, i);
            if(Vector::equals(&upgrade.name, Vector::borrow(&POWERUP_NAMES, index as usize))){
                upgrade.amount = upgrade_amount + 1;
                upgrade_existed = true;
                break;
            }
            i = i+1;
        }

        // if upgrade_existed does not exist then create it with the base upgrade_amount
        if(!upgrade_existed){
            let new_upgrade = Upgrade{
                name: Vector::borrow(&POWERUP_NAMES, upgrade_index as usize),
                amount: upgrade_amount;
            };
            let upgrades_mut = &mut users_game_store.upgrades;
            Vector::push_back(upgrades_mut, new_upgrade);
        }


        // set game_store.diamonds to current diamonds - total_upgrade_cost
        users_game_store.diamonds = users_game_store.diamonds - upgrade_cost;
    }

    #[view]
    public fun get_diamonds(account_address: address): u64 acquires GameStore {
        // return game_store.diamonds + unclaimed_diamonds
        let game_store = borrow_global<GameStore>(account_address);
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, Timestamp::now_seconds());
        game_store.diamonds + unclaimed_diamonds;
    }

    #[view]
    public fun get_diamonds_per_minute(account_address: address): u64 acquires GameStore {
        // loop over game_store.upgrades - calculate dpm * current_upgrade.amount to get the total diamonds_per_minute
        let game_store = borrow_global<GameStore>(account_address);
        let length = Vector::length(&game_store.upgrades);
        let index = 0;
        let mut dpm_total = 0;

        while(index < length){
            let upgrade = Vector::borrow(&game_store.upgrades, index);
            let dpm = *Vector::borrow(&POWERUP_VALUES[upgrade.name as usize], 0);
            dpm_total = dpm * upgrade.amount;
            i = i+1;
        } 
        // return diamonds_per_minute of all the user's powerups
        dpm_total;
    }

    #[view]
    public fun get_powerups(account_address: address): vector<Upgrade> acquires GameStore {
        // return game_store.upgrades
        let game_store = borrow_global<GameStore>(account_address);
        game_store.upgrades;
    }

    /*
    Tests
    DO NOT EDIT
    */
    inline fun test_click_loop(signer: &signer, amount: u64) acquires GameStore {
        let i = 0;
        while (amount > i) {
            click(signer);
            i = i + 1;
        }
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_without_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_with_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 2, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 0, location = diamond_clicker::game)]
    fun test_upgrade_does_not_exist(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 2, location = diamond_clicker::game)]
    fun test_upgrade_does_not_have_enough_diamonds(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_one(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 5);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_two(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 25);

        upgrade(test_one, 1, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_three(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 250);

        upgrade(test_one, 2, 1);
    }
}