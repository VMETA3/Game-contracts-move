// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module vip::vip {
    use std::vector;
    use sui::balance::{Self, Balance};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::vec_map::{Self, VecMap};

    const INTERVAL: u64 = 30 * 24 * 60 * 60;
    /// Error
    const EInvalidActivity: u64 = 0;
    const EUpgradeIntervalLessThan30Days: u64 = 1;
    const EExceedVipNumberLimit: u64 = 2;
    const ELevelThresholdNotReached: u64 = 3;
    const EInvalidOwnerCapability: u64 = 4;
    const ELengthOfDataIsDifferent: u64 = 5;

    struct Vip<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        level_rule: vector<Level>,
        activity_start_time: u64,
        activity_end_time: u64,
        vip_info: VecMap<address, VipInfo>
    }

    struct VipInfo has store, drop{
        amount: u64,
        start_time: u64,
        level: u8,
    }

    struct Level has store, drop{
        level: u8,
        threshold: u64,
        number_limit: u64,
        current_number: u64,
    }

    /// Owner capability
    struct OwnerCapability<phantom T> has key, store {
        id: UID,
        raffle_bag_id: ID,
    }

    // event Deposit(address account, uint256 amount);
    struct DepositEvent has copy, drop{
        account: address,
        amount: u64,
    }

    //////////////////////////////////////////////////////
    /// HELPER FUNCTIONS
    //////////////////////////////////////////////////////

    fun create_<T>(balance: Balance<T>, ctx: &mut TxContext): OwnerCapability<T> {
        let raffle_bag = Vip<T> {
            id: object::new(ctx),
            balance,
            level_rule: vector::empty(),
            activity_start_time: 0,
            activity_end_time: 0,
            vip_info: vec_map::empty(),
        };

        let owner_cap = OwnerCapability {
            id: object::new(ctx),
            raffle_bag_id: object::id(&raffle_bag),
        };
        transfer::share_object(raffle_bag);
        owner_cap
    }

    fun check_owner_capability_validity<T>(raffle_bag: &Vip<T>, capability: &OwnerCapability<T>) {
        assert!(object::id(raffle_bag) == capability.raffle_bag_id, EInvalidOwnerCapability);
    }


    fun handle<T>(vip: &mut Vip<T>, amount: u64): u64 {
        let level_index = calculation_level_index<T>(vip, amount);
        let current_level = vector::borrow_mut(&mut vip.level_rule, level_index);
        assert!(current_level.current_number < current_level.number_limit, EExceedVipNumberLimit);
        current_level.current_number = current_level.current_number + 1;
        level_index
    }

    fun calculation_level_index<T>(vip: &Vip<T>, amount: u64): u64 {
        let lv1_index = 0;
        let lv2_index = 0;
        let lv3_index = 0;

        let i = 0;
        while(i < vector::length(&vip.level_rule)) {
            if (vector::borrow(&vip.level_rule, i).level == 1) {
                lv1_index = i;
            };
            if (vector::borrow(&vip.level_rule, i).level == 2) {
                lv2_index = i;
            };
            if (vector::borrow(&vip.level_rule, i).level == 3) {
                lv3_index = i;
            };
            i = i + 1;
        };

        if (amount >= vector::borrow(&vip.level_rule, lv3_index).threshold) {
            lv3_index
        } else if (amount >= vector::borrow(&vip.level_rule, lv2_index).threshold && amount < vector::borrow(&vip.level_rule, lv3_index).threshold) {
            lv2_index
        } else if (amount >= vector::borrow(&vip.level_rule, lv1_index).threshold && amount < vector::borrow(&vip.level_rule, lv2_index).threshold) {
            lv1_index
        } else {
            0
        }
    }

    fun get_level_index<T>(vip: &Vip<T>, level: u8): u64{
        let i = 0;
        while(i < vector::length(&vip.level_rule)) {
            if (vector::borrow(&vip.level_rule, i).level == level) {
                return i
            };
            i = i + 1;
        };
        0
    }

    fun deposit_<T>(vip: &mut Vip<T>, clock: &Clock, to: address, balance: Balance<T>) {
        let amount = balance::value(&balance);
        let timestamp =  clock::timestamp_ms(clock);
        assert!(timestamp > vip.activity_start_time && timestamp < vip.activity_end_time, EInvalidActivity);

        if (vec_map::contains(&vip.vip_info, &to)){
            let (_, info) = vec_map::remove(&mut vip.vip_info, &to);
            let new_amount = info.amount + amount;
            assert!(timestamp - info.start_time < INTERVAL, EUpgradeIntervalLessThan30Days);

            let level_index = handle<T>(vip, new_amount);
            assert!(level_index > get_level_index(vip, info.level), ELevelThresholdNotReached);

            let info = VipInfo {
                amount: new_amount,
                start_time: info.start_time,
                level: vector::borrow(&vip.level_rule, level_index).level,
            };
            vec_map::insert(&mut vip.vip_info, to, info);
        }else{
            let level_index = handle<T>(vip, amount);
            let info = VipInfo {
                amount,
                start_time: timestamp,
                level: vector::borrow(&vip.level_rule, level_index).level,
            };
            vec_map::insert(&mut vip.vip_info, to, info);
        };

        balance::join(&mut vip.balance, balance);
        event::emit(DepositEvent{
                account: to,
                amount,
            });
    }

    //////////////////////////////////////////////////////
    /// PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////

    public entry fun create<T>(coin: Coin<T>, ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        let cap = create_<T>(balance, ctx);
        transfer::public_transfer(cap, sender(ctx));
    }

    public entry fun create_empty<T>(ctx: &mut TxContext) {
        let empty_balance = balance::zero<T>();
        let cap = create_(empty_balance, ctx);
        transfer::public_transfer(cap, sender(ctx));
    }

    public entry fun deposit<T>(vip: &mut Vip<T>, clock: &Clock, coin: Coin<T>, ctx: &mut TxContext) {
        let amount = coin::into_balance(coin);
        deposit_(vip, clock, sender(ctx), amount);
    }

    public entry fun deposit_to<T>(vip: &mut Vip<T>, clock: &Clock, coin: Coin<T>, to: address) {
        let amount = coin::into_balance(coin);
        deposit_(vip, clock, to, amount);
    }

    public entry fun set_activity_start_time<T>(vip: &mut Vip<T>, capability: &OwnerCapability<T>, start_time: u64) {
        check_owner_capability_validity<T>(vip, capability);
        vip.activity_start_time = start_time;
    }

    public entry fun set_activity_end_time<T>(vip: &mut Vip<T>, capability: &OwnerCapability<T>, end_time: u64) {
        check_owner_capability_validity<T>(vip, capability);
        vip.activity_end_time = end_time;
    }

    public entry fun set_level<T>(
        vip: &mut Vip<T>, 
        capability: &OwnerCapability<T>,
        level: u8,
        threshold: u64,
        number_limit: u64,
        current_number: u64,
    ) {
        check_owner_capability_validity<T>(vip, capability);
        
        vector::push_back(&mut vip.level_rule, Level {
            level,
            threshold,
            number_limit,
            current_number,
        });
    }

    public entry fun set_level_rule<T>(
        vip: &mut Vip<T>, 
        capability: &OwnerCapability<T>, 
        levels: vector<u8>,
        thresholds: vector<u64>,
        number_limits: vector<u64>,
        current_numbers: vector<u64>,
    ) {
        check_owner_capability_validity<T>(vip, capability);

        let len = vector::length(&levels);
        assert!(
            len == vector::length(&thresholds) 
            && len == vector::length(&number_limits)
            && len == vector::length(&current_numbers), 
            ELengthOfDataIsDifferent);
        
        let i = 0;
        while (i < len) {
            let level = *vector::borrow(&levels, i);
            let threshold = *vector::borrow(&thresholds, i);
            let number_limit = *vector::borrow(&number_limits, i);
            let current_number = *vector::borrow(&current_numbers, i);
            
            vector::push_back(&mut vip.level_rule, Level {
                level,
                threshold,
                number_limit,
                current_number,
            });

            i = i + 1;
        };
    }

    public entry fun clean_level_rule<T>(vip: &mut Vip<T>, capability: &OwnerCapability<T>, index: u64) {
        check_owner_capability_validity<T>(vip, capability);
        vector::remove(&mut vip.level_rule, index);
    }


    public entry fun clean_all_level_rule<T>(vip: &mut Vip<T>, capability: &OwnerCapability<T>){
        check_owner_capability_validity<T>(vip, capability);
        vip.level_rule = vector::empty();
    }



    public fun get_latest_list<T>(vip: &Vip<T>): VecMap<address, u8> {
        let result: VecMap<address, u8> = vec_map::empty();
        let keys = vec_map::keys(&vip.vip_info);

        let i = 0;
        while (i < vector::length(&keys)) {
            let key = *vector::borrow(&keys, i);
            let level = vec_map::get(&vip.vip_info, &key).level;
            vec_map::insert(&mut result, key, level);
            i = i + 1;
        };
        result
    }
}