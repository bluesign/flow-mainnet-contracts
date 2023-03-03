import EmeraldPass from 0x6a07dbeb03167a13
import MetadataViews from 0x1d7e57aa55817448

// Created by Emerald City DAO for Touchstone (https://touchstone.city/)

pub contract TouchstonePurchases {

  pub let PurchasesStoragePath: StoragePath
  pub let PurchasesPublicPath: PublicPath

  pub struct Purchase {
    pub let metadataId: UInt64
    pub let display: MetadataViews.Display
    pub let contractAddress: Address
    pub let contractName: String 

    init(_metadataId: UInt64, _display: MetadataViews.Display, _contractAddress: Address, _contractName: String) {
      self.metadataId = _metadataId
      self.display = _display
      self.contractAddress = _contractAddress
      self.contractName = _contractName
    }
  }

  pub resource interface PurchasesPublic {
    pub fun getPurchases(): {UInt64: Purchase}
  }

  pub resource Purchases: PurchasesPublic {
    pub let list: {UInt64: Purchase}

    pub fun addPurchase(uuid: UInt64, metadataId: UInt64, display: MetadataViews.Display, contractAddress: Address, contractName: String) {
      self.list[uuid] = Purchase(_metadataId: metadataId, _display: display, _contractAddress: contractAddress, _contractName: contractName)
    }

    pub fun getPurchases(): {UInt64: Purchase} {
      return self.list
    }

    init() {
      self.list = {}
    }
  }

  pub fun createPurchases(): @Purchases {
    return <- create Purchases()
  }

  init() {
    self.PurchasesStoragePath = /storage/TouchstonePurchases
    self.PurchasesPublicPath = /public/TouchstonePurchases
  }

}
 