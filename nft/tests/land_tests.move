// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module nft::land_tests {
    use nft::land::{Self, Land, OwnerCap, InjectCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    #[test]
    fun integration_test() {
        let admin = @0xA;
        let user1 = @0xA1;

        let scenario = test_scenario::begin(admin);
        let test = &mut scenario;

        {
            land::test_init(ctx(test));
        };

        // Mint a `Land` object
        next_tx(test, admin);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(test);
            let conditions = 100;
            let token_uri = b"http://example.com/land/1";
            land::mint(&owner_cap, user1, conditions, token_uri, ctx(test));

            test_scenario::return_to_sender<OwnerCap>(test, owner_cap);
        };

        // Create a `InjectCap` to user1
        next_tx(test, admin);
        {

            let land = test_scenario::take_from_address<Land>(test, user1);
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(test);

            let active = 100;
            land::create_inject_capability(&owner_cap, &land, active, user1, user1, ctx(test));

            test_scenario::return_to_address<Land>(user1, land);
            test_scenario::return_to_sender<OwnerCap>(test, owner_cap);
        };
        
        next_tx(test, user1);
        {
            let land = test_scenario::take_from_sender<Land>(test);
            let inject_cap = test_scenario::take_from_sender<InjectCap>(test);

            let status = land::get_land_status(&land);
            assert!(status == false, 0);

            land::inject_active(inject_cap, &mut land);
            let status = land::get_land_status(&land);
            assert!(status == true, 0);

            test_scenario::return_to_sender<Land>(test, land);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}
