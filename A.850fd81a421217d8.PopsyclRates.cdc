// Popsycl NFT Marketplace
// Popsycl Rates contract
// Version         : 0.0.1
// Blockchain      : Flow www.onFlow.org
// Owner           : Popsycl.com    
// Developer       : RubiconFinTech.com

pub contract PopsyclRates {

  // Market operator Address 
  pub var PopsyclMarketAddress : Address
  // Market fee percentage 
  pub var PopsyclMarketplaceFees : UFix64
  // creator royality
  pub var PopsyclCreatorRoyalty : UFix64

  /// Path where the `Configs` is stored
  pub let PopsyclStoragePath: StoragePath

  pub resource Admin {
    pub fun changeRated(newOperator: Address, marketCommission: UFix64, royality: UFix64 ) {
        PopsyclRates.PopsyclMarketAddress = newOperator
        PopsyclRates.PopsyclMarketplaceFees = marketCommission
        PopsyclRates.PopsyclCreatorRoyalty = royality
    } 
  }

  init() {
    self.PopsyclMarketAddress = 0x875c9668059b74db
    // 5% Popsycl Fee
    self.PopsyclMarketplaceFees = 0.05
    // 10% Royalty reward for original creater / minter for every re-sale
    self.PopsyclCreatorRoyalty = 0.1

    self.PopsyclStoragePath = /storage/PopsyclRates

    self.account.save(<- create Admin(), to:self.PopsyclStoragePath)
  } 

}
