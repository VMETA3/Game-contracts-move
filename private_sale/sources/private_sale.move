// SPDX-License-Identifier: MIT

module private_sale::private_sale {
    use private_sale::safe_math;
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::vec_set::{Self, VecSet};
    use sui::tx_context::{Self, TxContext};
    use sui::vec_map::{Self, VecMap};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use std::vector;
    use sui::event;
   
    struct UserAsset<phantom T> has key, store{
        id: UID,
        owner: address,
        paused: bool,
        amount: Balance<T>,
        amount_withdrawn: u64,
        latest_withdrawn_time: u64,
        withdrawn_months: u64,
        release_total_months: u64
    }

    struct Sale<phantom S, phantom R> has key,store {
        id: UID,
        admin: address,
        paused: bool,

        sale_token: Balance<S>, 
        received_token: Balance<R>, // user pay for by sale_token
        price: u64, // how many token user could pay
        sold_amount: u64,

        person_min_buy: u64, // each
        person_max_buy: u64, // total 
        
        start_time: u64,
        end_time: u64,
        release_start_time: u64,
        release_total_months: u64,

        while_list: VecSet<address>,
        user_assets: VecMap<address, UserAsset<S>>,
    }

    struct EventSaleCreated has copy, drop {
        from: address,
        sale_id: ID,
        price: u64,
    }
    struct EventWithdraw has copy, drop {
        recipient: address,
        sale_id: ID,
        amount: u64,
    }
    struct EventWhitelistAdded has copy, drop {
        sale_id: ID,
        users: vector<address>,
    }

    // errors
    const ENotAdmin: u64 = 1;
    const ENotOwner: u64 = 2;
    const EWithdrawnRecently: u64 = 3;
    const ENotInWhiteList: u64 = 4;
    const ESaleNotStartOrEnd: u64 = 5;
    const EReleaseNotStart: u64 = 6;
    const ESalePaused: u64 = 7;

    //constant
    const Month: u64 = 30*24*60*60*1000;

    // creat a token sale and share it.
    // admin is sender.
    public entry fun create_sale<S,R>(price:u64, person_max_buy:u64, person_min_buy:u64, 
                        start_time:u64, end_time:u64, release_start_time:u64, release_total_months:u64, 
                        ctx:&mut TxContext) {
        assert!(price>0 && person_max_buy>0 && end_time>0, 0);
        
        let sale = Sale {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            paused: false,

            sale_token: balance::zero<S>(),
            received_token: balance::zero<R>(),
            price: price,
            sold_amount: 0,

            person_max_buy: person_max_buy,
            person_min_buy: person_min_buy,

            start_time: start_time,
            end_time: end_time,
            release_start_time: release_start_time,
            release_total_months: release_total_months,

            while_list: vec_set::empty(),
            user_assets: vec_map::empty()
        };

        event::emit(EventSaleCreated{
            from: tx_context::sender(ctx),
            sale_id: object::id(&sale),
            price: price,
        });

        transfer::share_object(sale);
    }

    public entry fun buy<S,R>(sale:&mut Sale<S,R>, pay_amount_coin: Coin<R>, clock:&Clock, ctx:&mut TxContext) {
        let current_time = timestamp(clock);
        assert!(sale.start_time <= current_time && sale.end_time >= current_time, ESaleNotStartOrEnd);
        assert!(sale.paused == false, ESalePaused);
        let pay_amount = coin::into_balance(pay_amount_coin);

        let sender = tx_context::sender(ctx);
        let can_buy_amount = balance::value(&pay_amount) / sale.price;
        assert!(vec_set::contains(&sale.while_list, &sender) == true, ENotInWhiteList);
        assert!(can_buy_amount >= sale.person_min_buy, 0);

        if (vec_map::contains(&sale.user_assets, &sender) == false){
            let user_asset = UserAsset{
                id: object::new(ctx),
                owner: sender,
                paused: false,
                amount: balance::zero<S>(),
                amount_withdrawn: 0,
                withdrawn_months: 0,
                release_total_months: sale.release_total_months,
                latest_withdrawn_time: 0,
            };
    
            vec_map::insert(&mut sale.user_assets, sender, user_asset);
        };

        let user_asset = vec_map::get_mut(&mut sale.user_assets, &sender);
        assert!(safe_math::add(balance::value(&user_asset.amount) + user_asset.amount_withdrawn, can_buy_amount) < sale.person_max_buy, 0);

        let can_buy_amount_balance = balance::split(&mut sale.sale_token, can_buy_amount);
        balance::join(&mut user_asset.amount, can_buy_amount_balance);
        balance::join(&mut sale.received_token, pay_amount);
    }

