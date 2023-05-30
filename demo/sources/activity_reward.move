// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::activity_reward{
    use sui::event;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::clock::{Self, Clock};
    use std::hash;
    use sui::address;

    struct FutureReleaseData has copy, drop {
        date: u64,
        amount: u64,
    }

    struct GetRewardEvent has copy, drop {
        account: address,
        amount: u64,
    }

    struct WithdrawReleasedRewardEvent has copy, drop {
        account: address,
        amount: u64,
    }

    struct InjectReleaseRewardEvent has copy, drop {
        account: address,
        amount: u64,
    }

    struct RequestSentEvent has copy, drop {
        request_id: u64,
        num_words: u64,
    }

    struct RequestFulfilledEvent has copy, drop {
        request_id: u64,
        random_words: vector<u64>,
    }

    public entry fun get_free_reward(nonce: u64, ctx: &mut TxContext) {
        let account = tx_context::sender(ctx);
        free_reward_(account, nonce);
    }

    public entry fun get_free_reward_to(to: address, nonce: u64) {
        free_reward_(to, nonce);
    }

    fun free_reward_(account: address, _nonce: u64) {
        event::emit(GetRewardEvent {
            account: account,
            amount: 500000000,
        });
    }

    public entry fun get_multiple_reward(nonce: u64, clock: &Clock, ctx: &mut TxContext) {
        let account = tx_context::sender(ctx);
        multiple_reward_(account, nonce, clock);
    }

    public entry fun get_multiple_reward_to(to: address, nonce: u64, clock: &Clock) {
        multiple_reward_(to, nonce, clock);
    }

    fun multiple_reward_(account: address, _nonce: u64, clock: &Clock) {
        let num = random_number(clock);

        event::emit(GetRewardEvent {
            account: account,
            amount: num,
        });
    }

    public fun random_number(clock: &Clock): u64 {
        let timestamp = clock::timestamp_ms(clock);
        let n = bytes2u64(hash::sha3_256(u642bytes(timestamp)));
        event::emit(RequestSentEvent {
            request_id: timestamp,
            num_words: timestamp,
        });
        n
    }

    fun bytes2u64(data:vector<u8>): u64 {
        let result:u64 = 0;
        let l = vector::length(&data);
        let i = 0;
        while (i < l) {
            let b = vector::borrow(&data, i);
            result = (result << 8) | (*b as u64);
            i=i+1;
        };

        result
    }

    fun u642bytes(n:u64): vector<u8> {
        let data = vector::empty<u8>();
        while(true){
            vector::push_back(&mut data, (n%8 as u8));
            n = n / 8;
            if (n==0) {
                break
            };
        };

        vector::reverse(&mut data);
        data
    }

    public entry fun check_released(_receiver: address): u64 {
        9000000000
    }

    public entry fun withdraw_released_reward(ctx: &mut TxContext) {
        let account = tx_context::sender(ctx);
        withdraw_released_reward_(account);
    }

    public entry fun withdraw_released_reward_to(to: address) {
        withdraw_released_reward_(to);
    }
    // function _withdrawReleasedReward(address receiver) internal {
    fun withdraw_released_reward_(receiver: address) {

        event::emit(WithdrawReleasedRewardEvent {
            account: receiver,
            amount: 1000000000,
        });
    }
 
    public entry fun injection_income_and_pool(_receiver: address, amount: u64): (u64, u64) {
        (amount,amount)
    }

    public entry fun inject_release_reward(receiver: address, amount: u64, _nonce: u64) {
        event::emit(InjectReleaseRewardEvent {
            account: receiver,
            amount: amount,
        });
    }

    public entry fun spender(): address {
        address::from_u256(111)
    }

    public entry fun release_reward_record(_user: address): u64 {
        1000000000
    }

    public entry fun release_reward_inserted(_user: address): bool {
        true
    }

    public entry fun release_reward_info(_user: address): (u64, u64) {
        (1000000000,1000000000)
    }

    public entry fun future_release_data(_user: address): vector<FutureReleaseData> {
        let v = vector::empty<FutureReleaseData>();
        vector::push_back(&mut v, FutureReleaseData {
            date: 1000000000,
            amount: 1000000000,
        });
        vector::push_back(&mut v, FutureReleaseData {
            date: 1000000000,
            amount: 1000000000,
        });
        v
    }
}