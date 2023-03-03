/**

# Common staking errors

# Author: Increment Labs

*/
pub contract StakingError {
  pub enum ErrorCode: UInt8 {
    pub case NO_ERROR
    
    pub case INVALID_PARAMETERS
    pub case WHITE_LIST_EXIST
    pub case EXCEEDED_AMOUNT_LIMIT
    pub case INSUFFICIENT_REWARD_BALANCE  // 5
    pub case SAME_BOOL_STATE
    pub case POOL_LIFECYCLE_ERROR
    pub case INVALID_USER_CERTIFICATE
    pub case MISMATCH_VAULT_TYPE
    pub case ACCESS_DENY  // 10
    pub case INSUFFICIENT_BALANCE
    pub case INVALID_BALANCE_AMOUNT
    pub case NOT_FOUND
    pub case NOT_ELIGIBLE
  }

  pub fun errorEncode(msg: String, err: ErrorCode): String {
    return "[IncStakingErrorMsg:".concat(msg).concat("]").concat("[IncStakingErrorCode:").concat(err.rawValue.toString()).concat("]")
  }
}