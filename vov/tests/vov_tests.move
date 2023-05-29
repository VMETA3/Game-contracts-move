// SPDX-License-Identifier: Apache-2.0

module vov::vov_tests {
    use vov::vov::{Self};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};



    fun delayed_mint_test() {

    }

   
    fun prepare(admin: address):  Scenario {
        let scenario = test_scenario::begin(admin);
        {
            vov::test_init(ctx(&mut scenario));
        };

        return (scenario)
    }
}