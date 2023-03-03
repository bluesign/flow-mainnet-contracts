import NonFungibleToken from 0x1d7e57aa55817448
import ProjectR from 0xf0c30bc89c2b2a44
import FungibleToken from 0xf233dcee88fe0abe
import Rumble from 0x078f3716ca07719a

pub contract BloxmithMarketplace {
  
  pub event NFTListing(id: UInt64, amount: UFix64)
  pub event NFTPurchase(id: UInt64, new_owner: Address?)

  pub let SaleCollectionStoragePath: StoragePath
  pub let SaleCollectionPublicPath: PublicPath

  pub struct SaleItem {
    pub let price: UFix64
    
    pub let nftRef: &ProjectR.NFT
    
    init(_price: UFix64, _nftRef: &ProjectR.NFT) {
      self.price = _price
      self.nftRef = _nftRef
    }
  }

  pub resource interface SaleCollectionPublic {
    pub fun getIDs(): [UInt64]
    pub fun getPrice(id: UInt64): UFix64
    pub fun purchase(id: UInt64, newOwner: Address, recipientCollection: &ProjectR.Collection{NonFungibleToken.CollectionPublic}, payment: @Rumble.Vault)
  }

  pub resource SaleCollection: SaleCollectionPublic {
    // maps the id of the NFT --> the price of that NFT
    pub var forSale: {UInt64: UFix64}
    pub let ProjectRCollection: Capability<&ProjectR.Collection>
    pub let TokenVault: Capability<&Rumble.Vault{FungibleToken.Receiver}>

    pub fun listForSale(id: UInt64, price: UFix64) {
      pre {
        price >= 0.0: "Price must be more that 0.0"
        self.ProjectRCollection.borrow()!.getIDs().contains(id): "This SaleCollection owner does not contain this NFT"
      }
      self.forSale[id] = price
      emit NFTListing(id: id, amount: price)
    }

    pub fun unlistFromSale(id: UInt64) {
      self.forSale.remove(key: id)
    }

    pub fun purchase(id: UInt64, newOwner: Address, recipientCollection: &ProjectR.Collection{NonFungibleToken.CollectionPublic}, payment: @Rumble.Vault) {
      pre {
        payment.balance == self.forSale[id]: "The payment balance is not equal to the NFT price"
      }
      recipientCollection.deposit(token: <- self.ProjectRCollection.borrow()!.withdraw(withdrawID: id))
      self.TokenVault.borrow()!.deposit(from: <- payment)
      self.unlistFromSale(id: id)
      emit NFTPurchase(id: id, new_owner: newOwner)
    }

    pub fun getPrice(id: UInt64): UFix64 {
      return self.forSale[id]!
    }

    pub fun getIDs(): [UInt64] {
      return self.forSale.keys
    }

    init(_ProjectRCollection: Capability<&ProjectR.Collection>, _TokenVault: Capability<&Rumble.Vault{FungibleToken.Receiver}>) {
      self.forSale = {}
      self.ProjectRCollection = _ProjectRCollection
      self.TokenVault = _TokenVault
    }
  }

  pub fun createSaleCollection(ProjectRCollection: Capability<&ProjectR.Collection>, TokenVault: Capability<&Rumble.Vault{FungibleToken.Receiver}>): @SaleCollection {
    return <- create SaleCollection(_ProjectRCollection: ProjectRCollection, _TokenVault: TokenVault)
  }

  init() {
    self.SaleCollectionStoragePath = /storage/SaleCollection
    self.SaleCollectionPublicPath = /public/SaleCollection
  }
}
 