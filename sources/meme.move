module hop::meme;

use hop::{connector, events, math};
use std::u64;
use sui::{
    balance::,
    coin::{Self, Coin},
    dynamic_field,
    sui::SUI,
    transfer::Receiving
};

public struct AdminCap has store, key {
    id: UID,
}

public struct MemeConfig has key {
    id: UID,
    version: u64,
    is_create_enabled: bool,
    minimum_version: u64,
    virtual_sui_amount: u64,
    curve_supply: u64,
    listing_fee: u64,
    swap_fee_bps: u64,
    migration_fee: u64,
    treasury: address,
}

public struct BondingCurve<phantom MemeCoin> has key {
    id: UID,
    sui_balance: Balance<SUI>,
    virtual_sui_amount: u64,
    token_balance: Balance<MemeCoin>,
    available_token_reserves: u64,
    creator: address,
    curve_type: u8,
    status: u8,
}

public struct MEME has drop {}

public struct MigrateReceipt {
    curve_id: ID,
}

public struct DevOrder has store {
    buy_coin: Coin<SUI>,
    token_amount: u64,
}

fun init(_: MEME, ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };

    transfer::public_transfer(admin_cap, tx_context::sender(ctx));

    let config = MemeConfig {
        id: object::new(ctx),
        version: 0,
        is_create_enabled: false,
        minimum_version: 0,
        virtual_sui_amount: 1500000000000,
        curve_supply: 800000000000000,
        listing_fee: 5000000000,
        swap_fee_bps: 200,
        migration_fee: 300000000000,
        treasury: @0xa5f11d742bb442732149129297564b121a9e7da0be214817ef75814af30c47fd,
    };

    transfer::share_object(config);
}

public fun accept_connector<MemeCoin>(
    config: &mut MemeConfig,
    connector_receiving: Receiving<connector::Connector<MemeCoin>>,
    ctx: &mut TxContext,
) {
    enforce_config_version(config);

    let connector = transfer::public_receive(
        &mut config.id,
        connector_receiving,
    );

    let creator = connector::get_creator(&connector);
    let temp_id = connector::get_temp_id(&connector);

    assert!(dynamic_field::exists_(&config.id, temp_id), 7);

    let DevOrder {
        buy_coin,
        token_amount,
    } = dynamic_field::remove(&mut config.id, temp_id);

    assert!(connector::get_supply(&connector) == 0, 6);
    assert!(connector::get_decimals(&connector) == 6, 3);

    let mut bonding_curve = create_bonding_curve(connector, config, ctx);

    if (coin::value(&buy_coin) > 0) {
        let (sui_coin, token_coin) = buy_returns_internal(
            &mut bonding_curve,
            config,
            buy_coin,
            token_amount,
            token_amount,
            creator,
            true,
            ctx,
        );

        delete_or_return(sui_coin, creator);
        transfer::public_transfer(token_coin, creator);
    } else {
        coin::destroy_zero(buy_coin);
    };

    transfer::share_object(bonding_curve);
}

public entry fun buy<MemeCoin>(
    bonding_curve: &mut BondingCurve<MemeCoin>,
    config: &MemeConfig,
    buy_coin: Coin<SUI>,
    token_amount: u64,
    min_token_amount: u64,
    sender: address,
    ctx: &mut TxContext,
) {
    let (sui_coin, token_coin) = buy_returns(
        bonding_curve,
        config,
        buy_coin,
        token_amount,
        min_token_amount,
        sender,
        ctx,
    );

    delete_or_return(sui_coin, sender);
    transfer::public_transfer(token_coin, sender);
}

public fun buy_returns<MemeCoin>(
    bonding_curve: &mut BondingCurve<MemeCoin>,
    config: &MemeConfig,
    buy_coin: Coin<SUI>,
    token_amount: u64,
    min_token_amount: u64,
    sender: address,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<MemeCoin>) {
    buy_returns_internal(
        bonding_curve,
        config,
        buy_coin,
        token_amount,
        min_token_amount,
        sender,
        false,
        ctx,
    )
}

