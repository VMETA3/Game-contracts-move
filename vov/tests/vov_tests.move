// SPDX-License-Identifier: Apache-2.0

#[test_only]
module vov::vov_tests {
    use vov::vov::{Self, VOV, DelayMintData, AdminParams, EOnlyAdminCanDo, EMintClosed, EMintRecently};
    use sui::coin::{TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use sui::clock::{Self};

    //constant
    const TwoDay: u64 = 2*24*60*60*1000; //ms
    const OneWeek: u64 = 7*24*60*60*1000;

    #[test]
    fun delayed_mint_test() {
        let admin = @0x1;
        let user = @0x2;
        let scenario = prepare(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));


        next_tx(&mut scenario, admin);
        {
            let amount = 100;
            let cap =  test_scenario::take_from_sender<TreasuryCap<VOV>>(&scenario);
            let delayed_mint_data = test_scenario::take_shared<DelayMintData>(&scenario);
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            
            clock::increment_for_testing(&mut myclock, TwoDay);
            vov::delayed_mint(&mut cap, &mut delayed_mint_data, &admin_params, user, amount, &myclock, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_address<TreasuryCap<VOV>>(admin, cap);
            test_scenario::return_shared(delayed_mint_data);
            test_scenario::return_shared(admin_params);
        };

        // check balance_of
        next_tx(&mut scenario, admin);
        {
            let delayed_mint_data = test_scenario::take_shared<DelayMintData>(&scenario);

            let b = vov::balance_of(&delayed_mint_data, user, &myclock);
            assert!(b==0, 0);
            clock::increment_for_testing(&mut myclock, OneWeek);
            b = vov::balance_of(&delayed_mint_data, user, &myclock);
            assert!(b==100, 0);

            test_scenario::return_shared(delayed_mint_data);
        };

        clock::destroy_for_testing(myclock);
        test_scenario::end(scenario);
    }

    // only admin can close mint 
    #[test]
    #[expected_failure(abort_code = EOnlyAdminCanDo)]
    fun close_mint_failed_test() {
        let admin = @0x1;
        let user = @0x2;
        let scenario = prepare(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));


        // admin close mint
        next_tx(&mut scenario, user);
        {
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            vov::close_mint(&mut admin_params, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(admin_params);
        };

        clock::destroy_for_testing(myclock);
        test_scenario::end(scenario);
    }

    // only admin can open mint 
    #[test]
    #[expected_failure(abort_code = EOnlyAdminCanDo)]
    fun open_mint_failed_test() {
        let admin = @0x1;
        let user = @0x2;
        let scenario = prepare(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));


        // user open mint, should be failed
        next_tx(&mut scenario, user);
        {
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            vov::open_mint(&mut admin_params, &myclock,test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(admin_params);
        };

        clock::destroy_for_testing(myclock);
        test_scenario::end(scenario);
    }

    // close mint, cannot mint immediately
    #[test]
    #[expected_failure(abort_code = EMintClosed)]
    fun mint_failed_for_closed_test() {
        let admin = @0x1;
        let user = @0x2;
        let scenario = prepare(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        // user close mint, should be failed
        next_tx(&mut scenario, admin);
        {
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            vov::close_mint(&mut admin_params, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(admin_params);
        };

        next_tx(&mut scenario, admin);
        {
            let amount = 100;
            let cap =  test_scenario::take_from_sender<TreasuryCap<VOV>>(&scenario);
            let delayed_mint_data = test_scenario::take_shared<DelayMintData>(&scenario);
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            
            clock::increment_for_testing(&mut myclock, TwoDay);
            vov::delayed_mint(&mut cap, &mut delayed_mint_data, &admin_params, user, amount, &myclock, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_address<TreasuryCap<VOV>>(admin, cap);
            test_scenario::return_shared(delayed_mint_data);
            test_scenario::return_shared(admin_params);
        };


        // user open mint, should be wait two days
        next_tx(&mut scenario, admin);
        {
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            vov::open_mint(&mut admin_params, &myclock,test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(admin_params);
        };
        next_tx(&mut scenario, admin);
        {
            let amount = 100;
            let cap =  test_scenario::take_from_sender<TreasuryCap<VOV>>(&scenario);
            let delayed_mint_data = test_scenario::take_shared<DelayMintData>(&scenario);
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            
            clock::increment_for_testing(&mut myclock, TwoDay);
            vov::delayed_mint(&mut cap, &mut delayed_mint_data, &admin_params, user, amount, &myclock, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_address<TreasuryCap<VOV>>(admin, cap);
            test_scenario::return_shared(delayed_mint_data);
            test_scenario::return_shared(admin_params);
        };

        clock::destroy_for_testing(myclock);
        test_scenario::end(scenario);
    }

    // only admin can open mint 
    #[test]
    #[expected_failure(abort_code = EMintRecently)]
    fun mint_recently_fail_test() {
        let admin = @0x1;
        let user = @0x2;
        let scenario = prepare(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));


        next_tx(&mut scenario, admin);
        {
            let amount = 100;
            let cap =  test_scenario::take_from_sender<TreasuryCap<VOV>>(&scenario);
            let delayed_mint_data = test_scenario::take_shared<DelayMintData>(&scenario);
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            
            clock::increment_for_testing(&mut myclock, TwoDay);
            vov::delayed_mint(&mut cap, &mut delayed_mint_data, &admin_params, user, amount, &myclock, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_address<TreasuryCap<VOV>>(admin, cap);
            test_scenario::return_shared(delayed_mint_data);
            test_scenario::return_shared(admin_params);
        };

        //mint recently should be failed
        next_tx(&mut scenario, admin);
        {
            let amount = 100;
            let cap =  test_scenario::take_from_sender<TreasuryCap<VOV>>(&scenario);
            let delayed_mint_data = test_scenario::take_shared<DelayMintData>(&scenario);
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            
            clock::increment_for_testing(&mut myclock, TwoDay);
            vov::delayed_mint(&mut cap, &mut delayed_mint_data, &admin_params, user, amount, &myclock, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_address<TreasuryCap<VOV>>(admin, cap);
            test_scenario::return_shared(delayed_mint_data);
            test_scenario::return_shared(admin_params);
        };


        clock::destroy_for_testing(myclock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EOnlyAdminCanDo)]
    fun update_admin_owner_fail(){
        let admin = @0x1;
        let user = @0x2;
        let new_admin = @0x3;
        let scenario = prepare(admin);
        let myclock = clock::create_for_testing(test_scenario::ctx(&mut scenario));


        // admin close mint
        next_tx(&mut scenario, user);
        {
            let admin_params = test_scenario::take_shared<AdminParams>(&scenario);
            vov::update_admin_owner_params(new_admin, &mut admin_params, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(admin_params);
        };

        clock::destroy_for_testing(myclock);
        test_scenario::end(scenario);
    }


    fun prepare(admin: address):  Scenario {
        let scenario = test_scenario::begin(admin);
        {
            vov::test_init(ctx(&mut scenario));
        };

        return (scenario)
    }
}