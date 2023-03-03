pub contract HoodlumsMetadata {

  pub event ContractInitialized()
  pub event MetadataSetted(tokenID: UInt64, metadata: {String: String})

  pub let AdminStoragePath: StoragePath

  access(self) let metadata: {UInt64: {String: String}}
  pub var sturdyRoyaltyAddress: Address
  pub var artistRoyaltyAddress: Address
  pub var sturdyRoyaltyCut: UFix64
  pub var artistRoyaltyCut: UFix64

  pub resource Admin {
    pub fun setMetadata(tokenID: UInt64, metadata: {String: String}) {
      HoodlumsMetadata.metadata[tokenID] = metadata;
      emit MetadataSetted(tokenID: tokenID, metadata: metadata)
    }

    pub fun setSturdyRoyaltyAddress(sturdyRoyaltyAddress: Address) {
      HoodlumsMetadata.sturdyRoyaltyAddress = sturdyRoyaltyAddress;
    }

    pub fun setArtistRoyaltyAddress(artistRoyaltyAddress: Address) {
      HoodlumsMetadata.artistRoyaltyAddress = artistRoyaltyAddress;
    }

    pub fun setSturdyRoyaltyCut(sturdyRoyaltyCut: UFix64) {
      HoodlumsMetadata.sturdyRoyaltyCut = sturdyRoyaltyCut;
    }

    pub fun setArtistRoyaltyCut(artistRoyaltyCut: UFix64) {
      HoodlumsMetadata.artistRoyaltyCut = artistRoyaltyCut;
    }
  }

  pub fun getMetadata(tokenID: UInt64): {String: String}? {
    return HoodlumsMetadata.metadata[tokenID]
  }

  init() {
    self.AdminStoragePath = /storage/HoodlumsMetadataAdmin

    self.metadata = {}

    self.sturdyRoyaltyAddress = self.account.address
    self.artistRoyaltyAddress = self.account.address
    self.sturdyRoyaltyCut = 0.05
    self.artistRoyaltyCut = 0.05

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}