// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::vip{
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use std::vector;
    use sui::address;

    struct LatestList {
        addr: address,
        level: u8,
    }

    struct Level {
        level: u8,
        threshold: u64,
        numberLimit: u64,
        currentNumber: u64,
    }

    struct DepositEvent has copy, drop {
        account: address,
        amount: u64,
    }

    
    public entry fun deposit(amount: u64, ctx: &mut TxContext) {
        deposit_(tx_context::sender(ctx), amount);
    }

    public entry fun deposit_to(to: address, amount: u64) {
        deposit_(to, amount);
    }

    fun deposit_(to: address, amount: u64) {
        event::emit(DepositEvent {
            account: to,
            amount: amount,
        });
    }

    public fun get_latest_list(): vector<LatestList> {
        let list = vector::empty();
        
        vector::push_back(&mut list, LatestList{
            addr: address::from_u256(111),
            level: 1,
        });
        vector::push_back(&mut list, LatestList{
            addr: address::from_u256(222),
            level: 2,
        });
        vector::push_back(&mut list, LatestList{
            addr: address::from_u256(333),
            level: 3,
        });

        list
    }

    public fun get_level(_target: address):u8{
        1
    }

    public fun get_level_array(): vector<Level> {
        let list = vector::empty();
        
        vector::push_back(&mut list, Level{
            level: 1,
            threshold: 100,
            numberLimit: 10,
            currentNumber: 1,
        });
        vector::push_back(&mut list, Level{
            level: 2,
            threshold: 200,
            numberLimit: 20,
            currentNumber: 2,
        });
        vector::push_back(&mut list, Level{
            level: 3,
            threshold: 300,
            numberLimit: 30,
            currentNumber: 3,
        });

        list
    }
}