    public entry fun withdraw<S,R>(sale:&mut Sale<S,R>, recipient:address, clock:&Clock, ctx:&mut TxContext): (u64, u64) {
        let current_time = timestamp(clock);
        assert!(current_time >= sale.release_start_time, EReleaseNotStart);
        assert!(sale.paused == false, ESalePaused);

        let (withdraw_amount, withdraw_months) = can_withdraw_amount_(sale, recipient, clock);
        assert!(withdraw_amount > 0, 0);
        let user_asset = vec_map::get_mut(&mut sale.user_assets, &recipient);
        assert!(user_asset.paused == false, 0);

        let withdraw_amount_balance = balance::split(&mut user_asset.amount, withdraw_amount);
        transfer::public_transfer(coin::from_balance<S>(withdraw_amount_balance, ctx), recipient);

        user_asset.latest_withdrawn_time = current_time;
        user_asset.amount_withdrawn = user_asset.amount_withdrawn + withdraw_amount;
        user_asset.withdrawn_months = user_asset.withdrawn_months + withdraw_months;

        event::emit(EventWithdraw{
            recipient: recipient,
            sale_id: object::id(sale),
            amount: withdraw_amount,
        });

        return (withdraw_amount, withdraw_months)
    }

    public entry fun deposit<S,R>(sale:&mut Sale<S,R>, coin: Coin<S>) {
        let balance = coin::into_balance(coin);
        balance::join(&mut sale.sale_token, balance);
    }

    public entry fun can_withdraw_amount<S,R>(sale:&Sale<S,R>, user:address, clock:&Clock): (u64, u64) {
        can_withdraw_amount_(sale, user, clock)
    }

    /*
    * Query
    */
    public entry fun get_user_asset<S,R>(sale:&Sale<S,R>, user:address): (u64, u64) {
        let user_asset = vec_map::get(&sale.user_assets, &user);

        return (balance::value(&user_asset.amount), user_asset.amount_withdrawn)
    }

     public entry fun get_user_lastest_withdraw_time<S,R>(sale:&Sale<S,R>, user:address): (u64) {
        let user_asset = vec_map::get(&sale.user_assets, &user);

        user_asset.latest_withdrawn_time
    }


    /*
    * Admin operation
    */
    public entry fun withdraw_received_token<S,R>(sale:&mut Sale<S,R>, recipient:address, ctx:&mut TxContext){
        check_admin_(sale.admin, ctx);

        let value = balance::value(&sale.received_token);
        let value_balance = balance::split(&mut sale.received_token, value);
        transfer::public_transfer(coin::from_balance(value_balance, ctx), recipient);
    }

    public entry fun add_to_white_list<S,R>(sale:&mut Sale<S,R>, users:vector<address>,ctx:&TxContext) {
        check_admin_(sale.admin, ctx);
        let users_added = vector::empty<address>(); 

        while(vector::is_empty(&users) == false){
            let user = vector::remove(&mut users, 0);
            if (vec_set::contains(&sale.while_list, &user) == true) {
                continue
            };

            vec_set::insert(&mut sale.while_list, user);
            vector::push_back(&mut users_added, user);
        };

        event::emit(EventWhitelistAdded{
            sale_id: object::id(sale),
            users: users_added,
        });
    }

    public entry fun remove_from_white_list<S,R>(sale:&mut Sale<S,R>, users:vector<address>,ctx:&TxContext) {
        check_admin_(sale.admin, ctx);

        while(vector::is_empty(&users) == false){
            let user = vector::remove(&mut users, 0);
            if (vec_set::contains(&sale.while_list, &user) == false) {
                continue
            };

            vec_set::remove(&mut sale.while_list, &user);
        };
    }

    public entry fun pause_sale<S,R>(sale:&mut Sale<S,R>, ctx:&TxContext) {
        check_admin_(sale.admin, ctx);
        assert!(sale.paused == true, 0);

        sale.paused = false;
    }

    public entry fun open_salesale<S,R>(sale:&mut Sale<S,R>, ctx:&TxContext) {
        check_admin_(sale.admin, ctx);
        assert!(sale.paused == false, 0);

        sale.paused = true;
    }
   
    fun can_withdraw_amount_<S,R>(sale:&Sale<S,R>, user:address, clock:&Clock): (u64, u64) {
        let current_time = timestamp(clock);
        let user_asset = vec_map::get(&sale.user_assets, &user);

        if (user_asset.latest_withdrawn_time > 0) {
            assert!(current_time - user_asset.latest_withdrawn_time > Month, EWithdrawnRecently);
        };
        
        let _can_withdraw_months = 0;
        if (user_asset.latest_withdrawn_time == 0) {
            _can_withdraw_months = (current_time - sale.release_start_time) / Month;
        } else {
            _can_withdraw_months = (current_time - user_asset.latest_withdrawn_time) / Month;
        };
        assert!( _can_withdraw_months > 0, 0);
        
        let withdraw_amount = balance::value(&user_asset.amount) / (user_asset.release_total_months - user_asset.withdrawn_months) 
                                * _can_withdraw_months;
        assert!(withdraw_amount > 0, 0);

        return (withdraw_amount, _can_withdraw_months)
    }

    fun check_admin_(admin:address, ctx:&TxContext) {
        assert!(tx_context::sender(ctx) == admin, ENotAdmin);
    }

    fun timestamp(clock: &Clock): u64 {
        clock::timestamp_ms(clock)
    }
}