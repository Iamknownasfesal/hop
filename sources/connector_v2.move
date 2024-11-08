module hop::connector_v2;

use hop::events;
use std::string::String;
use sui::{balance::Balance, coin, url};

public struct ConnectorV2<phantom MemeCoin> has store, key {
    id: UID,
    temp_id: u64,
    supply: Balance<MemeCoin>,
    twitter: String,
    website: String,
    telegram: String,
    creator: address,
}

#[allow(lint(share_owned))]
public fun new<MemeCoin: drop>(
    otw: MemeCoin,
    temp_id: u64,
    symbol: vector<u8>,
    name: vector<u8>,
    description: vector<u8>,
    url: vector<u8>,
    twitter: String,
    website: String,
    telegram: String,
    creator: address,
    ctx: &mut TxContext,
) {
    let (mut treasury_cap, metadata) = coin::create_currency<MemeCoin>(
        otw,
        6,
        name,
        symbol,
        description,
        option::some(url::new_unsafe_from_bytes(url)),
        ctx,
    );

    transfer::public_share_object(metadata);

    let connector = ConnectorV2<MemeCoin> {
        id: object::new(ctx),
        temp_id,
        supply: coin::into_balance<MemeCoin>(
            coin::mint(&mut treasury_cap, 1000000000000000, ctx),
        ),
        twitter,
        website,
        telegram,
        creator,
    };

    events::emit_connector_create<MemeCoin>(get_id(&connector));

    transfer::public_freeze_object(treasury_cap);

    transfer::public_transfer(
        connector,
        @0xfa6d14378e545d7da62d15f7f1b5ac26ed9b2d7ffa6b232b245ffe7645591e91,
    );
}

public(package) fun deconstruct<MemeCoin>(
    connector: ConnectorV2<MemeCoin>,
): (UID, Balance<MemeCoin>, String, String, String, address) {
    let ConnectorV2 {
        id,
        supply,
        twitter,
        website,
        telegram,
        creator,
        ..,
    } = connector;

    (id, supply, twitter, website, telegram, creator)
}

public fun get_creator<MemeCoin>(connector: &ConnectorV2<MemeCoin>): address {
    connector.creator
}

public fun get_id<MemeCoin>(connector: &ConnectorV2<MemeCoin>): ID {
    object::uid_to_inner(&connector.id)
}

public fun get_temp_id<MemeCoin>(connector: &ConnectorV2<MemeCoin>): u64 {
    connector.temp_id
}
