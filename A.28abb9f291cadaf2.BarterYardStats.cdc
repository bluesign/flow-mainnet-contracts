pub contract BarterYardStats {
  access(self) var minted: UInt64
  pub event ContractInitialized()


  pub fun mintedTokens(): UInt64 {
    return BarterYardStats.minted
  }

  pub fun setLastMintedToken(lastID: UInt64) {
      self.minted = lastID
  }

  access(account) fun getNextTokenId(): UInt64 {
    self.minted = self.minted + 1
    return self.minted
  }


  pub resource Admin {

  }


  init () {
    self.minted = 5500
    emit ContractInitialized()
  }
}
