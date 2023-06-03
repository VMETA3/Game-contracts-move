// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module drawing_game::drawing_game {
    use std::vector;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::ecvrf;
    use sui::vec_map::{Self, VecMap};
    use std::hash;
    use sui::event;

    struct DRAWING_GAME has drop {
    
    }

    struct InvestmentAccount has copy,drop {
        addr:address,
        level:u8,
    }

    struct BonusPool<T: key+store> has key,store {
        id: UID,
        nfts:vector<T>,
        old_lucky_number:VecSet<u128>,
        old_lucky_user:VecSet<address>,
    }

    struct InitLock has key {
        id: UID,
        has_init:bool,
    }

    struct OwnerCapability has key, store {
        id: UID,
    }

    //error code
    const EAlreadyInitialized: u64 = 1;

    //constant
    const ZeroAddress: address = @0x0;
    
    //events
    struct DrawEvent<T: drop+copy> has drop, copy {
        winner: address,
        nft: T,
    }

    fun init(_witness:DRAWING_GAME, ctx: &mut TxContext){
        let cap = OwnerCapability {
            id: object::new(ctx)
        };

        let init_lock = InitLock {
            id:object::new(ctx),
            has_init: false,
        };

        transfer::transfer(cap, tx_context::sender(ctx));
        transfer::share_object(init_lock);
    }

    public fun initialize<T: key+store>(ctx: &mut TxContext, init_lock:&mut InitLock) {
        assert!(init_lock.has_init==false, EAlreadyInitialized);
        
        let bonus_pool = BonusPool {
            id:object::new(ctx),
            nfts: vector::empty<T>(),
            old_lucky_number: vec_set::empty(),
            old_lucky_user: vec_set::empty(),
        };
        transfer::share_object(bonus_pool);
        init_lock.has_init = true;
    }

    public fun deposit<T: key+store>(_:&OwnerCapability, bonus_pool:&mut BonusPool<T>, nfts:vector<T>) {
        vector::append(&mut bonus_pool.nfts, nfts);
    }

    
    public entry fun draw<T: key+store>(_:&OwnerCapability, bonus_pool:&mut BonusPool<T>, draw_total:u64,rand_number_bytes: vector<u8>, alpha_string: vector<u8>, public_key: vector<u8>, proof: vector<u8>) {
        assert!(ecvrf::ecvrf_verify(&rand_number_bytes, &alpha_string, &public_key, &proof), 0);
        assert!(draw_total > 0 && draw_total  <= vector::length(&bonus_pool.nfts), 0);

        let (users, users_weight, users_total_weight) = getUsers();
        let winners = vector::empty<address>();

        let i=0;
        while( i < draw_total && i < vector::length(&bonus_pool.nfts)){
            if (users_total_weight == 0) {
                break
            };

            let rand_number = bytes2u128(rand_number_bytes);
            let winner = who_win(rand_number, &mut users, &users_weight);
            vector::push_back(&mut winners, winner);
            users_total_weight = users_total_weight - *vec_map::get(&users_weight, &winner);
            rand_number_bytes = hash::sha3_256(rand_number_bytes);

            
            i = i + 1;
        };

        draw_<T>(bonus_pool, &mut winners);
    }

    fun draw_<T: key+store> (bonus_pool:&mut BonusPool<T>,lucky_users:&mut vector<address>){
        while (!vector::is_empty(lucky_users) && !vector::is_empty(&mut bonus_pool.nfts)) {
            let luck_user = vector::pop_back(lucky_users);
            let nft_ = vector::pop_back(&mut bonus_pool.nfts);
            transfer::public_transfer(nft_, luck_user);
        }
    }

    fun who_win(number:u128, users:&mut vector<InvestmentAccount>,users_weight:&VecMap<address,u128>) :address {
        let count:u128 = 0;
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


    fun bytes2u128(data:vector<u8>) :u128 {
        let result:u128 = 0;
        let l = vector::length(&data);
        let i = 0;
        while (i < l) {
            let b = vector::borrow(&data, i);
            result = (result << 8) | (*b as u128) ;
            i=i+1;
        };

        return (result)
    }

    fun calculteWeight(level:u8) :u128 {
        if (level == 3) {
            return (15)
        };

        if (level == 2) {
            return (5)
        };

        return (1)
    }

    fun getUsers(): (vector<InvestmentAccount>, VecMap<address,u128>,u128) {
        let users =  vector::empty<InvestmentAccount>();
        let users_weight = vec_map::empty<address,u128>();
        let total_weight:u128 = 0;

        return (users,users_weight,total_weight)
    }
}