fun buy_returns_internal<MemeCoin>(
    bonding_curve: &mut BondingCurve<MemeCoin>,
    config: &MemeConfig,
    mut buy_coin: Coin<SUI>,
    mut token_amount: u64,
    min_token_amount: u64,
    sender: address,
    is_dev_buy: bool,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<MemeCoin>) {
    enforce_config_version(config);
    assert!(bonding_curve.status == 0, 1);
    assert!(min_token_amount <= token_amount, 10);

    let bonding_token_balance = balance::value(&bonding_curve.token_balance);

    let bonding_sui_balance =
        bonding_curve.virtual_sui_amount + balance::value(&bonding_curve.sui_balance);

    token_amount =
        u64::min(token_amount, bonding_curve.available_token_reserves);

    let mut amount_in = math::get_amount_in(
        token_amount,
        bonding_sui_balance,
        bonding_token_balance,
    );

    let mut fee = math::get_fee_amount(
        amount_in,
        config.swap_fee_bps,
    );

    if (coin::value(&buy_coin) < amount_in + fee) {
        fee =
            math::get_fee_amount(
                coin::value(&buy_coin),
                config.swap_fee_bps,
            );

        amount_in = coin::value(&buy_coin) - fee;

        let amount_out = math::get_amount_out(
            amount_in,
            bonding_sui_balance,
            bonding_token_balance,
        );

        token_amount = amount_out;
        assert!(amount_out >= min_token_amount, 2);
    };

    transfer::public_transfer(
        coin::split(&mut buy_coin, fee, ctx),
        config.treasury,
    );

    coin::put(
        &mut bonding_curve.sui_balance,
        coin::split(&mut buy_coin, amount_in, ctx),
    );

    let token_coin = coin::take(
        &mut bonding_curve.token_balance,
        token_amount,
        ctx,
    );

    bonding_curve.available_token_reserves =
        bonding_curve.available_token_reserves - coin::value(&token_coin);
    if (bonding_curve.available_token_reserves == 0) {
        bonding_curve.status = 2;
        events::emit_complete<MemeCoin>(get_id(bonding_curve));
    };

    events::emit_buy<MemeCoin>(
        get_id(bonding_curve),
        amount_in + fee,
        token_amount,
        get_price_per_token_scaled(bonding_curve),
        get_price_per_token_scaled(bonding_curve),
        sender,
        is_dev_buy,
        bonding_curve.virtual_sui_amount,
        balance::value(&bonding_curve.sui_balance),
        balance::value(&bonding_curve.token_balance),
        bonding_curve.available_token_reserves,
    );

    (buy_coin, token_coin)
}

public fun complete_migrate<MemeCoin>(
    _: &AdminCap,
    migrate_receipt: MigrateReceipt,
    to_pool_id: ID,
) {
    let MigrateReceipt { curve_id } = migrate_receipt;
    events::emit_migrate<MemeCoin>(curve_id, to_pool_id);
}

fun create_bonding_curve<MemeCoin>(
    connector: connector::Connector<MemeCoin>,
    config: &MemeConfig,
    ctx: &mut TxContext,
): BondingCurve<MemeCoin> {
    enforce_config_version(config);
    connector::get_creator(&connector);

    let (
        id,
        mut treasury_cap,
        metadata,
        creator,
        twitter,
        website,
        telegram,
    ) = connector::deconstruct(connector);

    object::delete(id);

    let bonding_curve = BondingCurve {
        id: object::new(ctx),
        sui_balance: balance::zero<SUI>(),
        virtual_sui_amount: config.virtual_sui_amount,
        token_balance: coin::mint_balance(
            &mut treasury_cap,
            1000000000000000,
        ),
        available_token_reserves: config.curve_supply,
        creator,
        curve_type: 0,
        status: 0,
    };

    events::emit_curve_create<MemeCoin>(
        get_id(&bonding_curve),
        creator,
        coin::get_name(&metadata),
        coin::get_symbol(&metadata),
        coin::get_description(&metadata),
        coin::get_icon_url(&metadata),
        twitter,
        website,
        telegram,
    );

    transfer::public_freeze_object(treasury_cap);
    transfer::public_freeze_object(metadata);

    bonding_curve
}

public fun delete_or_return<MemeCoin>(
    coin: Coin<MemeCoin>,
    recipient: address,
) {
    if (coin::value<MemeCoin>(&coin) == 0) {
        coin::destroy_zero<MemeCoin>(coin);
    } else {
        transfer::public_transfer<Coin<MemeCoin>>(coin, recipient);
    };
}

fun enforce_config_version(config: &MemeConfig) {
    assert!(0 >= config.minimum_version, 0);
}

public fun get_id<MemeCoin>(bonding_curve: &BondingCurve<MemeCoin>): ID {
    object::uid_to_inner(&bonding_curve.id)
}

fun get_price_per_token_scaled<MemeCoin>(
    bonding_curve: &BondingCurve<MemeCoin>,
): u64 {
    if (balance::value(&bonding_curve.token_balance) == 0) {
        return 0
    };
    (
        ((bonding_curve.virtual_sui_amount + balance::value(&bonding_curve.sui_balance)) as u128) * 1000000000 / (balance::value(&bonding_curve.token_balance) as u128),
    ) as u64
}

public fun place_dev_order(
    config: &mut MemeConfig,
    temp_id: u64,
    mut sui_in: Coin<SUI>,
    token_amount: u64,
    ctx: &mut TxContext,
) {
    enforce_config_version(config);
    assert!(config.is_create_enabled, 9);

    assert!(!dynamic_field::exists_(&config.id, temp_id), 8);

    let amount_in = math::get_amount_in(
        token_amount,
        config.virtual_sui_amount,
        1000000000000000,
    );

    let fee = math::get_fee_amount(
        amount_in,
        config.swap_fee_bps,
    );

    assert!(coin::value(&sui_in) >= config.listing_fee + amount_in + fee, 5);

    if (config.listing_fee > 0) {
        transfer::public_transfer(
            coin::split(&mut sui_in, config.listing_fee, ctx),
            config.treasury,
        );
    };

    let dev_order = DevOrder {
        buy_coin: coin::split(&mut sui_in, amount_in + fee, ctx),
        token_amount,
    };

    delete_or_return(sui_in, tx_context::sender(ctx));

    dynamic_field::add(&mut config.id, temp_id, dev_order);
}

