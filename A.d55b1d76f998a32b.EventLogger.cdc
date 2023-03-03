pub contract EventLogger {
    pub event Success(id: UInt64, dapp: String)
    pub event Failure(id: UInt64, dapp: String, reason: String)

    pub fun logSuccess(id: UInt64, dapp: String) {
        emit Success(id: id, dapp: dapp)
    }
    pub fun logFailure(id: UInt64, dapp: String, reason: String) {
        emit Failure(id: id, dapp: dapp, reason: reason)
    }
}