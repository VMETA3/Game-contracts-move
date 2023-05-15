// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module vmeta3_nfts::land {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};
    use sui::vec_map::{Self, VecMap};
    use sui::event;
    use std::ascii;
    use std::option;

    struct Land has key {
        id: UID,
        token_uri: Url,
        active_value: ActiveValue,
    }

    struct ActiveValue has store {
        status: bool,
        conditions: u64,
        total: u64,
        injection_details: VecMap<address, u64>,
    }

    struct LandCap has key {
        id: UID
    }

    struct ActivationEvent has copy, drop{
        land_id: ID,
        active: u64,
        status: bool,
    }

    const EAlreadyActive: u64 = 0;
    const EActiveValueIsZero: u64 = 1;
    const ETooManyActiveValues: u64 = 2;


    fun init(ctx: &mut TxContext) {
        transfer::transfer(LandCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }


    public entry fun mint(_: &LandCap, to: address, conditions: u64, token_uri: vector<u8>, ctx: &mut TxContext) {
        let status = false;
        if (conditions == 0) status = true;

        let active_value = ActiveValue {
            status,
            conditions,
            total: 0,
            injection_details: vec_map::empty(),
        };

        let uri_str = ascii::string(token_uri);
        let land = Land {
            id: object::new(ctx),
            token_uri: url::new_unsafe(uri_str),
            active_value,
        };
        transfer::transfer(land, to);
    }

    fun inject_active_(_: &LandCap, land: &mut Land, active: u64, account: address) {
        assert!(land.active_value.status == false, EAlreadyActive);
        assert!(active > 0, EActiveValueIsZero);
        assert!(land.active_value.total + active <= land.active_value.conditions, ETooManyActiveValues);

        land.active_value.total = land.active_value.total + active;

        let injection_details = land.active_value.injection_details;
        
        let option_value =  vec_map::try_get(&injection_details, &account);
        if (option::is_some(&option_value)) {
            *vec_map::get_mut(&mut injection_details, &account) = *option::borrow(&option_value) + active;
        }else{
            vec_map::insert(&mut injection_details, account, active);
        };

        if (land.active_value.total == land.active_value.conditions) land.active_value.status = true;

        event::emit(ActivationEvent{
            land_id: object::uid_to_inner(&land.id),
            active,
            status: land.active_value.status,
        });
    }

    public entry fun inject_active(cap: &LandCap, land: &mut Land, active: u64, ctx: &mut TxContext) {
        inject_active_(cap, land, active, tx_context::sender(ctx));
    }

    public entry fun inject_active_to(cap: &LandCap, land: &mut Land, active: u64, to: address) {
        inject_active_(cap, land, active, to);
    }

    public fun get_land_status (land: &Land): bool {
        land.active_value.status
    }

    public fun get_land_total (land: &Land): u64 {
        land.active_value.total
    }

    public fun get_land_injection_details (land: &Land, account: address): u64 {
        let option_value =  vec_map::try_get(&land.active_value.injection_details, &account);
        if (option::is_some(&option_value)) {
            *option::borrow(&option_value)
        } else {
            0
        }
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}