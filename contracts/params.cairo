
# The maximum amount of each token that belongs to the AMM.
const BALANCE_UPPER_BOUND = 2 ** 64

const TOKEN_TYPE_A = 1
const TOKEN_TYPE_B = 2

# Ensure the user's balances are much smaller than the pool's balance.
const PAIR_UPPER_BOUND = 2 ** 16
const ACCOUNT_BALANCE_BOUND = 1073741  # 2**30 // 1000.

# The maximum precision of each token amount.
const TOKEN_MAX_PRECISION = 18