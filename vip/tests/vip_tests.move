#[test_only]
module vip::vip_test {
    use sui::test_scenario::{Self as ts, Scenario, ctx, next_tx};
    use sui::sui::SUI;
    use sui::coin;
    use sui::clock::{Self, Clock};
    use std::vector;
    use vip::vip::{Self, Vip, OwnerCapability, EUpgradeThresholdNotReached, EExceedVipNumberLimit};

    const OWNER: address = @0xA1C05;
    const MINTER: address = @0xA1C20;
    const USER: address = @0xA1C21;

    const OneMonth: u64 = 30 * 24 * 60 * 60 * 1000;

    const OneHundred: u64 = 100000000000;
    const OneThousand: u64 = 1000000000000;
    const TenThousand: u64 = 10000000000000;

    fun prepare(): Scenario {
        let scenario = ts::begin(OWNER);
        {
            vip::create_empty<SUI>(ctx(&mut scenario));
            clock::share_for_testing(clock::create_for_testing(ctx(&mut scenario)));
        };

        next_tx(&mut scenario, OWNER);
        {
            set_activity_time(&mut scenario);
        };

        next_tx(&mut scenario, OWNER);
        {
            set_default_level_rules(&mut scenario);
        };

        scenario
    }

    fun set_activity_time(scenario: &mut Scenario) {
        let vip = ts::take_shared<Vip<SUI>>(scenario);
        let capability = ts::take_from_sender<OwnerCapability<SUI>>(scenario);

        vip::set_activity_start_time(&mut vip, &capability, 0);
        vip::set_activity_end_time(&mut vip, &capability, OneMonth);

        ts::return_shared(vip);
        ts::return_to_sender(scenario, capability);
    }

    fun set_default_level_rules(scenario: &mut Scenario) {
        let vip = ts::take_shared<Vip<SUI>>(scenario);
        let capability = ts::take_from_sender<OwnerCapability<SUI>>(scenario);

        let levels = vector::empty();
        vector::push_back(&mut levels, 1);
        vector::push_back(&mut levels, 2);
        vector::push_back(&mut levels, 3);

        let thresholds = vector::empty();
        vector::push_back(&mut thresholds, OneHundred);
        vector::push_back(&mut thresholds, OneThousand);
        vector::push_back(&mut thresholds, TenThousand);

        let number_limits = vector::empty();
        vector::push_back(&mut number_limits, 2000);
        vector::push_back(&mut number_limits, 700);
        vector::push_back(&mut number_limits, 150);

        let current_numbers = vector::empty();
        vector::push_back(&mut current_numbers, 0);
        vector::push_back(&mut current_numbers, 0);
        vector::push_back(&mut current_numbers, 0);

        vip::set_level_rules(&mut vip, &capability, levels, thresholds, number_limits, current_numbers);

        ts::return_shared(vip);
        ts::return_to_sender(scenario, capability);
    }

    fun set_level_rules_already_full(scenario: &mut Scenario) {
        let vip = ts::take_shared<Vip<SUI>>(scenario);
        let capability = ts::take_from_sender<OwnerCapability<SUI>>(scenario);

        vip::clean_all_level_rule(&mut vip, &capability);

        let levels = vector::empty();
        vector::push_back(&mut levels, 1);
        vector::push_back(&mut levels, 2);
        vector::push_back(&mut levels, 3);

        let thresholds = vector::empty();
        vector::push_back(&mut thresholds, OneHundred);
        vector::push_back(&mut thresholds, OneThousand);
        vector::push_back(&mut thresholds, TenThousand);

        let number_limits = vector::empty();
        vector::push_back(&mut number_limits, 2000);
        vector::push_back(&mut number_limits, 700);
        vector::push_back(&mut number_limits, 150);

        let current_numbers = vector::empty();
        vector::push_back(&mut current_numbers, 2000);
        vector::push_back(&mut current_numbers, 700);
        vector::push_back(&mut current_numbers, 150);

        vip::set_level_rules(&mut vip, &capability, levels, thresholds, number_limits, current_numbers);

        ts::return_shared(vip);
        ts::return_to_sender(scenario, capability);
    }

    #[test]
    public fun multiple_invest_within_30_days() {
        let scenario = prepare();

        next_tx(&mut scenario, USER);
        {
            let vip = ts::take_shared<Vip<SUI>>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            // deposit one hundred, expect level 1
            let coin = coin::mint_for_testing<SUI>(OneHundred, ctx(&mut scenario));
            vip::deposit(&mut vip, &clock, coin, ctx(&mut scenario));

            let level = vip::get_level(&vip, USER);
            assert!(level == 1, 0);

            // deposit one thousand, expect level 2
            let coin = coin::mint_for_testing<SUI>(OneThousand, ctx(&mut scenario));
            vip::deposit(&mut vip, &clock, coin, ctx(&mut scenario));

            let level = vip::get_level(&vip, USER);
            assert!(level == 2, 0);

            // deposit ten thousand, expect level 3
            let coin = coin::mint_for_testing<SUI>(TenThousand, ctx(&mut scenario));
            vip::deposit(&mut vip, &clock, coin, ctx(&mut scenario));

            let level = vip::get_level(&vip, USER);
            assert!(level == 3, 0);

            ts::return_shared(vip);
            ts::return_shared(clock);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EUpgradeThresholdNotReached)]
    public fun not_reached_threshold() {
        let scenario = prepare();

        next_tx(&mut scenario, USER);
        {
            let vip = ts::take_shared<Vip<SUI>>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            // deposit one hundred, expect level 1
            let coin = coin::mint_for_testing<SUI>(OneHundred, ctx(&mut scenario));
            vip::deposit(&mut vip, &clock, coin, ctx(&mut scenario));

            let level = vip::get_level(&vip, USER);
            assert!(level == 1, 0);

            // expect failure
            let coin = coin::mint_for_testing<SUI>(1, ctx(&mut scenario));
            vip::deposit(&mut vip, &clock, coin, ctx(&mut scenario));

            ts::return_shared(vip);
            ts::return_shared(clock);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EExceedVipNumberLimit)]
    public fun exceed_vip_number_limit() {
        let scenario = prepare();
        next_tx(&mut scenario, OWNER);
        {
            set_level_rules_already_full(&mut scenario);
        };

        next_tx(&mut scenario, USER);
        {
            let vip = ts::take_shared<Vip<SUI>>(&scenario);
            let clock = ts::take_shared<Clock>((&scenario));

            // deposit one hundred, expect failure
            let coin = coin::mint_for_testing<SUI>(OneHundred, ctx(&mut scenario));
            vip::deposit(&mut vip, &clock, coin, ctx(&mut scenario));

            ts::return_shared(vip);
            ts::return_shared(clock);
        };
        ts::end(scenario);
    }

}
