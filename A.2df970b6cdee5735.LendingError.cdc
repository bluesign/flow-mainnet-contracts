/**

# Common lending errors

# Author: Increment Labs

*/
pub contract LendingError {
    pub enum ErrorCode: UInt8 {
        pub case NO_ERROR
        /// Pool related:
        pub case INVALID_PARAMETERS
        pub case INVALID_USER_CERTIFICATE
        pub case INVALID_POOL_CERTIFICATE
        pub case CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
        pub case CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY // 5
        pub case CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
        pub case POOL_INITIALIZED
        pub case EMPTY_FUNGIBLE_TOKEN_VAULT
        pub case MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
        pub case INSUFFICIENT_POOL_LIQUIDITY // 10
        pub case REDEEM_FAILED_NO_ENOUGH_LP_TOKEN
        pub case SAME_LIQUIDATOR_AND_BORROWER
        pub case EXTERNAL_SEIZE_FROM_SELF
        pub case EXCEED_TOTAL_RESERVES
        /// Comptroller:
        pub case ADD_MARKET_DUPLICATED // 15
        pub case ADD_MARKET_NO_ORACLE_PRICE
        pub case UNKNOWN_MARKET
        pub case MARKET_NOT_OPEN
        pub case REDEEM_NOT_ALLOWED_POSITION_UNDER_WATER
        pub case BORROW_NOT_ALLOWED_EXCEED_BORROW_CAP // 20
        pub case BORROW_NOT_ALLOWED_POSITION_UNDER_WATER
        pub case LIQUIDATION_NOT_ALLOWED_SEIZE_MORE_THAN_BALANCE
        pub case LIQUIDATION_NOT_ALLOWED_POSITION_ABOVE_WATER
        pub case LIQUIDATION_NOT_ALLOWED_TOO_MUCH_REPAY
        pub case SUPPLY_NOT_ALLOWED_EXCEED_SUPPLY_CAP
    }

    pub fun ErrorEncode(msg: String, err: ErrorCode): String {
        return "[IncErrorMsg:".concat(msg).concat("]").concat(
               "[IncErrorCode:").concat(err.rawValue.toString()).concat("]")
    }
    
    init() {
    }
}