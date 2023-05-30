// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::raffle_bag{
    use std::vector;
    use sui::event;
    use sui::tx_context::{Self, TxContext};    
    use sui::clock::{Self, Clock};
    use std::hash;


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

    public entry fun draw(nonce: u64, clock: &Clock, ctx: &mut TxContext) {
        draw_(tx_context::sender(ctx), nonce, clock);
    }

    public entry fun draw_to(to: address, nonce: u64, clock: &Clock) {
        draw_(to, nonce, clock);
    }

    fun draw_(_to: address, nonce: u64, clock: &Clock) {
        let num = random_number(clock);

        let vec = vector::empty();
        vector::push_back(&mut vec, num);

        event::emit(RequestFulfilledEvent {
            request_id: nonce,
            random_words: vec,
        });
    }

    public entry fun clean_prize_pool(){
        
    }

    public entry fun random_number(clock: &Clock): u64 {
        let timestamp = clock::timestamp_ms(clock);
        let n = bytes2u64(hash::sha3_256(u642bytes(timestamp)));
        event::emit(RequestSentEvent {
            request_id: timestamp,
            num_words: timestamp,
        });
        n
    }

    fun bytes2u64(data:vector<u8>): u64 {
        let result:u64 = 0;
        let l = vector::length(&data);
        let i = 0;
        while (i < l) {
            let b = vector::borrow(&data, i);
            result = (result << 8) | (*b as u64);
            i=i+1;
        };

        result
    }

    fun u642bytes(n:u64): vector<u8> {
        let data = vector::empty<u8>();
        while(true){
            vector::push_back(&mut data, (n%8 as u8));
            n = n / 8;
            if (n==0) {
                break
            };
        };

        vector::reverse(&mut data);
        data
    }

    public entry fun get_prize_pool(): vector<Prize> {
        vector::empty()
    }
}