// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module coin::vm3 {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};

    struct VM3 has drop {}

    struct VM3Coin has key{
        id: UID,
        has_minted: u64,
    }

    const TotalSupply: u64 = 80000000000000000;

    /// Error
    const ETotalSupplyExceeded: u64 = 1;

    fun init(witness: VM3, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<VM3>(witness, 9, b"VM3", b"VMeta3", b"VMeta3", option::none(), ctx);
        let coin = VM3Coin {
            id: object::new(ctx),
            has_minted: 0,
        };

        transfer::share_object(coin);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    /// Manager can mint new coins
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<VM3>, 
        vm3_coin: &mut VM3Coin,
        amount: u64, recipient: 
        address, 
        ctx: &mut TxContext
    ) {
        assert!(amount + vm3_coin.has_minted <= TotalSupply, ETotalSupplyExceeded);
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
        vm3_coin.has_minted = vm3_coin.has_minted + amount;
    }

    /// Manager can burn coins
    public entry fun burn(
        treasury_cap: &mut TreasuryCap<VM3>, 
        vm3_coin: &mut VM3Coin,
        coin: Coin<VM3>
    ) {
        vm3_coin.has_minted = vm3_coin.has_minted - coin::value(&coin);
        coin::burn(treasury_cap, coin);
    }

    /// transfer coins
    public entry fun transfer(c: &mut Coin<VM3>, value: u64, recipient: address, ctx: &mut TxContext) {
        transfer::public_transfer(
            coin::split(c, value, ctx), 
            recipient
        );
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(VM3 {}, ctx);
    }
}
