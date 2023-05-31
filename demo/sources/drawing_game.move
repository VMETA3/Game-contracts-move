// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::drawing_game {
    use std::vector;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::vec_map::{Self, VecMap};
    use std::hash;
    use sui::event;
    use sui::clock::{Clock};
    use demo::util::{Self};

    struct DRAWING_GAME has drop {
        
    }

    struct InvestmentAccount has copy,drop {
        addr:address,
        level:u8,
    }

    struct BonusPool has key,store {
        id: UID,
        nfts:vector<u64>,
        old_lucky_number:VecSet<u64>,
        old_lucky_user:VecSet<address>,
    }


    struct OwnerCapability has key, store {
        id: UID,
    }

    //error code
    const EAlreadyInitialized: u64 = 1;

    //constant
    const ZeroAddress: address = @0x0;
    
    //events
    struct DrawEvent has drop, copy {
        winners: vector<address>,
        nfts: vector<u64>,
    }

    fun init(_witness:DRAWING_GAME, ctx: &mut TxContext){
        let cap = OwnerCapability {
            id: object::new(ctx)
        };

         let bonus_pool = BonusPool {
            id:object::new(ctx),
            nfts: vector::empty(),
            old_lucky_number: vec_set::empty(),
            old_lucky_user: vec_set::empty(),
        };

        transfer::share_object(bonus_pool);
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    public fun deposit(_:&OwnerCapability, bonus_pool:&mut BonusPool, nfts:vector<u64>) {
        vector::append(&mut bonus_pool.nfts, nfts);
    }


    public entry fun draw(_:&OwnerCapability,draw_total:u64, bonus_pool:&mut BonusPool, myclock: &Clock, ctx:&TxContext) {
        let (users, users_weight, users_total_weight) = getUsers();

        let winners = vector::empty<address>();
        let winner_nfts = vector::empty<u64>();

        let rand_number_bytes = util::get_current_timestamp_hash(myclock);
        vector::append(&mut rand_number_bytes, *tx_context::digest(ctx));
        rand_number_bytes = hash::sha3_256(rand_number_bytes);

        let i=0;
        while( i < draw_total && i < vector::length(&bonus_pool.nfts)){
            if (users_total_weight == 0) {
                break
            };

            let rand_number = util::bytes2u64(rand_number_bytes) % users_total_weight;
            let winner = who_win(rand_number, &mut users, &users_weight);
            vector::push_back(&mut winners, winner);
            vector::push_back(&mut winner_nfts, vector::pop_back(&mut bonus_pool.nfts));
            vec_set::insert(&mut bonus_pool.old_lucky_user, winner);
            vec_set::insert(&mut bonus_pool.old_lucky_number, rand_number);

            users_total_weight = users_total_weight - *vec_map::get(&users_weight, &winner);
            rand_number_bytes = hash::sha3_256(rand_number_bytes);

            i = i + 1;
        };

        event::emit(DrawEvent{
            winners: winners,
            nfts: winner_nfts,
       });
    }

    fun who_win(number:u64, users:&mut vector<InvestmentAccount>,users_weight:&VecMap<address,u64>) :address {
        let count:u64 = 0;
        let i = 0;
        while (i < vector::length(users)) {
            let user = vector::borrow(users,i);
            count = count + *vec_map::get(users_weight, &user.addr);
            if (count>=number) {
                let winner = user.addr;
                vector::remove(users, i);
                return (winner)
            };

            i = i + 1;
        };

        return (ZeroAddress)
    }

    fun calculteWeight(level:u8) :u64 {
        if (level == 3) {
            return (15)
        };

        if (level == 2) {
            return (5)
        };

        return (1)
    }

    fun getUsers(): (vector<InvestmentAccount>, VecMap<address,u64>, u64) {
        let users =  vector::empty<InvestmentAccount>();
        let users_weight = vec_map::empty<address,u64>();

        vector::push_back(&mut users, InvestmentAccount{
            addr: @0x30,
            level: 1,
        });
        vector::push_back(&mut users, InvestmentAccount{
            addr: @0x31,
            level: 2,
        });
        vector::push_back(&mut users, InvestmentAccount{
            addr: @0x32,
            level: 3,
        });

        vec_map::insert(&mut users_weight, @0x30, calculteWeight(1));
        vec_map::insert(&mut users_weight, @0x31, calculteWeight(2));
        vec_map::insert(&mut users_weight, @0x32, calculteWeight(3));
        let total_weight = calculteWeight(1) + calculteWeight(2) + calculteWeight(3);

        return (users, users_weight, total_weight)
    }
}