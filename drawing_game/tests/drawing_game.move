#[test_only]
module drawing_game::drawing_game_tests {
    // local
    use drawing_game::drawing_game::{Self, BonusPool, OwnerCapability, InitLock, EAlreadyInitialized};
    // sui framework
    use sui::object::{Self, UID};
    use sui::test_scenario::{Self, Scenario, next_tx};
    use sui::tx_context::{TxContext};
    use sui::vec_map::{Self, VecMap};
    use std::vector;
    use sui::vec_set::{Self};
    use std::bcs;
    //use std::debug;

    struct TestNFT has key, store {
        id: UID,
    }

    const Creator: address = @0xAB10;
    const Users: vector<address> = vector[@0xAC10, @0xAC11, @0xAC12, @0xAC13, @0xAC14, @0xAC15, @0xAC16, @0xAC17, @0xAC18, @0xAC19];

    #[test]
    #[expected_failure(abort_code = EAlreadyInitialized)]
    fun init_drawing_game_test() {
        let scenario = prepare(Creator);

        // failed if init twice
        next_tx(&mut scenario, Creator);
        {
            let init_lock = test_scenario::take_shared<InitLock>(&scenario); 
            drawing_game::initialize<TestNFT>(&mut init_lock, test_scenario::ctx(&mut scenario));

            //return object
            test_scenario::return_shared(init_lock);
        };

        
        // clean scenario object
        test_scenario::end(scenario);
    }

    #[test] 
    fun deposit_test() {
        let scenario = prepare(Creator);

        next_tx(&mut scenario, Creator);
        {
            let cap = test_scenario::take_from_sender<OwnerCapability>(&scenario);
            let bonus_pool = test_scenario::take_shared<BonusPool<TestNFT>>(&scenario);
            deposit(&cap, &mut bonus_pool, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, cap);
            test_scenario::return_shared(bonus_pool);
        };

        next_tx(&mut scenario, Creator);
        {
            let cap = test_scenario::take_from_sender<OwnerCapability>(&scenario);
            let bonus_pool = test_scenario::take_shared<BonusPool<TestNFT>>(&scenario);
            deposit_many(10, &cap, &mut bonus_pool, test_scenario::ctx(&mut scenario));
            assert!(drawing_game::nfts_pool_number(&bonus_pool) == 11, 0);

            test_scenario::return_to_sender(&scenario, cap);
            test_scenario::return_shared(bonus_pool);
        };

        // clean scenario object
        test_scenario::end(scenario);
    }

    #[test] 
    fun get_users_test() {
        {
            let users_level = generate_users_level();
            assert!(vec_map::size(&users_level) == 3, 0);

            let (users, _, total_weight) = drawing_game::get_users(&vec_set::empty(), users_level);
            assert!(total_weight == 21, 0);
            assert!(vector::length(&users) == 3, 0);

            // let  user = vector::borrow(&users, 0);
            // debug::print(&drawing_game::get_investment_account_addr(user));
        };
    }

    #[test]
    fun draw_test() {
        let scenario = prepare(Creator);
        next_tx(&mut scenario, Creator);
        {
            let cap = test_scenario::take_from_sender<OwnerCapability>(&scenario);
            let bonus_pool = test_scenario::take_shared<BonusPool<TestNFT>>(&scenario);
            deposit_many(10, &cap, &mut bonus_pool, test_scenario::ctx(&mut scenario));
            assert!(drawing_game::nfts_pool_number(&bonus_pool) == 10, 0);

            test_scenario::return_to_sender(&scenario, cap);
            test_scenario::return_shared(bonus_pool);
        };

        next_tx(&mut scenario, Creator);
        {
            let random_number: u64 = 1;
            let random_number_bytes = bcs::to_bytes(&random_number);
            let bonus_pool = test_scenario::take_shared<BonusPool<TestNFT>>(&scenario);
            let users_level = generate_users_level();

            let (winners, winners_lucky_number) = drawing_game::test_draw(&mut bonus_pool, 1, users_level, random_number_bytes);
            assert!(vector::length(&winners) == 1, 0);
            //debug::print(vector::borrow(&winners_lucky_number, 0));
            assert!(vector::contains(&winners_lucky_number, &(1 as u64)), 0);
            assert!(vector::contains(&winners, vector::borrow(&Users, 3)), 0);
            
            test_scenario::return_shared(bonus_pool);
        };

        // clean scenario object
        test_scenario::end(scenario);
    }

    #[test]
    fun bytes2u64_test() {
        {
            let number: u64 = 10;
            let number_bytes = bcs::to_bytes(&number);
            let n = drawing_game::bytes2u64(number_bytes);
            assert!(number == n, 0);
        };
    
        {
            let number: u64 = 899;
            let number_bytes = bcs::to_bytes(&number);
            let n = drawing_game::bytes2u64(number_bytes);
            assert!(number == n, 0);
        };

        {
            let number: u64 = 889192;
            let number_bytes = bcs::to_bytes(&number);
            let n = drawing_game::bytes2u64(number_bytes);
            assert!(number == n, 0);
        };
    }
    
    // prepare before each test
    fun prepare(admin: address) :Scenario {
        let scenario = test_scenario::begin(admin);
        {
            drawing_game::test_init(test_scenario::ctx(&mut scenario));
        };

        next_tx(&mut scenario, Creator);
        {
            let init_lock = test_scenario::take_shared<InitLock>(&scenario); 
            drawing_game::initialize<TestNFT>(&mut init_lock, test_scenario::ctx(&mut scenario));

            //return object
            test_scenario::return_shared(init_lock);
        };

        return (scenario)
    }

    //===== Util =====
    fun deposit(cap:&OwnerCapability, bonus_pool: &mut BonusPool<TestNFT>, ctx: &mut TxContext) {
        let nft = TestNFT { id: object::new(ctx) };
        drawing_game::deposit(cap, bonus_pool, nft);
    }

    fun deposit_many(
        amount: u64,
        cap:&OwnerCapability, bonus_pool: &mut BonusPool<TestNFT>, ctx: &mut TxContext
    ) {
        let i = 0;
        while (i < amount) {
            deposit(cap, bonus_pool, ctx);
            i = i + 1;
        };
    }

    fun generate_users_level(): VecMap<address, u8> {
        let users_level = vec_map::empty<address, u8>();

        vec_map::insert(&mut users_level, *vector::borrow(&Users, 1), 1);
        vec_map::insert(&mut users_level, *vector::borrow(&Users, 2), 2);
        vec_map::insert(&mut users_level, *vector::borrow(&Users, 3), 3);
        return (users_level)
    }
}