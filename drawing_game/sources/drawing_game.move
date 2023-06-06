// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module drawing_game::drawing_game {
    use std::vector;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::vec_set::{Self, VecSet};
    use sui::ecvrf;
    use sui::vec_map::{Self, VecMap};
    use std::hash;
    use sui::dynamic_object_field as dof;
    use sui::event;
    use vip::vip::{Self, Vip};

    struct DRAWING_GAME has drop {
    
    }

    struct InvestmentAccount has copy,drop {
        addr:address,
        level:u8,
    }

    struct BonusPool<phantom T> has key,store {
        id: UID,
        bonus_pool: UID,
        nfts:vector<ID>,
        old_lucky_users:VecSet<address>,
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
    struct DrawEvent has drop, copy {
        winners: vector<address>,
        nfts: vector<ID>,
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

    public fun initialize<T>(init_lock:&mut InitLock, ctx: &mut TxContext) {
        assert!(init_lock.has_init==false, EAlreadyInitialized);
        
        let bonus_pool = BonusPool<T>{
            id: object::new(ctx),
            bonus_pool: object::new(ctx),
            nfts: vector::empty(),
            old_lucky_users: vec_set::empty(),
        };
        transfer::share_object(bonus_pool);
        init_lock.has_init = true;
    }

    //TODO: depost nft list(Must solve vector<T> drop ability)
    public entry fun deposit<T: key+store>(_:&OwnerCapability, bonus_pool:&mut BonusPool<T>, nft:T) {
        add_nft_to_pool_(bonus_pool, nft);
    }

    public entry fun nfts_pool_number<T: key+store>(bonus_pool:&BonusPool<T>): u64{
        let l = vector::length(&bonus_pool.nfts);

        return (l)
    }
    
    public entry fun draw<T: key+store, VT>(_:&OwnerCapability, vip_info:&Vip<VT>,bonus_pool:&mut BonusPool<T>, draw_total:u64, rand_number_bytes: vector<u8>, alpha_string: vector<u8>, public_key: vector<u8>, proof: vector<u8>) {
        assert!(ecvrf::ecvrf_verify(&rand_number_bytes, &alpha_string, &public_key, &proof), 0);
        assert!(draw_total > 0 && draw_total  <= vector::length(&bonus_pool.nfts), 0);

        let users_level = vip::get_latest_list(vip_info);
        draw_<T>(bonus_pool, draw_total, rand_number_bytes, users_level);
    }

    fun draw_<T: key+store>(bonus_pool:&mut BonusPool<T>, draw_total:u64,rand_number_bytes: vector<u8>, users_level:VecMap<address, u8>): (vector<address>, vector<u64>) {
        let (users, users_weight, users_total_weight) = get_users_(&bonus_pool.old_lucky_users, users_level);
        let winners = vector::empty<address>();
        let winners_lucky_number = vector::empty<u64>();

        while(draw_total>0 && !vector::is_empty(&bonus_pool.nfts)){
            if (users_total_weight == 0) {
                break
            };

            let rand_number = bytes2u64(rand_number_bytes) % users_total_weight;
            let (winner, winner_weight) = who_win_(rand_number, &mut users, &users_weight);
            assert!(winner != ZeroAddress, 0);

            vector::push_back(&mut winners, winner);
            vector::push_back(&mut winners_lucky_number, rand_number);
            users_total_weight = users_total_weight - winner_weight;
            rand_number_bytes = hash::sha3_256(rand_number_bytes);

            draw_total = draw_total - 1;
        };

        transfer_to_lucky_users_<T>(bonus_pool, winners);
        return (winners, winners_lucky_number)
    }

    // convert bytes to u64, cut if length larger than 8
    public fun  bytes2u64(data:vector<u8>): u64 {
        vector::reverse(&mut data);
        while (vector::length(&data) > 8) {
            let end_i = vector::length(&data) - 1;
            vector::remove(&mut data, end_i);
        };

        let result:u64 = 0;
        let l = vector::length(&data);
        let i = 0;
        while (i < l) {
            let b = vector::borrow(&data, i);
            result = (result << 8) | (*b as u64) ;
            i=i+1;
        };

        return (result)
    }

    fun transfer_to_lucky_users_<T: key+store> (bonus_pool:&mut BonusPool<T>, lucky_users:vector<address>){
        let i = 0;
        let winner_nfts = vector::empty<ID>();
        while ( i < vector::length(&lucky_users) && vector::is_empty(&mut bonus_pool.nfts)) {
            let luck_user = vector::borrow(&lucky_users, i);
            let nft_id = vector::pop_back(&mut bonus_pool.nfts);
            let nft = remove_nft_from_pool_(bonus_pool, nft_id);
            
            transfer::public_transfer(nft, *luck_user);
            vector::push_back(&mut winner_nfts, nft_id);
            i = i + 1;
        };

        event::emit(DrawEvent{
                winners: lucky_users,
                nfts: winner_nfts,
        });
    }

    fun remove_nft_from_pool_<T: key+store>(bonus_pool:&mut BonusPool<T>, nft_id: ID): T {
        dof::remove(&mut bonus_pool.bonus_pool, nft_id)
    }

    fun add_nft_to_pool_<T: key+store>(bonus_pool:&mut BonusPool<T>, nft:T) {
        let nft_id = object::id(&nft);

        vector::push_back(&mut bonus_pool.nfts, nft_id);
        dof::add(&mut bonus_pool.bonus_pool, nft_id, nft);
    }

    fun who_win_(number:u64, users:&mut vector<InvestmentAccount>,users_weight:&VecMap<address,u64>): (address, u64) {
        let count:u64 = 0;
        let i = 0;
        while (i < vector::length(users)) {
            let user = vector::borrow(users,i);
            let user_weight = *vec_map::get(users_weight, &user.addr);
            count = count + user_weight;
            if (count>=number) {
                let winner = user.addr;
                vector::remove(users, i);
                return (winner, user_weight)
            };

            i = i + 1;
        };

        return (ZeroAddress, 0)
    }

    fun calculte_weight_(level:u8): u64 {
        if (level == 3) {
            return (15)
        };

        if (level == 2) {
            return (5)
        };

        return (1)
    }

    fun get_users_(old_lucky_users:&VecSet<address>, users_level:VecMap<address, u8>): (vector<InvestmentAccount>, VecMap<address,u64>,u64) {
        let users =  vector::empty<InvestmentAccount>();
        let users_weight = vec_map::empty<address, u64>();
        let total_weight:u64 = 0;

        while(!vec_map::is_empty(&users_level)){
            let(addr, level) = vec_map::pop(&mut users_level);
            if(vec_set::contains(old_lucky_users, &addr)){
                continue
            };

            let weight = calculte_weight_(level);
            vec_map::insert(&mut users_weight, addr, weight);
            total_weight = total_weight + (weight as u64);
            vector::push_back(&mut users, InvestmentAccount{
                addr: addr,
                level: level,
            });
        };

        return (users, users_weight, total_weight)
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(DRAWING_GAME {}, ctx);
    }

    #[test_only]
    public fun test_draw<T: key+store>(bonus_pool:&mut BonusPool<T>, draw_total:u64, users_level:VecMap<address, u8>, rand_number_bytes: vector<u8>): (vector<address>, vector<u64>) {
        draw_<T>(bonus_pool, draw_total, rand_number_bytes, users_level)
    }

    #[test_only]
    public fun get_users(old_lucky_users:&VecSet<address>, users_level:VecMap<address, u8>): (vector<InvestmentAccount>, VecMap<address,u64>,u64) {
        get_users_(old_lucky_users, users_level)
    }

    #[test_only]
    public fun get_investment_account_addr(account: &InvestmentAccount): address {
        account.addr
    }
}