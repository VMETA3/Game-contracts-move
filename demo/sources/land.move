module demo::land {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use sui::url::{Self, Url};
    use sui::vec_map::{Self, VecMap};
    use sui::event;
    use sui::clock::{Self, Clock};
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
    struct Noteboard has key {
        id: UID,
        balance: u64,
        enable_mint_status: bool,
        enable_mint_request_time: u64,
        active_condition: u64,
        active_condition_request_time: u64,
        minimum_injection_quantity: u64,
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
    
    fun init(ctx: &mut TxContext) {
        let note = Noteboard {
            id: object::new(ctx),
            balance: 0,
            enable_mint_status: true,
            enable_mint_request_time: 0,
            active_condition: 100000000000,
            active_condition_request_time: 0,
            minimum_injection_quantity: 1000000000,
        };

        transfer::share_object(note);
    }

    public entry fun mint(to: address, token_uri: vector<u8>, ctx: &mut TxContext) {
        let uri_str = ascii::string(token_uri);
        let land = Land {
            id: object::new(ctx),
            token_uri: url::new_unsafe(uri_str),
            status: false,
            condition: 100000000000,
            total: 0,
            injection_details: vec_map::empty(),
        };
        transfer::transfer(land, to);
    }

    public entry fun inject_active(land: &mut Land, _account: address) {
        let active = 100000000000;
        land.status = true;

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

    public fun get_enable_mint_status(clock: &Clock, note: &Noteboard): bool {
        let new_enable_mint_status = note.enable_mint_status;
        let enable_mint_request_time = note.enable_mint_request_time;
        if (new_enable_mint_status == true && clock::timestamp_ms(clock) > enable_mint_request_time + 2 * 24 * 60 * 60 * 1000) {
            true
        } else {
            note.enable_mint_status
        }
    }

    public fun get_active_condition(clock: &Clock, note: &Noteboard): u64 {
        let new_active_condition = note.active_condition;
        let active_condition_request_time = note.active_condition_request_time;
        if (new_active_condition > 0 && clock::timestamp_ms(clock) > active_condition_request_time + 2 * 24 * 60 * 60 * 1000) {
            new_active_condition
        } else {
            note.active_condition
        }
    }

    public entry fun enable_mint(clock: &Clock, note: &mut Noteboard) {
        assert!(!get_enable_mint_status(clock, note), EMintingAlreadyEnabled);
        note.enable_mint_request_time = clock::timestamp_ms(clock);
        note.enable_mint_status = true;
    }

    public entry fun disable_mint(clock: &Clock, note: &mut Noteboard) {
        assert!(get_enable_mint_status(clock, note), EMintingAlreadyDisabled);
        note.enable_mint_status = false;
    }

    public entry fun set_active_condition(clock: &Clock, note: &mut Noteboard, new_active_condition: u64) {
        let old_active_condition = get_active_condition(clock, note);
        assert!(new_active_condition > old_active_condition, EActiveValueIsZero);

        note.active_condition = old_active_condition;
        note.active_condition_request_time = clock::timestamp_ms(clock);
    }
}