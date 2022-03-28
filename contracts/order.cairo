from contracts.account import account_balance, modify_account_balance, get_account_token_balance
from contracts.params import TOKEN_MAX_PRECISION
from starkware.cairo.common.math import assert_le, assert_nn_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_not_zero

# A map from account and slot type to the corresponding tidy-order of that account.
@storage_var
func account_order(account_id : felt, slot_num : felt) -> (order : StoredOrder):
end

# A map from account and slot type to the corresponding nonce of that account.
@storage_var
func account_nonce(account_id : felt, slot_num : felt) -> (nonce : felt):
end

# Basic element of atomic swap .
struct Order:
    member account_id : felt
    member slot_id : felt
    member nonce : felt
    member base_token_id : felt
    member quote_token_id : felt
    member amount : felt
    member price : felt
    member is_sell : felt
end

# Be used for stored remaining order.
struct StoredOrder:
    member nonce : felt
    member residue : felt
    member hash : felt
end

func check_order{syscall_ptr : felt, range_check_ptr}(
    order : Order):
    assert_nn_le(order.quote_token_id, max_no_lp_tokens())
    assert_nn_le(order.base_token_id, max_no_lp_tokens())
    assert_nn_le(order.account_id, max_account_id())
    assert (order.is_sell - 1) * order.is_sell = 0
    assert_nn(order.price)
    assert_nn(order.amount)
    assert_nn_le(order.slot_id, MAX_ORDER_NUMBER)
    return ()
end

func verify_matching{syscall_ptr : felt, range_check_ptr}(
    maker : Order, taker : order):
    assert maker.quote_token_id = taker.quote_token_id
    assert maker.base_token_id = taker.base_token_id

    if order_matching.maker.account_id == order_matching.taker.account_id:
        assert_not_equal(maker.slot_id, taker.slot_id)
    end
    assert maker.is_sell + taker.is_sell = 1

    # normal code
    if maker.is_sell != 0:
        assert_le(maker.price, taker.price)
    else:
        assert_le(taker.price, maker.price)
    end

    # TODO: optimized code
    let (local le) = is_le(taker.price, maker.price)
    assert le + maker.is_sell = 1

    return ()
end


func verify_matching_and_accounts{syscall_ptr : felt, range_check_ptr}(
    maker : Order, taker : order
) -> ((residue1: felt,residue2: felt),(is_refresh_order1: felt,is_refresh_order2: felt)):
    verify_matching(maker=maker, taker=taker)

    let (local residue1, local refresh_order1) = check_account(maker)
    let (local residue2, local refresh_order2) = check_account(maker)

    return ((residue1=residue1,residue2=residue2),(is_refresh_order1=refresh_order1,is_refresh_order2=refresh_order2))
end


func check_account{syscall_ptr : felt, range_check_ptr}(
    order : Order) -> (residue: felt, is_refresh_order: felt):

    let (local cur_order) = account_order.read(account_id=order.account_id, slot_num=order.slot_id)

    # TODO: verify signature

    let (local not_refresh_order) = is_not_equal(order.nonce, cur_order.nonce + 1)
    if cur_order.residue == 0:
        assert order.nonce = cur_order.nonce
    else:
        # ensure order.nonce == cur_order.nonce || is_refresh_order
        let not_match_nonce = is_not_equal(order.nonce, cur_order.nonce)
        assert not_match_nonce * not_refresh_order = 0
    end

    if is_not_equal(cur_order.residue, 0)  * not_refresh_order == 0:
        let residue = order.amount
    else:
        let residue = cur_order.residue
    end

    if order.is_sell != 0:
        let necessary_amount = residue
        let token = base_token_id
    else:
        let (local precision_magnified) = 10 ** TOKEN_MAX_PRECISION;
        let necessary = residue * price / precision_magnified
        let token = order.quote_token_id
    end
    let (local balance) = account.get_balance(token)
    assert_le(necessary_amount, balance)
    return (residue=cur_order.residue, is_refresh_order=)
end


func update_stored_order{syscall_ptr : felt}(
     order : Order, actual_exchange: felt):
    let (local old_order) = account_order.read(account_id=order.account_id, slot_num=order.slot_id)
    let (local new_order): StoredOrder

    if old_order.residue == 0 || order.nonce == old_order.nonce + 1:
        new_order.residue = order.amount
        if order.nonce == old_order.nonce + 1:
            new_order.nonce = old_order.nonce + 1
        end
    end
    new_order.residue = new_order.residue - actual_exchanged
    if new_order.residue == 0 :
        new_order.nonce = new_order.nonce + 1
    end

    account_order.write(account_id=order.account_id, slot_num=order.slot_id, order=new_order)
    return ()
end