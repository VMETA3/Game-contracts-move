// SPDX-License-Identifier: MIT
module private_sale::private_sale_tests {
    use sui::sui::{SUI};
    use sui::coin::{Self};
    use sui::test_scenario::{Self, Scenario, next_tx};
    use private_sale::private_sale::{Self, Sale};
    use coin::vm3::{VM3};
    use sui::clock::{Self, Clock};

    const Admin: address = @0xAB10;
    const BadAdmin: address = @0xAD10;

    const User1: address = @0xAB11;
    const Day: u64 = 24*60*60*1000;
    const Week: u64 = 7 * 24*60*60*1000;
    const Month: u64 = 30 * 24*60*60*1000;

    #[test]
    fun normal_process() {
        let scenario = prepare(Admin);

        // user buy 12 VM3
        next_tx(&mut scenario, User1);
        {
            let myclock = test_scenario::take_shared<Clock>(&scenario);
            let sui_coin = coin::mint_for_testing<SUI>(12, test_scenario::ctx(&mut scenario));
            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::buy(&mut sale, sui_coin, &myclock,  test_scenario::ctx(&mut scenario));

            let (amount, _) = private_sale::get_user_asset<VM3, SUI>(&sale, User1);
            assert!(amount == 12, 0);
            
            test_scenario::return_shared(sale);
            test_scenario::return_shared(myclock);
        };

        // user withdraw  1 VM3 after one month;
        next_tx(&mut scenario, User1);
        {
            let myclock = test_scenario::take_shared<Clock>(&scenario);
            clock::increment_for_testing(&mut myclock, Month);

            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::withdraw(&mut sale, User1, &myclock, test_scenario::ctx(&mut scenario));
            let (amount, amount_withdrawn) = private_sale::get_user_asset<VM3, SUI>(&sale, User1);
            assert!(amount == 11 && amount_withdrawn == 1, 0);
            
            test_scenario::return_shared(sale );
            test_scenario::return_shared(myclock);
        };
        
        // user withdraw  2 VM3 after two month;
        next_tx(&mut scenario, User1);
        {
            let myclock = test_scenario::take_shared<Clock>(&scenario);
            clock::increment_for_testing(&mut myclock, Month*2);

            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::withdraw(&mut sale, User1, &myclock, test_scenario::ctx(&mut scenario));

            let (amount, amount_withdrawn) = private_sale::get_user_asset<VM3, SUI>(&sale, User1);
            assert!(amount == 9 && amount_withdrawn == 3, 0);
            
            
            test_scenario::return_shared(sale);
            test_scenario::return_shared(myclock);
        };

        // admin withdraw withdraw_received_token
        next_tx(&mut scenario, Admin);
        {
            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            let recipient = @0xBD10;
            private_sale::withdraw_received_token(&mut sale, recipient,  test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared(sale);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=private_sale::private_sale::ENotAdmin)]
    fun only_admin_can_add_white_list() {
        let scenario = prepare(Admin);

        // add user to whitlist
        next_tx(&mut scenario, BadAdmin);
        {   
            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::add_to_white_list(&mut sale, vector[User1], test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(sale);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code=private_sale::private_sale::ESaleNotStartOrEnd)] 
    fun sale_end_cannot_buy() {
        let scenario = prepare(Admin);

        // user buy 12 VM3
        next_tx(&mut scenario, User1);
        {
            let myclock = test_scenario::take_shared<Clock>(&scenario);
            clock::increment_for_testing(&mut myclock, Month); //default sale only has one week exparition

            let sui_coin = coin::mint_for_testing<SUI>(12, test_scenario::ctx(&mut scenario));
            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::buy(&mut sale, sui_coin, &myclock,  test_scenario::ctx(&mut scenario));

            let (amount, _) = private_sale::get_user_asset<VM3, SUI>(&sale, User1);
            assert!(amount == 12, 0);
            
            test_scenario::return_shared(sale);
            test_scenario::return_shared(myclock);
        };

        test_scenario::end(scenario);
    }

    fun prepare(admin: address): Scenario {
        let scenario = test_scenario::begin(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::share_for_testing(myclock);

        create_default_sale(Admin, &mut scenario);
        // add user to whitlist
        next_tx(&mut scenario, Admin);
        {   
            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::add_to_white_list(&mut sale, vector[User1], test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(sale);
        };

        //admin deposit vm3
        let vm3_for_sale_amount = 10000u64;
        next_tx(&mut scenario, Admin);
        {
            let vm3_coin = coin::mint_for_testing<VM3>(vm3_for_sale_amount, test_scenario::ctx(&mut scenario));
            let sale = test_scenario::take_shared<Sale<VM3, SUI>>(&scenario);
            private_sale::deposit(&mut sale, vm3_coin);

            test_scenario::return_shared(sale);
        };

        return (scenario)
    }

    fun create_default_sale(admin:address, scenario: &mut Scenario) {
        next_tx(scenario, admin);
        {
            let myclock = test_scenario::take_shared<Clock>(scenario);

            let price = 1u64;
            let person_max_buy = 100u64;
            let person_min_buy = 1u64;
            let start_time = 0u64;
            let release_start_time = 0u64;
            let release_total_months = 12u64;
            let end_time = timestamp(&myclock)+Week;
            private_sale::create_sale<VM3, SUI>(price, person_max_buy, person_min_buy, start_time, end_time, release_start_time, release_total_months, test_scenario::ctx(scenario));

            test_scenario::return_shared(myclock);
        };
    }

    // fun create_sale(admin:address, price:u64, person_max_buy:u64, person_min_buy:u64, start_time:u64,
    //     release_start_time:u64, release_total_months:u64, end_time:u64, scenario: &mut Scenario) {
        
    //     next_tx(scenario, admin);
    //     {
    //         let myclock = test_scenario::take_shared<Clock>(scenario);
    //         private_sale::create_sale<VM3, SUI>(price, person_max_buy, person_min_buy, start_time, end_time, release_start_time, release_total_months, test_scenario::ctx(scenario));
    //         test_scenario::return_shared(myclock);
    //     };
    // }

    fun timestamp(clock: &Clock): u64 {
        clock::timestamp_ms(clock)
    }
}