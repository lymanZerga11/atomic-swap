%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem
from starkware.starknet.common.syscalls import storage_read, storage_write

from contracts.order import Order, check_order, verify_matching_and_accounts, update_stored_order
from contracts.params import (
    BALANCE_UPPER_BOUND, TOKEN_TYPE_A, TOKEN_TYPE_B, PAIR_UPPER_BOUND, ACCOUNT_BALANCE_BOUND, TOKEN_MAX_PRECISION
)
from contracts.account import account_balance, modify_account_balance, get_account_token_balance

# Until we have LPs, for testing, we'll need to initialize the AMM somehow.
@external
func init_pair{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a : felt, token_b : felt):
    assert_nn_le(token_a, POOL_UPPER_BOUND - 1)
    assert_nn_le(token_b, POOL_UPPER_BOUND - 1)

    set_pool_token_balance(token_type=TOKEN_TYPE_A, balance=token_a)
    set_pool_token_balance(token_type=TOKEN_TYPE_B, balance=token_b)

    return ()
end

# Adds demo tokens to the given account.
@external
func add_demo_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account_id : felt, token : felt, amount : felt):
    # Make sure the account's balance is much smaller then atomic-swap pair init balance.
    assert_nn_le(amount, ACCOUNT_BALANCE_BOUND - 1)

    modify_account_balance(account_id=account_id, token_type=token, amount=amount)
    return ()
end

# Swaps tokens between the given account and the pool.
@external
func atomic_swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        maker : Order*, taker : Order*, submitter : felt, nonce : felt):
    # basic check and verification
    check_order(order=maker)
    check_order(order=taker)
    let (residues, is_refresh_oders) = verify_matching_and_accounts(taker=taker, maker=maker)

    do_swap(account_id=account_id, token_from=token_from, taker=taker, maker=maker)

    return ()
end

# Swaps tokens between the given account and the pool.
func do_swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    residues: (felt, felt),
    is_refresh_orders: (felt, felt),
    maker : Order*,
    taker : Order* ):

    if maker.is_sell == 0 :
        let token_1 = op.tx.maker.quote_token_id
    else:
        let token_1 = op.tx.maker.base_token_id
    end
    if taker.is_sell == 0 :
        let token_2 = op.tx.taker.quote_token_id
    else:
        let token_2 = op.tx.taker.base_token_id
    end

    # calculate exchanged amounts.
    let (local actual_exchange1, local actual_exchange2) = calculate_actual_exchanged_amounts(
        residues=residues,is_refresh_orders=is_refresh_orders, maker=maker, taker=taker)

    if maker.is_sell != 0:
        let actual_exchanged_amount = actual_exchanged_amount1
    else:
        let actual_exchanged_amount = actual_exchanged_amount2
    end

    # Update maker stored order.
    update_stored_order(order=maker, actual_exchange=actual_exchanged_amount)
    update_stored_order(account_id=account_id, token_type=token_1, amount=-actual_exchanged_amount)
    # Update maker token balances.
    update_stored_order(account_id=account_id, token_type=token_1, amount=-actual_exchange1)
    update_stored_order(account_id=account_id, token_type=token_2, amount=actual_exchange2)

    # Update taker stored order.
    update_stored_order(order=taker, actual_exchange=actual_exchanged_amount)
    update_stored_order(account_id=account_id, token_type=token_2, amount=-amount_from)
    # Update taker token balances.
    modify_account_balance(account_id=account_id, token_type=token_2, amount=-actual_exchange2)
    modify_account_balance(account_id=account_id, token_type=token_1, amount=actual_exchange1)

    return ()
end

func calculate_actual_exchanged_amounts(
    residues: (felt, felt),
    is_refresh_orders: (felt, felt),
    maker : Order*,
    taker : Order*
) ->(actual_exchanged_amount1: felt, actual_exchanged_amount2: felt) :
    let (local precision_magnified) = 10 ** TOKEN_MAX_PRECISION
    if residues[0] == 0 || is_refresh_order[0] == 1:
        let residue1 = maker.amount
    end
    if residues[1] == 0 || is_refresh_order[1] == 1:
        let residue2 = taker.amount
    end

    # maker residue value less than taker residue value
    # final price must be maker.price, maker.price
    if maker.is_sell != 0:
        if assert_le(residue1, residue2):
            let amount1 = residue1
            let amount2 = residue1
                .checked_mul(&maker.price)
                .checked_div(&precision_magnified)
        else:
            let amount1 = residue2
            let amount2 = residue2
                .checked_mul(&maker.price)
                .checked_div(&precision_magnified)
        end
    else:
        if assert_le(residue1, residue2):
            let amount1 = residue1
                .checked_mul(&maker.price)
                .checked_div(&precision_magnified)
            let amount2 = residue1
        else:
            let amount1 = residue2
                .checked_mul(&maker.price)
                .checked_div(&precision_magnified)
            let amount2 = residue2
        end
    end

    return (actual_exchanged_amount1=amount1, actual_exchanged_amount2=amount2)
end