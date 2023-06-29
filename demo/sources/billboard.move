// Copyright (c) VMeta3 Labs, Inc.
// SPDX-License-Identifier: MIT

module demo::billboard {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID,UID};
    use sui::event;
    use std::string::{Self, String};

    struct Billboard has key {
        id: UID,
        data: String,
    }

    struct OwnerCapability has key {
        id: UID,
    }

    /// Event
    struct MintEvent has copy, drop {
        object_id: ID,
        to: address,
    }

    struct UpdateEvent has copy, drop {
        object_id: ID,
        data: String,
    }

    fun init(ctx: &mut TxContext) {
        let cap = OwnerCapability {
            id: object::new(ctx)
        };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    public entry fun mint(_: &OwnerCapability, data: vector<u8>, to: address, ctx: &mut TxContext) {
        let id = object::new(ctx);

        event::emit(MintEvent {
            object_id: object::uid_to_inner(&id),
            to,
        });

        let billboard = Billboard {
            id,
            data: string::utf8(data),
        };
        transfer::transfer(billboard, to);
    }

    public entry fun update(billboard: &mut Billboard, data: vector<u8>) {
        billboard.data = string::utf8(data);
        event::emit(UpdateEvent {
            object_id: object::id(billboard),
            data: string::utf8(data),
        });
    }

}