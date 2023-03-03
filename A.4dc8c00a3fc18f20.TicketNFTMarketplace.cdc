import NonFungibleToken from 0x1d7e57aa55817448
import TicketNFT from 0x4dc8c00a3fc18f20
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61

pub contract TicketNFTMarketplace {

  pub struct SaleItem {
    pub let price: UFix64
    
    pub let nftRef: &TicketNFT.NFT
    
    init(_price: UFix64, _nftRef: &TicketNFT.NFT) {
      self.price = _price
      self.nftRef = _nftRef
    }
  }

  pub resource interface SaleCollectionPublic {
    pub fun getIDs(): [UInt64]
    pub fun getPrice(id: UInt64): UFix64
    pub fun purchase(id: UInt64, recipientCollection: &TicketNFT.Collection{NonFungibleToken.CollectionPublic}, payment: @FlowToken.Vault)
    pub fun claimTicketNFT(id: UInt64, recipientCollection: &TicketNFT.Collection{NonFungibleToken.CollectionPublic})
  }

  pub resource SaleCollection: SaleCollectionPublic {
    pub var forSale: {UInt64: UFix64}
    pub let TicketNFTCollection: Capability<&TicketNFT.Collection>
    pub let FlowTokenVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

    pub fun listForSale(id: UInt64, price: UFix64) {
      pre {
        price >= 0.0: "It doesn't make sense to list a ticket for less than 0.0"
        self.TicketNFTCollection.borrow()!.getIDs().contains(id): "This SaleCollection owner does not have this NFT"
      }

      self.forSale[id] = price
    }

    pub fun unlistFromSale(id: UInt64) {
      self.forSale.remove(key: id)
    }

    pub fun purchase(id: UInt64, recipientCollection: &TicketNFT.Collection{NonFungibleToken.CollectionPublic}, payment: @FlowToken.Vault) {
      pre {
        payment.balance == self.forSale[id]: "The payment is not equal to the price of the NFT"
      }

      recipientCollection.deposit(token: <- self.TicketNFTCollection.borrow()!.withdraw(withdrawID: id))
      self.FlowTokenVault.borrow()!.deposit(from: <- payment)
      self.unlistFromSale(id: id)
    }

    pub fun claimTicketNFT(id: UInt64, recipientCollection: &TicketNFT.Collection{NonFungibleToken.CollectionPublic}) {
      recipientCollection.deposit(token: <- self.TicketNFTCollection.borrow()!.withdraw(withdrawID: id))
      self.unlistFromSale(id: id)
    }

    pub fun getPrice(id: UInt64): UFix64 {
      return self.forSale[id] ?? panic("Can't get the NFT price")
    }

    pub fun getIDs(): [UInt64] {
      return self.forSale.keys
    }

    init(_TicketNFTCollection: Capability<&TicketNFT.Collection>, _FlowTokenVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
      self.forSale = {}
      self.TicketNFTCollection = _TicketNFTCollection
      self.FlowTokenVault = _FlowTokenVault
    }
  }

  pub fun createSaleCollection(TicketNFTCollection: Capability<&TicketNFT.Collection>, FlowTokenVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>): @SaleCollection {
    return <- create SaleCollection(_TicketNFTCollection: TicketNFTCollection, _FlowTokenVault: FlowTokenVault)
  }

  init() {

  }
}
 