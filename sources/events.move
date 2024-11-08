module hop::events;

use std::{ascii::String, string::String as StdString};
use sui::{event, url::Url};

public struct ConnectorCreated<phantom MemeCoin> has copy, drop {
    connector_id: ID,
}

public struct ConnectorCreatedV2<phantom MemeCoin> has copy, drop {
    connector_id: ID,
}

public struct BondingCurveCreated<phantom MemeCoin> has copy, drop {
    curve_id: ID,
    creator: address,
    coin_name: StdString,
    ticker: String,
    description: StdString,
    image_url: Option<Url>,
    twitter: StdString,
    website: StdString,
    telegram: StdString,
}

public struct BondingCurveBuy<phantom MemeCoin> has copy, drop {
    curve_id: ID,
    sui_amount: u64,
    token_amount: u64,
    pre_price: u64,
    post_price: u64,
    sender: address,
    is_dev_buy: bool,
    virtual_sui_amount: u64,
    post_sui_balance: u64,
    post_token_balance: u64,
    available_token_reserves: u64,
}

public struct BondingCurveSell<phantom MemeCoin> has copy, drop {
    curve_id: ID,
    sui_amount: u64,
    token_amount: u64,
    pre_price: u64,
    post_price: u64,
    virtual_sui_amount: u64,
    post_sui_balance: u64,
    post_token_balance: u64,
    available_token_reserves: u64,
}

public struct BondingCurveComplete<phantom MemeCoin> has copy, drop {
    curve_id: ID,
}

public struct BondingCurveMigrate<phantom MemeCoin> has copy, drop {
    curve_id: ID,
    to_pool_id: ID,
}

public(package) fun emit_buy<MemeCoin>(
    curve_id: ID,
    sui_amount: u64,
    token_amount: u64,
    pre_price: u64,
    post_price: u64,
    sender: address,
    is_dev_buy: bool,
    virtual_sui_amount: u64,
    post_sui_balance: u64,
    post_token_balance: u64,
    available_token_reserves: u64,
) {
    let event = BondingCurveBuy<MemeCoin> {
        curve_id,
        sui_amount,
        token_amount,
        pre_price,
        post_price,
        sender,
        is_dev_buy,
        virtual_sui_amount,
        post_sui_balance,
        post_token_balance,
        available_token_reserves,
    };

    event::emit(event);
}

public(package) fun emit_complete<MemeCoin>(curve_id: ID) {
    let event = BondingCurveComplete<MemeCoin> { curve_id };

    event::emit(event);
}

public(package) fun emit_connector_create<MemeCoin>(connector_id: ID) {
    let event = ConnectorCreated<MemeCoin> { connector_id };

    event::emit(event);
}

public(package) fun emit_connector_create_v2<MemeCoin>(connector_id: ID) {
    let event = ConnectorCreatedV2<MemeCoin> { connector_id };

    event::emit(event);
}

public(package) fun emit_curve_create<MemeCoin>(
    curve_id: ID,
    creator: address,
    coin_name: StdString,
    ticker: String,
    description: StdString,
    image_url: Option<Url>,
    twitter: StdString,
    website: StdString,
    telegram: StdString,
) {
    let event = BondingCurveCreated<MemeCoin> {
        curve_id,
        creator,
        coin_name,
        ticker,
        description,
        image_url,
        twitter,
        website,
        telegram,
    };

    event::emit(event);
}

public(package) fun emit_migrate<MemeCoin>(curve_id: ID, to_pool_id: ID) {
    let event = BondingCurveMigrate<MemeCoin> {
        curve_id,
        to_pool_id,
    };

    event::emit(event);
}

public(package) fun emit_sell<MemeCoin>(
    curve_id: ID,
    sui_amount: u64,
    token_amount: u64,
    pre_price: u64,
    post_price: u64,
    virtual_sui_amount: u64,
    post_sui_balance: u64,
    post_token_balance: u64,
    available_token_reserves: u64,
) {
    let event = BondingCurveSell<MemeCoin> {
        curve_id,
        sui_amount,
        token_amount,
        pre_price,
        post_price,
        virtual_sui_amount,
        post_sui_balance,
        post_token_balance,
        available_token_reserves,
    };

    event::emit(event);
}
