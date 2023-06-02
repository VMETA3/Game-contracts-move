// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module raffle::raffle_bag {
    use std::vector;
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Self, Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::dynamic_object_field as dof;
    use sui::clock::Clock;
    use sui::event;
    use raffle::util;

    /// The hardcoded ID for the singleton Clock Object.
    const SUI_CLOCK_OBJECT_ID: address = @0x6;

    /// Prize kind
    const ACard: u8 = 1;
    const BCard: u8 = 2;
    const CCard: u8 = 3;
    const DCard: u8 = 4;
    const VM3Coin: u8 = 5;

    struct Prize<phantom T: key + store> has key, store {
        id: UID,
        kind: u8,
        amount: u64,
        weight: u64,
        nft_ids: vector<ID>,
        description: string::String,
    }

    struct RaffleBag<phantom T> has key{
        id: UID,
        name: vector<u8>,
        prize_pool: ObjectBag,
        balance: Balance<T>,
        random_nonce: u64
    }

    /// Owner capability
    struct OwnerCapability<phantom T> has key, store {
        id: UID,
        raffle_bag_id: ID,
    }

    /// Event
    struct DrawVM3CoinEvent has copy, drop {
        to: address,
        value: u64,
    }
    
    struct DrawCardEvent has copy, drop {
        to: address,
        prize_kind: u8,
        nft_id: ID,
    }

    /// Error
    const EInvalidOwnerCapability: u64 = 0;
    const EInconsistentDataLength: u64 = 1;
    const EInvalidRandomNumber: u64 = 2;
    const EInvalidPrizeKind: u64 = 3;
    const EPrizeKindAlreadyExists: u64 = 4;
    const EPrizeKindNotEmpty: u64 = 5;

    //////////////////////////////////////////////////////
    /// HELPER FUNCTIONS
    //////////////////////////////////////////////////////

    fun create_<T>(balance: Balance<T>, name: vector<u8>, ctx: &mut TxContext): OwnerCapability<T> {
        let raffle_bag = RaffleBag<T> {
            id: object::new(ctx),
            name,
            prize_pool: object_bag::new(ctx),
            balance,
            random_nonce: 0,
        };

        let owner_cap = OwnerCapability {
            id: object::new(ctx),
            raffle_bag_id: object::id(&raffle_bag),
        };
        transfer::share_object(raffle_bag);
        owner_cap
    }

    fun check_owner_capability_validity<T>(raffle_bag: &RaffleBag<T>, capability: &OwnerCapability<T>) {
        assert!(object::id(raffle_bag) == capability.raffle_bag_id, EInvalidOwnerCapability);
    }

    fun set_prize_kind_<T: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        kind: u8, 
        amount: u64, 
        weight: u64, 
        description: vector<u8>, 
        ctx: &mut TxContext
    ) {
        if (kind != ACard && kind != BCard && kind != CCard && kind != DCard && kind != VM3Coin) {
            assert!(false, EInvalidPrizeKind);
        };

        let prize = Prize<T> {
            id: object::new(ctx),
            kind,
            amount,
            weight,
            nft_ids: vector::empty(),
            description: string::utf8(description),
        };

        if (object_bag::contains(&mut raffle_bag.prize_pool, kind)){
            assert!(false, EPrizeKindAlreadyExists);
        };
        object_bag::add(&mut raffle_bag.prize_pool, kind, prize);
    }

    // Destroy Prize object after transferring all NFTs
    fun handle_clean<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>,
        kind: u8,
        ctx: &mut TxContext
    ) {
        let prize: &Prize<U> = object_bag::borrow(&raffle_bag.prize_pool, kind);
        let length = vector::length(&prize.nft_ids);

        // transfer nfts 
        let  i = 0;
        while (i < length) {
            let nft = redeem_prize_nft<T,U>(raffle_bag, kind);
            transfer::public_transfer(nft, sender(ctx));
            i = i + 1;
        };

        // destroy Prize
        clean_empty_prize<T,U>(raffle_bag, kind);
    }

    fun handle_weight<T: key + store>(
        total_weight: u64, 
        weights: &mut vector<u64>, 
        prize_pool: &ObjectBag, 
        kind: u8
    ): (u64, &mut vector<u64>) {
        let prize: &Prize<T> = object_bag::borrow(prize_pool, kind);
        total_weight = total_weight + prize.weight;
        vector::push_back(weights, prize.weight);
        (total_weight, weights)
    }

    // Calculate the total weight of the prize pool
    fun total_weight<T: key + store>(prize_pool: &ObjectBag): (u64, vector<u64>) {
        let total_weight = 0;
        let weights = vector::empty();
        if (object_bag::contains(prize_pool, ACard)) {
            handle_weight<T>(total_weight, &mut weights, prize_pool, ACard);
        };
        if (object_bag::contains(prize_pool, BCard)) {
            handle_weight<T>(total_weight, &mut weights, prize_pool, BCard);
        };
        if (object_bag::contains(prize_pool, CCard)) {
            handle_weight<T>(total_weight, &mut weights, prize_pool, CCard);
        };
        if (object_bag::contains(prize_pool, DCard)) {
            handle_weight<T>(total_weight, &mut weights, prize_pool, DCard);
        };
        if (object_bag::contains(prize_pool, VM3Coin)) {
            handle_weight<T>(total_weight, &mut weights, prize_pool, VM3Coin);
        };
        (total_weight, weights)
    }

    // Active gift package rule
    fun active_rule<T: key + store>(
        random_number: u64, 
        prize_pool: &ObjectBag
    ): u64 {
        let (total_weight, weights) = total_weight<T>(prize_pool);

        let number = object_bag::length(prize_pool) + 1;

        let num = random_number % total_weight;

        let minimum = 0;
        let i = 0;
        while (!vector::is_empty(&weights)) {
            if (i != 0) {
                minimum = minimum + vector::pop_back(&mut weights);
            };
            if (num >= minimum && num < vector::pop_back(&mut weights) + minimum) {
                number = i;
            };
            i = i + 1;
        };
        assert!(number < object_bag::length(prize_pool), EInvalidRandomNumber);
        number
    }

    fun transfer_balance<T>(
        raffle_bag: &mut RaffleBag<T>, 
        to: address, 
        value: u64,
        ctx: &mut TxContext
    ) {
        let balance = balance::split(&mut raffle_bag.balance, value);
        let coin = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin, to);
    }

    fun random<T>(
        raffle_bag: &mut RaffleBag<T>, 
        clock: &Clock, 
        ctx: &mut TxContext
    ): u64 {
        raffle_bag.random_nonce = raffle_bag.random_nonce + 1;
        util::random_n2(raffle_bag.random_nonce, clock, ctx)
    }

    fun draw_<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        to: address, 
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        let random_num = random(raffle_bag, clock, ctx);
        let number = active_rule<U>(random_num, &raffle_bag.prize_pool);

        let prize: &mut Prize<U> = object_bag::borrow_mut(&mut raffle_bag.prize_pool, number);
        let kind = prize.kind;

        if (kind == VM3Coin){
            transfer_balance<T>(raffle_bag, to, prize.amount, ctx);
        }else if (kind == DCard){
            event::emit(DrawCardEvent{
                to,
                prize_kind: kind,
                nft_id: object::id_from_bytes(b"0xVM3"),
            });
        }else{
            let nft = redeem_prize_nft<T,U>(raffle_bag, kind);
            let nft_id = object::id(&nft);

            transfer::public_transfer(nft, to);
            clean_empty_prize<T,U>(raffle_bag, kind);
            
            event::emit(DrawCardEvent{
                to,
                prize_kind: kind,
                nft_id,
            });
        }
    }

    //////////////////////////////////////////////////////
    /// PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////

    public entry fun create<T>(coin: Coin<T>, name: vector<u8>, ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        let cap = create_<T>(balance, name, ctx);
        transfer::public_transfer(cap, sender(ctx));
    }

    public entry fun create_empty<T>(name: vector<u8>, ctx: &mut TxContext) {
        let empty_balance = balance::zero<T>();
        let cap = create_(empty_balance, name, ctx);
        transfer::public_transfer(cap, sender(ctx));
    }

    public entry fun set_prize_kind<T: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        capability: &OwnerCapability<T>, 
        kind: u8, 
        amount: u64, 
        weight: u64, 
        description: vector<u8>, 
        ctx: &mut TxContext
    ) {
        check_owner_capability_validity(raffle_bag, capability);
        set_prize_kind_(raffle_bag, kind, amount, weight, description, ctx);
    }

    public entry fun set_prize_kinds<T: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        capability: &OwnerCapability<T>, 
        kind: vector<u8>, 
        amounts: vector<u64>, 
        weights: vector<u64>, 
        description: vector<vector<u8>>, 
        ctx: &mut TxContext
    ) {
        check_owner_capability_validity(raffle_bag, capability);

        let len = vector::length(&amounts);
        assert!(vector::length(&amounts) == vector::length(&weights), EInconsistentDataLength);

        let i = 0;
        while (i < len) {
            let kind = *vector::borrow(&kind, i);
            let amount = *vector::borrow(&amounts, i);
            let weight = *vector::borrow(&weights, i);
            let description = *vector::borrow(&description, i);
            set_prize_kind_(raffle_bag, kind, amount, weight, description, ctx);
            i=i+1;
        }
    }

    public entry fun deposit_prize_nft<T: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        capability: &OwnerCapability<T>,
        kind: u8,
        nft: T,
    ) {
        check_owner_capability_validity(raffle_bag, capability);

        let nft_id = object::id(&nft);
        let prize: &mut Prize<T> = object_bag::borrow_mut(&mut raffle_bag.prize_pool, kind);

        vector::push_back(&mut prize.nft_ids, nft_id);
        dof::add(&mut prize.id, nft_id, nft);
    }

    public fun redeem_prize_nft<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        kind: u8,
    ): U {
        let prize: &mut Prize<U> = object_bag::borrow_mut(&mut raffle_bag.prize_pool, kind);
        let nft_id = vector::pop_back(&mut prize.nft_ids);
        dof::remove(&mut prize.id, nft_id)
    }

    public entry fun draw<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        capability: &OwnerCapability<T>, 
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        check_owner_capability_validity(raffle_bag, capability);
        draw_<T,U>(raffle_bag, sender(ctx), clock, ctx);
    }

    public entry fun draw_to<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        capability: &OwnerCapability<T>, 
        to: address, 
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        check_owner_capability_validity(raffle_bag, capability);
        draw_<T,U>(raffle_bag, to, clock, ctx);
    }

    public entry fun clean_empty_prize<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        kind: u8,
    ) {
        let prize: &Prize<U> = object_bag::borrow(&raffle_bag.prize_pool, kind);
        assert!(vector::is_empty(&prize.nft_ids), EPrizeKindNotEmpty);

        let Prize<U>{id, kind:_, amount:_, description:_, nft_ids:_, weight:_}  = object_bag::remove(&mut raffle_bag.prize_pool, kind);
        object::delete(id);
    }

    public entry fun clean_prize_pool<T, U: key + store>(
        raffle_bag: &mut RaffleBag<T>, 
        capability: &OwnerCapability<T>, 
        ctx: &mut TxContext
    ) {
        check_owner_capability_validity(raffle_bag, capability);

        if (object_bag::contains(&raffle_bag.prize_pool, ACard)) {
            handle_clean<T, U>(raffle_bag, ACard, ctx);
            clean_empty_prize<T, U>(raffle_bag, ACard);
        };
        if (object_bag::contains(&raffle_bag.prize_pool, BCard)) {
            handle_clean<T, U>(raffle_bag, BCard, ctx);
            clean_empty_prize<T, U>(raffle_bag, BCard);
        };
        if (object_bag::contains(&raffle_bag.prize_pool, CCard)) {
            handle_clean<T, U>(raffle_bag, CCard, ctx);
            clean_empty_prize<T, U>(raffle_bag, CCard);
        };
        if (object_bag::contains(&raffle_bag.prize_pool, DCard)) {
            clean_empty_prize<T,U>(raffle_bag, DCard);
        };
        if (object_bag::contains(&raffle_bag.prize_pool, VM3Coin)) {
            clean_empty_prize<T,U>(raffle_bag, VM3Coin);
        };
    }
}