module hop::math;

public(package) fun find_amount_with_fee(amount: u64, fee_bps: u64): u64 {
    (((amount * 10000) as u128) / ((10000 - fee_bps) as u128)) as u64
}

public(package) fun get_amount_in(
    token_amount: u64,
    bonding_sui_balance: u64,
    bonding_token_balance: u64,
): u64 {
    (
        (bonding_sui_balance as u128) * (token_amount as u128) / ((bonding_token_balance - token_amount) as u128),
    ) as u64
}

public(package) fun get_amount_out(
    token_amount: u64,
    bonding_sui_balance: u64,
    bonding_token_balance: u64,
): u64 {
    (
        (token_amount as u128) * (bonding_sui_balance as u128) / ((bonding_token_balance + token_amount as u128) as u128),
    ) as u64
}

public(package) fun get_fee_amount(amount: u64, fee_bps: u64): u64 {
    ((amount as u128) * (fee_bps as u128) / 10000) as u64
}
