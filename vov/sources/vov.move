// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module vov::vov {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};
    use sui::clock::{Self, Clock};

    //constant
    const TwoDay: u64 = 2*24*60*60*1000; //ms
    const OneWeek: u64 = 7*24*60*60*1000;

    //errors code
    const EMintClosed: u64 = 1;
    const EOnlyAdminCanDo: u64 = 2;
    const EMintRecently: u64 = 3;

    struct VOV has drop {

    }

    struct DelayMintData has key,store {
        id: UID,
    
        balances: VecMap<address, Balance<VOV>>,
        times: VecMap<address, u64>,
    }

    struct MintSwitch has key,store {
        id:UID,
        opened: bool,
        time: u64, //ms
    }

    struct AdminParams has key,store {
        id: UID,
        owner: address,

        mint_switch: MintSwitch,
    }

    fun init(witness:VOV, ctx: &mut TxContext){
        let sender = tx_context::sender(ctx);
        // Get a treasury cap for the coin 
        let (treasury_cap, metadata) = coin::create_currency<VOV>(witness, 1, b"VOV", b"Vitality of VMeta3", b"Vitality of VMeta3", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, sender);

        let mint_switch = MintSwitch{
            id: object::new(ctx),
            opened: true,
            time: 0,
        };
        let admin_params = AdminParams{
            id: object::new(ctx),
            owner: sender,
            mint_switch: mint_switch,
        };
        transfer::share_object(admin_params);

        transfer::share_object(DelayMintData{
            id: object::new(ctx),
    
            balances: vec_map::empty(),
            times: vec_map::empty(),
        });
    }

    public entry fun delayed_mint(
       treasury_cap: &mut TreasuryCap<VOV>, delayed_mint_data:&mut DelayMintData,
       admin_params: &AdminParams, recipient: address, amount: u64,  clock: &Clock,ctx: &mut TxContext
    ) {
        assert!(admin_params.mint_switch.opened==true && timestamp(clock)-admin_params.mint_switch.time >= TwoDay, EMintClosed);
       
        check_and_handle_delayed_balance(&mut delayed_mint_data.balances, &mut delayed_mint_data.times, recipient, clock,ctx);
        assert!(vec_map::contains(&delayed_mint_data.balances, &recipient)==false, EMintRecently);

        // mint vov and add to delayed treasury
        let b  = coin::mint_balance(treasury_cap, amount);
        // record user delayed balance
        vec_map::insert(&mut delayed_mint_data.balances, recipient, b);
        vec_map::insert(&mut delayed_mint_data.times, recipient, timestamp(clock));
    }

    public entry fun transfer(c: &mut Coin<VOV>, value: u64, recipient: address,  delayed_mint_data:&mut DelayMintData, clock: &Clock,ctx: &mut TxContext) {
        check_and_handle_delayed_balance(&mut delayed_mint_data.balances, &mut delayed_mint_data.times, tx_context::sender(ctx), clock,ctx);

        transfer::public_transfer(
            coin::split(c, value, ctx), 
            recipient
        )
    }

    public entry fun close_mint(admin_params: &mut AdminParams, ctx: &mut TxContext) {
        check_admin(admin_params, tx_context::sender(ctx));

        admin_params.mint_switch.opened = false;
    }

    public entry fun open_mint(admin_params: &mut AdminParams, clock: &Clock,ctx: &mut TxContext) {
        check_admin(admin_params, tx_context::sender(ctx));

        admin_params.mint_switch.opened = true;
        admin_params.mint_switch.time = timestamp(clock);
    }

    public entry fun update_admin_owner_params(new_admin:address, admin_params: &mut AdminParams, ctx: &mut TxContext) {
        check_admin(admin_params, tx_context::sender(ctx));
        
        admin_params.owner = new_admin;
    }

    public entry fun balance_of(delayed_mint_data:&DelayMintData, account:address, clock: &Clock): u64 {
        if (vec_map::contains(&delayed_mint_data.balances, &account) && timestamp(clock) - *vec_map::get(&delayed_mint_data.times, &account) >= OneWeek) {
            let b = vec_map::get(&delayed_mint_data.balances, &account);
           
            return (balance::value(b))
        };

        return (0)
    }

    fun check_and_handle_delayed_balance(balances:&mut VecMap<address, Balance<VOV>>, times:&mut VecMap<address, u64>, account:address, clock: &Clock,ctx: &mut TxContext) {
        // if had deplayed balance unfreeze, transfer to receipt
        if(vec_map::contains(balances, &account) && 
        timestamp(clock) - *vec_map::get(times, &account) >= OneWeek){
            let (_,b) = vec_map::remove(balances, &account);
            vec_map::remove(times, &account);

            let c = coin::from_balance(b, ctx);
            transfer::public_transfer(c, account);
        };
    }

    fun check_admin(admin_params: &AdminParams, account:address) {
        assert!(admin_params.owner == account, EOnlyAdminCanDo);
    }

    fun timestamp(clock: &Clock): u64 {
        clock::timestamp_ms(clock)
    }

     #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(VOV{}, ctx);
    }
}