#[test_only]
module ivm3::ivm3_tests {
    use ivm3::ivm3::{Self, IVM3, Registry,EAddressBanned};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx,Scenario};

    #[test]
    fun white_list(){
        let admin = @0xA;
        let user1 = @0xB;
        let scenario = prepare(admin);


        // amind  add admin to whiteList
        next_tx(&mut scenario, admin);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            let register = test_scenario::take_shared<Registry>(&scenario);
            ivm3::add_to_white_list(&mut treasurycap,&mut register,admin);

            // return value
            test_scenario::return_shared(register);
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };


         // admin send next transaction
         // amind  transafer IVM3 to user1
        next_tx(&mut scenario, admin);
        {
            let myIvm3 = test_scenario::take_from_sender<Coin<IVM3>>(&scenario);
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            let register = test_scenario::take_shared<Registry>(&scenario);
            assert!(coin::value(&myIvm3) == 100, 0);

            ivm3::transfer(&mut register,&mut myIvm3,100, user1, test_scenario::ctx(&mut scenario));

            // return value
            test_scenario::return_shared(register);
            test_scenario::return_to_sender(&scenario, myIvm3);
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };

        
        // clean scenario object
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EAddressBanned)]
    fun test_white_list_tranfer_failed() {
        let admin = @0xA;
        let user1 = @0xB;
        let scenario = prepare(admin);
        
    
         // admin send next transaction
         // amind  transafer IVM3 to user1
        next_tx(&mut scenario, admin);
        {
            let myIvm3 = test_scenario::take_from_sender<Coin<IVM3>>(&scenario);
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            let register = test_scenario::take_shared<Registry>(&scenario);
            assert!(coin::value(&myIvm3) == 100, 0);

            ivm3::transfer(&mut register,&mut myIvm3,100, user1, test_scenario::ctx(&mut scenario));

            // return value
            test_scenario::return_shared(register);
            test_scenario::return_to_sender(&scenario, myIvm3);
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };

         // clean scenario object
        test_scenario::end(scenario);
    }

    // remove from white list
    #[test]
    #[expected_failure(abort_code = EAddressBanned)]
    fun test_white_list_tranfer_failed2() {
        let admin = @0xA;
        let user1 = @0xB;
        let scenario = prepare(admin);

         // amind  add admin to whiteList
        next_tx(&mut scenario, admin);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            let register = test_scenario::take_shared<Registry>(&scenario);
            ivm3::add_to_white_list(&mut treasurycap,&mut register,admin);

            // return value
            test_scenario::return_shared(register);
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };

        // remove admin from whiteList
        next_tx(&mut scenario, admin);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            let register = test_scenario::take_shared<Registry>(&scenario);
            ivm3::remove_from_white_list(&mut treasurycap,&mut register,admin);

            // return value
            test_scenario::return_shared(register);
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };
        
    
         // admin send next transaction
         // amind  transafer IVM3 to user1
        next_tx(&mut scenario, admin);
        {
            let myIvm3 = test_scenario::take_from_sender<Coin<IVM3>>(&scenario);
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            let register = test_scenario::take_shared<Registry>(&scenario);
            assert!(coin::value(&myIvm3) == 100, 0);

            ivm3::transfer(&mut register,&mut myIvm3,100, user1, test_scenario::ctx(&mut scenario));

            // return value
            test_scenario::return_shared(register);
            test_scenario::return_to_sender(&scenario, myIvm3);
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };

         // clean scenario object
        test_scenario::end(scenario);
    }

    fun prepare(admin: address) :Scenario {
        let scenario = test_scenario::begin(admin);

        // run IVM3 init function
        {
            ivm3::test_init(ctx(&mut scenario));
        };

        // admin send next transaction
        next_tx(&mut scenario, admin);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<IVM3>>(&scenario);
            ivm3::mint(&mut treasurycap, 100, admin, test_scenario::ctx(&mut scenario));

            // return value
            test_scenario::return_to_address<TreasuryCap<IVM3>>(admin, treasurycap);
        };

        return (scenario)
    }
}