public entry fun sell<MemeCoin>(
    bonding_curve: &mut BondingCurve<MemeCoin>,
    config: &MemeConfig,
    token_coin: Coin<MemeCoin>,
    sui_amount: u64,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(
        sell_returns(bonding_curve, config, token_coin, sui_amount, ctx),
        tx_context::sender(ctx),
    );
}

public fun sell_returns<MemeCoin>(
    bonding_curve: &mut BondingCurve<MemeCoin>,
    config: &MemeConfig,
    token_coin: Coin<MemeCoin>,
    min_sui_amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    enforce_config_version(config);
    assert!(bonding_curve.status == 0, 1);

    let token_amount = coin::value(&token_coin);
    let amount_out = math::get_amount_out(
        token_amount,
        balance::value(&bonding_curve.token_balance),
        bonding_curve.virtual_sui_amount + balance::value(&bonding_curve.sui_balance),
    );

    bonding_curve.available_token_reserves =
        bonding_curve.available_token_reserves + token_amount;

    coin::put(&mut bonding_curve.token_balance, token_coin);

    let mut sui_coin = coin::take(
        &mut bonding_curve.sui_balance,
        amount_out,
        ctx,
    );

    transfer::public_transfer(
        coin::split(
            &mut sui_coin,
            math::get_fee_amount(
                amount_out,
                config.swap_fee_bps,
            ),
            ctx,
        ),
        config.treasury,
    );

    assert!(coin::value(&sui_coin) >= min_sui_amount, 2);

    events::emit_sell<MemeCoin>(
        get_id(bonding_curve),
        coin::value(&sui_coin),
        token_amount,
        get_price_per_token_scaled(bonding_curve),
        get_price_per_token_scaled(bonding_curve),
        bonding_curve.virtual_sui_amount,
        balance::value(&bonding_curve.sui_balance),
        balance::value(&bonding_curve.token_balance),
        bonding_curve.available_token_reserves,
    );

    sui_coin
}

public fun set_create_enabled(
    _: &AdminCap,
    config: &mut MemeConfig,
    is_create_enabled: bool,
) {
    enforce_config_version(config);
    config.is_create_enabled = is_create_enabled;
}

public fun start_migrate<MemeCoin>(
    _: &AdminCap,
    config: &MemeConfig,
    bonding_curve: &mut BondingCurve<MemeCoin>,
    ctx: &mut TxContext,
): (Coin<MemeCoin>, Coin<SUI>, MigrateReceipt) {
    enforce_config_version(config);
    assert!(bonding_curve.status == 2, 1);

    bonding_curve.status = 3;

    let sui_balance = balance::value(&bonding_curve.sui_balance);

    let mut sui_coin = coin::take(
        &mut bonding_curve.sui_balance,
        sui_balance,
        ctx,
    );

    transfer::public_transfer(
        coin::split(&mut sui_coin, config.migration_fee, ctx),
        config.treasury,
    );

    let migrate_receipt = MigrateReceipt {
        curve_id: get_id(bonding_curve),
    };

    let token_balance = balance::value(&bonding_curve.token_balance);

    (
        coin::take(
            &mut bonding_curve.token_balance,
            token_balance,
            ctx,
        ),
        sui_coin,
        migrate_receipt,
    )
}

public fun update_listing_fee(
    _: &AdminCap,
    config: &mut MemeConfig,
    listing_fee: u64,
) {
    enforce_config_version(config);
    config.listing_fee = listing_fee;
}

public fun update_migration_fee(
    _: &AdminCap,
    config: &mut MemeConfig,
    migration_fee: u64,
) {
    enforce_config_version(config);
    config.migration_fee = migration_fee;
}

public fun update_minimum_version(
    _: &AdminCap,
    config: &mut MemeConfig,
    minimum_version: u64,
) {
    enforce_config_version(config);
    assert!(minimum_version >= config.minimum_version, 0);
    config.minimum_version = minimum_version;
}

public fun update_swap_fee_bps(
    _: &AdminCap,
    config: &mut MemeConfig,
    swap_fee_bps: u64,
) {
    enforce_config_version(config);
    assert!(swap_fee_bps < 10000, 4);
    config.swap_fee_bps = swap_fee_bps;
}

public fun update_treasury(
    _: &AdminCap,
    config: &mut MemeConfig,
    treasury: address,
) {
    enforce_config_version(config);
    config.treasury = treasury;
}

public fun update_virtual_sui_amount(
    _: &AdminCap,
    config: &mut MemeConfig,
    virtual_sui_amount: u64,
) {
    enforce_config_version(config);

    config.virtual_sui_amount = virtual_sui_amount;
}
