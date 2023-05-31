// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::raffle_bag{
    use std::vector;
    use sui::event;
    use sui::tx_context::{Self, TxContext};    
    use sui::clock::Clock;
    use sui::transfer;
    use sui::object::{Self, UID};
    use demo::util;

    struct RaffleBag has key{
        id: UID,
        prize_pool: vector<Prize>,
     }


    struct Prize has store, copy, drop{
        prize_kind: u8,
        amount: u64,
        weight: u64,
        tokens: vector<u64>,
    }

    struct RequestSentEvent has copy, drop {
        request_id: u64,
        num_words: u64,
    }

    struct RequestFulfilledEvent has copy, drop {
        request_id: u64,
        random_words: vector<u64>,
    }

    struct DrawEvent has copy, drop {
        to: address,
        prize_kind: u8,
        value: u64,
        request_id: u64,
    }

    fun init(ctx: &mut TxContext){
        let raffle_bag = RaffleBag{
            id: object::new(ctx),
            prize_pool: vector::empty(),
        };

        let tokens = vector::empty();
        vector::push_back(&mut tokens, 1);
        vector::push_back(&mut tokens, 2);

        vector::push_back(&mut raffle_bag.prize_pool, Prize{
            prize_kind: 1,
            amount: 100,
            weight: 1,
            tokens,
        });
        vector::push_back(&mut raffle_bag.prize_pool, Prize{
            prize_kind: 2,
            amount: 200,
            weight: 2,
            tokens,
        });
        vector::push_back(&mut raffle_bag.prize_pool, Prize{
            prize_kind: 3,
            amount: 300,
            weight: 3,
            tokens,
        });

        transfer::share_object(raffle_bag);
    }

    public entry fun draw(nonce: u64, clock: &Clock, ctx: &mut TxContext) {
        draw_(tx_context::sender(ctx), nonce, clock,  ctx);
    }

    public entry fun draw_to(to: address, nonce: u64, clock: &Clock, ctx: &mut TxContext) {
        draw_(to, nonce, clock, ctx);
    }

    fun draw_(_to: address, nonce: u64, clock: &Clock, ctx: &mut TxContext) {
        let num = util::random_n2(nonce, clock, ctx);

        let vec = vector::empty();
        vector::push_back(&mut vec, num);

        event::emit(RequestFulfilledEvent {
            request_id: nonce,
            random_words: vec,
        });
    }

    public entry fun clean_prize_pool(r: &mut RaffleBag){
        r.prize_pool = vector::empty();
    }

}