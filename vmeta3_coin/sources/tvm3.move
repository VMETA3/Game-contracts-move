// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module vmeta3_coin::tvm3 {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TVM3 has drop {}

    /// Register the managed currency to acquire its `TreasuryCap`. Because
    /// this is a module initializer, it ensures the currency only gets
    /// registered once.
    fun init(witness: TVM3, ctx: &mut TxContext) {
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, metadata) = coin::create_currency<TVM3>(witness, 9, b"TVM3", b"TVMeta3", b"Test VMeta3", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    /// Manager can mint new coins
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<TVM3>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
    }

    /// Manager can burn coins
    public entry fun burn(treasury_cap: &mut TreasuryCap<TVM3>, coin: Coin<TVM3>) {
        coin::burn(treasury_cap, coin);
    }

    /// transfer coins
    public entry fun transfer(c: &mut Coin<TVM3>, value: u64, recipient: address, ctx: &mut TxContext) {
        transfer::public_transfer(
            coin::split(c, value, ctx), 
            recipient
        );
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(TVM3 {}, ctx);
    }
}
