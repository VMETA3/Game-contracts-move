// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::util {
    use sui::clock::{Self, Clock};
    use sui::tx_context::{Self, TxContext};
    use std::hash;
    use std::vector;

    // reuturn a random number interval [0,n)
    public fun random_n(n: u64,myclock: &Clock): u64 {
       let timestamp =  clock::timestamp_ms(myclock);
       let v = bytes2u64(hash::sha3_256(u642bytes(timestamp)));
    
       return (v%n)
    }

    public fun random_n2(n: u64, myclock: &Clock, ctx: &TxContext): u64 {
        let seed = vector::empty<u8>();
        vector::append(&mut seed, get_current_timestamp_hash(myclock));
        vector::append(&mut seed, *tx_context::digest(ctx));
        vector::append(&mut seed, u642bytes(tx_context::epoch(ctx)));

        let v = bytes2u64(hash::sha3_256(seed));
        return (v%n)
    }

    public fun bytes2u64(data:vector<u8>): u64 {
        let result:u64 = 0;
        let l = vector::length(&data);
        let i = 0;
        while (i < l) {
            let b = vector::borrow(&data, i);
            result = (result << 8) | (*b as u64);
            i=i+1;
        };

        return (result)
    }

    public fun get_current_timestamp_hash(myclock: &Clock): vector<u8>{
        let timestamp =  clock::timestamp_ms(myclock);
        let n = hash::sha3_256(u642bytes(timestamp));

        return (n)
    }

    public fun u642bytes(n:u64): vector<u8> {
        let data = vector::empty<u8>();
        while(true){
            vector::push_back(&mut data, (n%8 as u8));
            n = n / 8;
            if (n==0) {
                break
            };
        };

        vector::reverse(&mut data);
        return (data)
    }
}