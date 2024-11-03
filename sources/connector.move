module hop::connector;

use hop::events;
use std::string::String;
use sui::coin::{Self, TreasuryCap, CoinMetadata};

public struct Connector<phantom MemeCoin> has store, key {
    id: UID,
    temp_id: u64,
    treasury_cap: TreasuryCap<MemeCoin>,
    metadata: CoinMetadata<MemeCoin>,
    twitter: String,
    website: String,
    telegram: String,
    creator: address,
}

public fun get_decimals<MemeCoin>(connector: &Connector<MemeCoin>): u8 {
    coin::get_decimals(&connector.metadata)
}

public fun new<MemeCoin>(
    temp_id: u64,
    treasury_cap: TreasuryCap<MemeCoin>,
    metadata: CoinMetadata<MemeCoin>,
    twitter: String,
    website: String,
    telegram: String,
    creator: address,
    ctx: &mut TxContext,
): Connector<MemeCoin> {
    let connector = Connector {
        id: object::new(ctx),
        temp_id,
        treasury_cap,
        metadata,
        twitter,
        website,
        telegram,
        creator,
    };

    events::emit_connector_create<MemeCoin>(get_id(&connector));

    connector
}

public(package) fun deconstruct<MemeCoin>(
    connector: Connector<MemeCoin>,
): (
    UID,
    TreasuryCap<MemeCoin>,
    CoinMetadata<MemeCoin>,
    address,
    String,
    String,
    String,
) {
    let Connector {
        id,
        treasury_cap,
        metadata,
        twitter,
        website,
        telegram,
        creator,
        ..,
    } = connector;
    (id, treasury_cap, metadata, creator, twitter, website, telegram)
}

public fun get_creator<MemeCoin>(connector: &Connector<MemeCoin>): address {
    connector.creator
}

public fun get_id<MemeCoin>(connector: &Connector<MemeCoin>): ID {
    object::uid_to_inner(&connector.id)
}

public fun get_supply<MemeCoin>(connector: &Connector<MemeCoin>): u64 {
    coin::total_supply(&connector.treasury_cap)
}

public fun get_temp_id<MemeCoin>(connector: &Connector<MemeCoin>): u64 {
    connector.temp_id
}
