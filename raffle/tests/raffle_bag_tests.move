#[test_only]
module raffle::raffle_bag_test {
    use sui::test_scenario::{Self as ts, Scenario, ctx, next_tx};
    use sui::sui::SUI;
    use sui::object::{Self, UID};
    use sui::clock::{Self};
    use std::vector;
    use raffle::raffle_bag::{Self, RaffleBag, OwnerCapability};

    const OWNER: address = @0xA1C05;
    const MINTER: address = @0xA1C20;
    const USER: address = @0xA1C21;
    const ACardID: address = @0xA;

    const OneMonth: u64 = 30 * 24 * 60 * 60 * 1000;
    const Ten: u64 = 1000000000;

    /// Prize kind
    const ACard: u8 = 1;
    const BCard: u8 = 2;
    const CCard: u8 = 3;
    const DCard: u8 = 4;
    const VM3Coin: u8 = 5;

    struct NFT has key, store {
        id: UID,
        prize_kind: u8,
    }

    fun prepare(): Scenario {
        let scenario = ts::begin(OWNER);
        {
            raffle_bag::create_empty<SUI>(b"test raffle", ctx(&mut scenario));
            clock::share_for_testing(clock::create_for_testing(ctx(&mut scenario)));
        };

        next_tx(&mut scenario, OWNER);
        {
            set_prize_kinds(&mut scenario);
        };

        next_tx(&mut scenario, OWNER);
        {
            deposit_prize_nft(&mut scenario);
        };

        scenario
    }

    fun set_prize_kinds(scenario: &mut Scenario) {
        let raffle_bag = ts::take_shared<RaffleBag<SUI>>(scenario);
        let capability = ts::take_from_sender<OwnerCapability<SUI>>(scenario);

        let kinds = vector::empty();
        vector::push_back(&mut kinds, ACard);
        vector::push_back(&mut kinds, BCard);
        vector::push_back(&mut kinds, CCard);
        vector::push_back(&mut kinds, DCard);
        vector::push_back(&mut kinds, VM3Coin);

        let amounts = vector::empty();
        vector::push_back(&mut amounts, 0);
        vector::push_back(&mut amounts, 0);
        vector::push_back(&mut amounts, 0);
        vector::push_back(&mut amounts, 0);
        vector::push_back(&mut amounts, Ten);

        let weights = vector::empty();
        vector::push_back(&mut weights, 2);
        vector::push_back(&mut weights, 4);
        vector::push_back(&mut weights, 8);
        vector::push_back(&mut weights, 400);
        vector::push_back(&mut weights, 6000);

        let descriptions = vector::empty();
        vector::push_back(&mut descriptions, b"This is a A-grade card");
        vector::push_back(&mut descriptions, b"This is a B-grade card");
        vector::push_back(&mut descriptions, b"This is a C-grade card");
        vector::push_back(&mut descriptions, b"This is a D-grade card");
        vector::push_back(&mut descriptions, b"");

        raffle_bag::set_prizes<SUI, NFT>(&mut raffle_bag, &capability, kinds, amounts, weights, descriptions, ctx(scenario));

        ts::return_shared(raffle_bag);
        ts::return_to_sender(scenario, capability);
    }

    fun deposit_prize_nft(scenario: &mut Scenario) {
        let raffle_bag = ts::take_shared<RaffleBag<SUI>>(scenario);
        let capability = ts::take_from_sender<OwnerCapability<SUI>>(scenario);

        // deposit ACards, quantity is 1
        raffle_bag::deposit_prize_nft<SUI, NFT>(&mut raffle_bag, &capability, ACard, NFT{ id: object::new(ctx(scenario)), prize_kind: ACard });

        // deposit BCards, quantity is 1
        raffle_bag::deposit_prize_nft<SUI, NFT>(&mut raffle_bag, &capability, BCard, NFT{ id: object::new(ctx(scenario)), prize_kind: BCard });

        // deposit CCards, quantity is 1
        raffle_bag::deposit_prize_nft<SUI, NFT>(&mut raffle_bag, &capability, CCard, NFT{ id: object::new(ctx(scenario)), prize_kind: CCard });

        ts::return_shared(raffle_bag);
        ts::return_to_sender(scenario, capability);
    }

    #[test]
    public fun multiple_draw() {
        let scenario = prepare();

        // expect winning A card, and the number of prize on A card has been drawn out
        next_tx(&mut scenario, OWNER);
        {
            let raffle_bag = ts::take_shared<RaffleBag<SUI>>(&scenario);
            let capability = ts::take_from_sender<OwnerCapability<SUI>>(&scenario);

            let random = 0;
            raffle_bag::test_draw<SUI, NFT>(&mut raffle_bag, &capability, random, USER, ctx(&mut scenario));

            ts::return_shared(raffle_bag);
            ts::return_to_sender(&scenario, capability);
        };

        next_tx(&mut scenario, USER);
        {
            let raffle_bag = ts::take_shared<RaffleBag<SUI>>(&scenario);

            // winning A card
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(nft.prize_kind == ACard, 0);

            // A card prize has been cleared
            let is_contains = raffle_bag::test_is_contains_prize<SUI>(&mut raffle_bag, ACard);
            assert!(is_contains == false, 1);

            ts::return_to_sender(&scenario, nft);
            ts::return_shared(raffle_bag);

        };

        // expect winning C card, and the number of prize on C card has been drawn out
        next_tx(&mut scenario, OWNER);
        {
            let raffle_bag = ts::take_shared<RaffleBag<SUI>>(&scenario);
            let capability = ts::take_from_sender<OwnerCapability<SUI>>(&scenario);

            let random = 5;
            raffle_bag::test_draw<SUI, NFT>(&mut raffle_bag, &capability, random, USER, ctx(&mut scenario));

            ts::return_shared(raffle_bag);
            ts::return_to_sender(&scenario, capability);
        };

        next_tx(&mut scenario, USER);
        {
            let raffle_bag = ts::take_shared<RaffleBag<SUI>>(&scenario);

            // winning C card
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(nft.prize_kind == CCard, 0);

            // C card prize has been cleared
            let is_contains = raffle_bag::test_is_contains_prize<SUI>(&mut raffle_bag, CCard);
            assert!(is_contains == false, 1);

            ts::return_to_sender(&scenario, nft);
            ts::return_shared(raffle_bag);

        };
        ts::end(scenario);
    }
}
