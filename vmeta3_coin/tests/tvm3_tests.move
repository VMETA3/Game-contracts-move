// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module vmeta3_coin::tvm3_tests {
    use vmeta3_coin::tvm3::{Self, TVM3};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    #[test]
    fun mint_and_burn() {
        // Initialize a mock sender address
        let addr1 = @0xA;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario = test_scenario::begin(addr1);
        
        // Run the tvm3 coin module init function
        {
            tvm3::test_init(ctx(&mut scenario));
        };

        // Mint a `Coin<TVM3>` object
        next_tx(&mut scenario, addr1);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<TVM3>>(&scenario);
            tvm3::mint(&mut treasurycap, 100, addr1, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_address<TreasuryCap<TVM3>>(addr1, treasurycap);
        };

        // Burn a `Coin<TVM3>` object
        next_tx(&mut scenario, addr1);
        {
            let coin = test_scenario::take_from_sender<Coin<TVM3>>(&scenario);
            assert!(coin::value(&coin) == 100, 0);
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<TVM3>>(&scenario);
            tvm3::burn(&mut treasurycap, coin);
            test_scenario::return_to_address<TreasuryCap<TVM3>>(addr1, treasurycap);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}
