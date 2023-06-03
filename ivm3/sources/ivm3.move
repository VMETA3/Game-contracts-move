// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module ivm3::ivm3 {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::object::{Self, UID};


    /// Name of the coin. By convention, this type has the same name as its parent module
    /// and has no fields. The full type of the coin defined by this module will be `COIN<MANAGED>`.
    struct IVM3 has drop {}

    /// A registry of addresses white list from using the coin.
    struct Registry has key {
        id: UID,
        white_list: vector<address>
    }
    
    /// For when address not in whiteList
    const EAddressBanned: u64 = 1;


    /// Register the managed currency to acquire its `TreasuryCap`. Because
    /// this is a module initializer, it ensures the currency only gets
    /// registered once.
    fun init(witness: IVM3, ctx: &mut TxContext) {
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, metadata) = coin::create_currency<IVM3>(witness, 9, b"IVM3", b"Invitation VM3", b"Invitation VM3 Token", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        mint(&mut treasury_cap, 1000000000, tx_context::sender(ctx), ctx);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

        transfer::share_object(Registry {
            id: object::new(ctx),
            white_list: vector::empty(),
        });
    }

    /// Manager can add address to whiteList
    public entry fun add_to_white_list(_treasury_cap: &TreasuryCap<IVM3>, registry: &mut Registry, to_allow: address) {
        vector::push_back(&mut registry.white_list, to_allow)
    }
    /// Manager can remove address from whiteList
    public entry fun remove_from_white_list(_treasury_cap: &TreasuryCap<IVM3>, registry: &mut Registry, to_allow: address) {
        let(ok,index) = vector::index_of(&registry.white_list, &to_allow);
        if (!ok) return;
        

        vector::remove(&mut registry.white_list, index);
    }


    /// Manager can mint new coins
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<IVM3>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    /// Manager can burn coins
    public entry fun burn(treasury_cap: &mut TreasuryCap<IVM3>, coin: Coin<IVM3>) {
        coin::burn(treasury_cap, coin);
    }

    /// transfer coins
    public entry fun transfer(r: &Registry, c: &mut Coin<IVM3>, value: u64, recipient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&r.white_list, &sender) == true, EAddressBanned);

        transfer::public_transfer(
            coin::split(c, value, ctx), 
            recipient
        )
    }

     #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(IVM3 {}, ctx);
    }
}