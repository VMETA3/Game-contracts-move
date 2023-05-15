// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module vmeta3_nfts::land_tests {
    use vmeta3_nfts::land::{Self, Land, LandCap};
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
            let landCap = test_scenario::take_from_sender<LandCap>(test);
            let conditions = 100;
            let token_uri = b"http://example.com/land/1";
            land::mint(&landCap, user1, conditions, token_uri, ctx(test));
            test_scenario::return_to_sender<LandCap>(test, landCap);
        };
        
        next_tx(test, user1);
        {
            let land = test_scenario::take_from_sender<Land>(test);
            let status = land::get_land_status(&land);
            assert!(status == false, 0);
            let active = 100;

            let landCap = test_scenario::take_from_address<LandCap>(test, admin);
            land::inject_active(&landCap, &mut land, active, ctx(test));
            let status = land::get_land_status(&land);
            assert!(status == true, 0);
            test_scenario::return_to_address<LandCap>(admin, landCap);
            test_scenario::return_to_sender<Land>(test, land);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}
