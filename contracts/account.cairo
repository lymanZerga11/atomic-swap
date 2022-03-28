
# A map from account and token type to the corresponding balance of that account.
@storage_var
func account_balance(account_id : felt, token_type : felt) -> (balance : felt):
end

# Adds amount to the account's balance for the given token. Amount may be positive or negative.
# Assert before setting that the balance does not exceed the upper bound.
func modify_account_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}
(
    account_id : felt, token_type : felt, amount : felt
):
    let (current_balance) = account_balance.read(account_id, token_type)
    tempvar new_balance = current_balance + amount
    assert_nn_le(new_balance, BALANCE_UPPER_BOUND - 1)
    account_balance.write(account_id=account_id, token_type=token_type, value=new_balance)
    return ()
end

# Returns the account's balance for the given token.
@view
func get_account_token_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}
(
    account_id : felt, token_type : felt
) -> (balance : felt):
    return account_balance.read(account_id, token_type)
end
