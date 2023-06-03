// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module coin::vm3_tests {
    use coin::vm3::{Self, VM3, VM3Coin};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    #[test]
    fun mint_and_burn() {
        // Initialize a mock sender address
        let addr1 = @0xA;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario = test_scenario::begin(addr1);
        
        // Run the vm3 coin module init function
        {
            vm3::test_init(ctx(&mut scenario));
        };

        // Mint a `Coin<VM3>` object
        next_tx(&mut scenario, addr1);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<VM3>>(&scenario);
            let vm3_coin = test_scenario::take_shared<VM3Coin>(&scenario);
            vm3::mint(&mut treasurycap, &mut vm3_coin, 100, addr1, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared<VM3Coin>(vm3_coin);
            test_scenario::return_to_address<TreasuryCap<VM3>>(addr1, treasurycap);
        };

        // Burn a `Coin<VM3>` object
        next_tx(&mut scenario, addr1);
        {
            let coin = test_scenario::take_from_sender<Coin<VM3>>(&scenario);
            let vm3_coin = test_scenario::take_shared<VM3Coin>(&scenario);

            assert!(coin::value(&coin) == 100, 0);
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<VM3>>(&scenario);
            vm3::burn(&mut treasurycap, &mut vm3_coin, coin);

            test_scenario::return_shared<VM3Coin>(vm3_coin);
            test_scenario::return_to_address<TreasuryCap<VM3>>(addr1, treasurycap);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}
