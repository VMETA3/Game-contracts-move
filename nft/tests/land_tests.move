#[test_only]
module nft::land_test {
    use sui::test_scenario::{Self as ts, Scenario, ctx, next_tx};
    use sui::sui::SUI;
    use sui::coin;
    use sui::clock::{Self, Clock};
    use nft::land::{Self, OwnerCap, MinterCap, Land, Noteboard};

    const OWNER: address = @0xA1C05;
    const MINTER: address = @0xA1C20;
    const USER: address = @0xA1C21;

    const ActiveCondition: u64 = 100000000000;
    const MinimumInjectionQuantity: u64 = 1000000000;
    const TwoDay: u64 = 2*24*60*60*1000;


    fun prepare(): Scenario {
        let scenario = ts::begin(OWNER);
        {
            land::test_init(ctx(&mut scenario));
        };

        next_tx(&mut scenario, OWNER);
        {
            let owner_cap = ts::take_from_sender<OwnerCap>(&scenario);
            let coin = coin::mint_for_testing<SUI>(0, ctx(&mut scenario));
            land::create(&owner_cap, coin, MINTER, ActiveCondition, MinimumInjectionQuantity, ctx(&mut scenario));
            ts::return_to_sender<OwnerCap>(&scenario, owner_cap);
        };

        next_tx(&mut scenario, OWNER);
        {
            clock::share_for_testing(clock::create_for_testing(ctx(&mut scenario)));
        };
        scenario
    }

    fun mint(scenario: &mut Scenario){
        next_tx(scenario, MINTER);
        {
            let mint_cap = ts::take_from_sender<MinterCap>(scenario);  
            let note = ts::take_shared<Noteboard<SUI>>(scenario);
            let clock = ts::take_shared<Clock>(scenario);

            let to = USER;
            let uri = b"test";


            land::mint(&clock, &mint_cap, &note, to, uri, ctx(scenario));

            ts::return_to_sender<MinterCap>(scenario, mint_cap);
            ts::return_shared(note);
            ts::return_shared(clock);
        };
    }

    #[test]
    public fun test_mint_as_minter() {
        let scenario = prepare();
        mint(&mut scenario);
        ts::end(scenario);
    }

    #[test]
    public fun inject_active() {
        let scenario = prepare();
        mint(&mut scenario);
        
        next_tx(&mut scenario, USER);
        {
            let land = ts::take_from_sender<Land>(&scenario);  
            let note = ts::take_shared<Noteboard<SUI>>(&scenario);

            let coin = coin::mint_for_testing<SUI>(ActiveCondition, ctx(&mut scenario));
            land::inject_active(coin, &mut land, USER, &mut note);

            ts::return_to_sender<Land>(&scenario, land);
            ts::return_shared<Noteboard<SUI>>(note);
        };

        next_tx(&mut scenario, USER);
        {
            let land = ts::take_from_sender<Land>(&scenario);  

            let status = land::get_land_status(&land);
            assert!(status == true, 0);

            ts::return_to_sender<Land>(&scenario, land);
        };
        ts::end(scenario);
    }

    #[test]
    public fun switch_mint_status() {
        let scenario = prepare();
        
        // disable_mint
        next_tx(&mut scenario, OWNER);
        {
            let note = ts::take_shared<Noteboard<SUI>>(&scenario);
            let owner_cap = ts::take_from_sender<OwnerCap>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            // Mint status default status is true
            let status = land::get_enable_mint_status(&clock, &note);
            assert!(status == true, 0);

            land::disable_mint(&clock, &owner_cap, &mut note);

            //  Change the status immediately after executing disable_mint
            let status = land::get_enable_mint_status(&clock, &note);
            assert!(status == false, 0);

            ts::return_shared<Noteboard<SUI>>(note);
            ts::return_to_sender<OwnerCap>(&scenario, owner_cap);
            ts::return_shared(clock);
        };

        // enable_mint
        next_tx(&mut scenario, OWNER);
        {
            let note = ts::take_shared<Noteboard<SUI>>(&scenario);
            let owner_cap = ts::take_from_sender<OwnerCap>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            clock::increment_for_testing(&mut clock, 1);
            land::enable_mint(&clock, &owner_cap, &mut note);


            ts::return_shared<Noteboard<SUI>>(note);
            ts::return_to_sender<OwnerCap>(&scenario, owner_cap);
            ts::return_shared(clock);
        };

        next_tx(&mut scenario, OWNER);
        {

            let note = ts::take_shared<Noteboard<SUI>>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            // Less than 48 hours, the state is still false.
            let status = land::get_enable_mint_status(&clock, &note);
            assert!(status == false, 0);
            
            // It takes 48 hours to enable mint.
            clock::increment_for_testing(&mut clock, TwoDay);
            let status = land::get_enable_mint_status(&clock, &note);
            assert!(status == true, 0);

            ts::return_shared<Noteboard<SUI>>(note);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

        #[test]
    public fun modify_active_condition() {
        let scenario = prepare();
        
        // disable_mint
        next_tx(&mut scenario, OWNER);
        {
            let note = ts::take_shared<Noteboard<SUI>>(&scenario);
            let owner_cap = ts::take_from_sender<OwnerCap>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            // Default condition
            let condition = land::get_active_condition(&clock, &note);
            assert!(condition == ActiveCondition, 0);

            let new_condition = ActiveCondition + 1;
            land::set_active_condition(&clock, &owner_cap, &mut note, new_condition);

            // Less than 48 hours, remain unchanged.
            let condition = land::get_active_condition(&clock, &note);
            assert!(condition == ActiveCondition, 0);
            
            // It takes 48 hours to change condition.
            clock::increment_for_testing(&mut clock, TwoDay);
            let condition = land::get_active_condition(&clock, &note);
            assert!(condition == new_condition, 0);

            ts::return_shared<Noteboard<SUI>>(note);
            ts::return_to_sender<OwnerCap>(&scenario, owner_cap);
            ts::return_shared(clock);
        };
        ts::end(scenario);
    }
}
