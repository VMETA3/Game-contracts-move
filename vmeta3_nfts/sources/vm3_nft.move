// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module vmeta3_nfts::vm3_nft {
    use sui::object::{Self, ID, UID};
    use sui::url::{Self, Url};
    use sui::event;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use sui::vec_set::{Self, VecSet};
    use sui::coin::{Self, Coin};
    use sui::vec_map::{Self, VecMap};
    use std::option;


    struct VM3NFT has key {
        id: UID,
        token_uri: Url,
    }

    ///
    /// @ownership: Shared
    ///
    struct Noteboard<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        allowed_build_caps: VecSet<ID>,
        allowed_withdraw_fee_caps: VecSet<ID>,
        deposit_amount: VecMap<address, u64>,
        build_fee: u64,
        build_fee_balance: Balance<T>,
    }

    ///
    /// @ownership: Owned
    ///
    struct BuildCap has key, store {
        id: UID,
        note_id: ID,
        token_uri: vector<u8>,
        to: address,
    }

    struct WithdrawFeeCap has key, store {
        id: UID,
        note_id: ID,
        to: address,
        amount: u64,
    }

    struct OwnerCap<phantom T> has key, store {
        id: UID,
        note_id: ID,
    }
 
    /// Events
    struct BuildEvent has copy, drop {
        user: address,
        nft_id: ID,
    }

    struct DepositEvent has copy, drop {
        user: address,
        amount: u64,
    }

    struct WithdrawEvent has copy, drop {
        user: address,
        amount: u64,
    }

    struct WithdrawFeeEvent has copy, drop {
        user: address,
        amount: u64,
    }

    /// Errors
    const EInvalidBuildCapability: u64 = 0;
    const EInvalidWithdrawFeeCapability: u64 = 1;
    const EInvalidOwnerCapability: u64 = 2;
    const EBuildCapabilityRevoked: u64 = 3;
    const EWithdrawFeeCapabilityRevoked: u64 = 4;
    const EInvalidDepositAccount: u64 = 5;
    const EInvalidDepositAmount: u64 = 6;
    const EInsufficientDepositAmount: u64 = 7;
    const EInsufficientWithdrawAmount: u64 = 8;
    const EInsufficientBuildFee: u64 = 9;


    //////////////////////////////////////////////////////
    /// HELPER FUNCTIONS
    //////////////////////////////////////////////////////

    /// Initialization. Create a new `OwnerCapability` and `Noteboard` with the given balance.
    public fun create_<T>(balance: Balance<T>, build_fee: u64, ctx: &mut TxContext): OwnerCap<T> {
        let note = Noteboard {
            id: object::new(ctx),
            balance,
            allowed_build_caps: vec_set::empty(),
            allowed_withdraw_fee_caps: vec_set::empty(),
            deposit_amount: vec_map::empty(),
            build_fee,
            build_fee_balance: balance::zero(),
        };
        let cap = OwnerCap {
            id: object::new(ctx),
            note_id: object::id(&note),
        };
        transfer::share_object(note);
        cap
    }

    fun check_owner_capability_validity<T>(note: &Noteboard<T>, owner: &OwnerCap<T>) {
        assert!(object::id(note) == owner.note_id, EInvalidOwnerCapability);
    }

    fun check_build_capability_validity<T>(note: &Noteboard<T>, cap: &BuildCap) {
        // Check that the ids match
        assert!(object::id(note) == cap.note_id, EInvalidBuildCapability);
        // Check that it has not been cancelled
        assert!(vec_set::contains(&note.allowed_build_caps, &object::id(cap)), EBuildCapabilityRevoked);
    }

    fun check_withdraw_fee_capability_validity<T>(note: &Noteboard<T>, cap: &WithdrawFeeCap) {
        // Check that the ids match
        assert!(object::id(note) == cap.note_id, EInvalidWithdrawFeeCapability);
        // Check that it has not been cancelled
        assert!(vec_set::contains(&note.allowed_withdraw_fee_caps, &object::id(cap)), EWithdrawFeeCapabilityRevoked);
    }

    fun build_(token_uri: vector<u8>, to: address, ctx: &mut TxContext): VM3NFT {
        let nft = VM3NFT {
            id: object::new(ctx),
            token_uri: url::new_unsafe_from_bytes(token_uri)
        };
        event::emit(BuildEvent {
            user: to,
            nft_id: object::uid_to_inner(&nft.id),
        });
        nft
    }

    fun deposit_<T>(note: &mut Noteboard<T>, balance: Balance<T>, account: address) {
        assert!(balance::value(&balance) > 0, EInvalidDepositAmount);

        vec_map::insert(&mut note.deposit_amount, account, balance::value(&balance));
        balance::join(&mut note.balance, balance);
    }

    fun get_deposit_amount<T>(note: &mut Noteboard<T>, account: address): u64 {
        let option_deposit_amount = vec_map::try_get(&note.deposit_amount, &account);
        if (option::is_none(&option_deposit_amount)) {
            assert!(false, EInvalidDepositAccount);
        };
        *option::borrow(&option_deposit_amount)
    }

    fun set_deposit_amount<T>(note: &mut Noteboard<T>, account: address, value: u64) {
        let _ = get_deposit_amount(note, account);
        *vec_map::get_mut(&mut note.deposit_amount, &account) = value;
    }

    fun deduct_build_fee<T>(note: &mut Noteboard<T>, account: address) {
        let deposit_amount = get_deposit_amount(note, account);
        assert!(deposit_amount >= note.build_fee, EInsufficientBuildFee);

        let value = deposit_amount - note.build_fee;
        set_deposit_amount(note, account, value);

        let fee = balance::split(&mut note.balance, note.build_fee);
        balance::join(&mut note.build_fee_balance, fee);
    }

    fun withdraw_<T>(note: &mut Noteboard<T>, withdraw_amount: u64, account: address): Balance<T> {
        let deposit_amount = get_deposit_amount(note, account);
        assert!(withdraw_amount <= deposit_amount, EInsufficientWithdrawAmount);

        event::emit(WithdrawEvent {
            user: account,
            amount: withdraw_amount,
        });
        *vec_map::get_mut(&mut note.deposit_amount, &account) = deposit_amount - withdraw_amount;
        balance::split(&mut note.balance, withdraw_amount)
    }

    fun withdraw_fee_<T>(note: &mut Noteboard<T>, withdraw_amount: u64, to: address): Balance<T> {
        event::emit(WithdrawFeeEvent {
            user: to,
            amount: withdraw_amount,
        });
        balance::split(&mut note.balance, withdraw_amount)
    }

    //////////////////////////////////////////////////////
    /// PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////
    
    public fun balance<T>(note: &Noteboard<T>): &Balance<T> {
        &note.balance
    }

    public entry fun create<T>(coin: Coin<T>, build_fee: u64, ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        let cap = create_<T>(balance, build_fee, ctx);
        transfer::public_transfer(cap, sender(ctx));
    }

    public entry fun create_empty<T>(build_fee: u64, ctx: &mut TxContext) {
        let empty_balance = balance::zero<T>();
        let cap = create_(empty_balance, build_fee, ctx);
        transfer::public_transfer(cap, sender(ctx));
    }

    /// Create a `BuildCapability`
    public entry fun create_build_capability<T>(note: &mut Noteboard<T>, owner: &OwnerCap<T>, token_uri: vector<u8>, to: address, cap_transfer_to: address, ctx: &mut TxContext) {
        check_owner_capability_validity(note, owner);

        let cap_id = object::new(ctx);
        vec_set::insert(&mut note.allowed_build_caps, object::uid_to_inner(&cap_id));

        let cap = BuildCap {
            id: cap_id,
            note_id: object::uid_to_inner(&note.id),
            token_uri,
            to,
        };
        transfer::transfer(cap, cap_transfer_to);
    }

    /// Create a `WithdrawFeeCapability`
    public entry fun create_withdraw_fee_capability<T>(note: &mut Noteboard<T>, owner: &OwnerCap<T>, to: address, amount: u64, cap_transfer_to: address, ctx: &mut TxContext) {
        check_owner_capability_validity(note, owner);

        let cap_id = object::new(ctx);
        vec_set::insert(&mut note.allowed_withdraw_fee_caps, object::uid_to_inner(&cap_id));

        let cap = WithdrawFeeCap {
            id: cap_id,
            note_id: object::uid_to_inner(&note.id),
            to,
            amount,
        };
        transfer::transfer(cap, cap_transfer_to);
    }

    /// Revoke a `BuildCapability` as an `OwnerCapability` holder
    public entry fun revoke_build_capability<T>(note: &mut Noteboard<T>, owner: &OwnerCap<T>, cap_id: ID) {
        // Ensures that only the owner can withdraw from the safe.
        check_owner_capability_validity(note, owner);
        vec_set::remove(&mut note.allowed_build_caps, &cap_id);
    }

    /// Revoke a `BuildCapability` as its owner
    public entry fun self_revoke_transfer_capability<T>(note: &mut Noteboard<T>, cap: &BuildCap) {
        check_build_capability_validity(note, cap);
        vec_set::remove(&mut note.allowed_build_caps, &object::id(cap));
    }

    /// Revoke a `WithdrawFeeCapability` as an `OwnerCapability` holder
    public entry fun revoke_withdraw_fee_capability<T>(note: &mut Noteboard<T>, owner: &OwnerCap<T>, cap_id: ID) {
        // Ensures that only the owner can withdraw from the safe.
        check_owner_capability_validity(note, owner);
        vec_set::remove(&mut note.allowed_withdraw_fee_caps, &cap_id);
    }

    /// Revoke a `WithdrawFeeCapability` as its owner
    public entry fun self_revoke_withdraw_fee_capability<T>(note: &mut Noteboard<T>, cap: &WithdrawFeeCap) {
        check_withdraw_fee_capability_validity(note, cap);
        vec_set::remove(&mut note.allowed_withdraw_fee_caps, &object::id(cap));
    }

    public entry fun build<T>(note: &mut Noteboard<T>, cap: BuildCap, ctx: &mut TxContext) {
        let BuildCap { id, note_id:_, token_uri, to } = cap;
        deduct_build_fee(note, sender(ctx));

        let nft = build_(token_uri, to, ctx);
        transfer::transfer(nft, to);
        object::delete(id);
    }

    public entry fun deposit<T>(note: &mut Noteboard<T>, coin: Coin<T>, ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        deposit_(note, balance, sender(ctx));
    }

    public entry fun deposit_to<T>(note: &mut Noteboard<T>, coin: Coin<T>, to: address) {
        let balance = coin::into_balance(coin);
        deposit_(note, balance, to);
    }

    public entry fun withdraw<T>(note: &mut Noteboard<T>, withdraw_amount: u64, ctx: &mut TxContext) {
        let balance = withdraw_(note, withdraw_amount, sender(ctx));
        let coin = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin, sender(ctx));
    }

    public entry fun withdraw_to<T>(note: &mut Noteboard<T>, withdraw_amount: u64, to:address, ctx: &mut TxContext) {
        let balance = withdraw_(note, withdraw_amount, sender(ctx));
        let coin = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin, to);
    }

    public entry fun withdraw_fee<T>(note: &mut Noteboard<T>, cap: WithdrawFeeCap, ctx: &mut TxContext) {
        let WithdrawFeeCap {id, note_id:_, to, amount} = cap;
        let balance = withdraw_fee_(note, amount, to);
        let coin = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin, to);
        object::delete(id);
    }

}