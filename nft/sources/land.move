// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module nft::land {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::url::{Self, Url};
    use sui::vec_map::{Self, VecMap};
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use std::ascii;
    use std::option;

    struct Land has key {
        id: UID,
        token_uri: Url,
        status: bool,
        condition: u64,
        total: u64,
        injection_details: VecMap<address, u64>,
    }

    ///
    /// @ownership: Shared
    ///
    struct Noteboard<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        enable_mint_status: bool,
        enable_mint_request_time: u64,
        active_condition: u64,
        active_condition_request_time: u64,
        minimum_injection_quantity: u64,
    }

    struct OwnerCap has key {
        id: UID
    }

    struct MinterCap has key {
        id: UID
    }

    struct ActivationEvent has copy, drop{
        land_id: ID,
        active: u64,
        status: bool,
    }

    // Errors
    const EAlreadyActive: u64 = 0;
    const EActiveValueIsZero: u64 = 1;
    const ETooManyActiveValues: u64 = 2;
    const EInvalidLandId: u64 = 3;
    const EMintingIsDisabled: u64 = 4;
    const EMintingAlreadyDisabled: u64 = 5;
    const EMintingAlreadyEnabled: u64 = 6;
    const ELessThanTheMinimumQuantity: u64 = 7;
    
    public fun create_<T>(balance: Balance<T>, minter: address, active_condition: u64, minimum_injection_quantity: u64, ctx: &mut TxContext) {
        let note = Noteboard {
            id: object::new(ctx),
            balance,
            enable_mint_status: true,
            enable_mint_request_time: 0,
            active_condition,
            active_condition_request_time: 0,
            minimum_injection_quantity,
        };

        let owner_cap = OwnerCap {
            id: object::new(ctx),
        };

        let minter_cap = MinterCap {
            id: object::new(ctx),
        }; 

        transfer::share_object(note);
        transfer::transfer(owner_cap, sender(ctx));
        transfer::transfer(minter_cap, minter);
    }

    // clock objcet use '0x6'
    public entry fun mint<T>(clock: &Clock, _: &MinterCap, note: &Noteboard<T>, to: address, token_uri: vector<u8>, ctx: &mut TxContext) {
        assert!(get_enable_mint_status(clock, note), EMintingIsDisabled);

        let uri_str = ascii::string(token_uri);
        let land = Land {
            id: object::new(ctx),
            token_uri: url::new_unsafe(uri_str),
            status: false,
            condition: get_active_condition(clock, note),
            total: 0,
            injection_details: vec_map::empty(),
        };
        transfer::transfer(land, to);
    }

    public entry fun inject_active<T>(coin: Coin<T>, land: &mut Land, account: address, note: &mut Noteboard<T>) {
        let balance = coin::into_balance(coin);
        let active = balance::value(&balance);

        assert!(land.status == false, EAlreadyActive);
        assert!(active >= note.minimum_injection_quantity, ELessThanTheMinimumQuantity);
        assert!(land.total + active <= land.condition, ETooManyActiveValues);

        balance::join(&mut note.balance, balance);
        land.total = land.total + active;

        let injection_details = land.injection_details;
        let option_value =  vec_map::try_get(&injection_details, &account);
        if (option::is_some(&option_value)) {
            *vec_map::get_mut(&mut injection_details, &account) = *option::borrow(&option_value) + active;
        }else{
            vec_map::insert(&mut injection_details, account, active);
        };

        if (land.total == land.condition) land.status = true;

        event::emit(ActivationEvent{
            land_id: object::uid_to_inner(&land.id),
            active,
            status: land.status,
        });
    }

    public fun get_land_status (land: &Land): bool {
        land.status
    }

    public fun get_land_total (land: &Land): u64 {
        land.total
    }

    public fun get_land_injection_details (land: &Land, account: address): u64 {
        let option_value =  vec_map::try_get(&land.injection_details, &account);
        if (option::is_some(&option_value)) {
            *option::borrow(&option_value)
        } else {
            0
        }
    }

    // clock objcet use '0x6'
    public fun get_enable_mint_status<T>(clock: &Clock, note: &Noteboard<T>): bool {
        let new_enable_mint_status = note.enable_mint_status;
        let enable_mint_request_time = note.enable_mint_request_time;
        if (new_enable_mint_status == true && clock::timestamp_ms(clock) > enable_mint_request_time + 2 * 24 * 60 * 60 * 1000) {
            true
        } else {
            note.enable_mint_status
        }
    }

    // clock objcet use '0x6'
    public fun get_active_condition<T>(clock: &Clock, note: &Noteboard<T>): u64 {
        let new_active_condition = note.active_condition;
        let active_condition_request_time = note.active_condition_request_time;
        if (new_active_condition > 0 && clock::timestamp_ms(clock) > active_condition_request_time + 2 * 24 * 60 * 60 * 1000) {
            new_active_condition
        } else {
            note.active_condition
        }
    }

    // clock objcet use '0x6'
    public entry fun enable_mint<T>(clock: &Clock, _: &OwnerCap, note: &mut Noteboard<T>) {
        assert!(!get_enable_mint_status(clock, note), EMintingAlreadyEnabled);
        note.enable_mint_request_time = clock::timestamp_ms(clock);
        note.enable_mint_status = true;
    }

    public entry fun disable_mint<T>(clock: &Clock, _: &OwnerCap, note: &mut Noteboard<T>) {
        assert!(get_enable_mint_status(clock, note), EMintingAlreadyDisabled);
        note.enable_mint_status = false;
    }

    // clock objcet use '0x6'
    public entry fun set_active_condition<T>(clock: &Clock, _: &OwnerCap, note: &mut Noteboard<T>, new_active_condition: u64) {
        let old_active_condition = get_active_condition(clock, note);
        assert!(new_active_condition > old_active_condition, EActiveValueIsZero);

        note.active_condition = old_active_condition;
        note.active_condition_request_time = clock::timestamp_ms(clock);
    }
}