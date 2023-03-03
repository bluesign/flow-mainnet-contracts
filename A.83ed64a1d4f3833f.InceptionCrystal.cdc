// SPDX-License-Identifier: MIT

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract InceptionCrystal: NonFungibleToken {

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var InceptionCrystalMetadata: InceptionCrystalTemplate

  pub resource interface InceptionCrystalCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowInceptionCrystal(id: UInt64): &InceptionCrystal.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow InceptionCrystal reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct InceptionCrystalTemplate {
    pub var name: String
    pub var description: String
    access(self) var metadata: {String: String}

    pub fun getMetadata(): {String: String} {
      return self.metadata
    }

    pub fun updateMetadata(newMetadata: {String: String}) {
      pre {
        newMetadata.length != 0: "New Template metadata cannot be empty"
      }
      self.metadata = newMetadata
    }

    init(name: String, description: String, metadata: {String: String}){
      self.name = name
      self.description= description
      self.metadata = metadata
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let serialNumber: UInt64
    
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }

     pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: InceptionCrystal.InceptionCrystalMetadata.name,
            description: InceptionCrystal.InceptionCrystalMetadata.description,
            thumbnail: MetadataViews.HTTPFile(
              url: InceptionCrystal.InceptionCrystalMetadata.getMetadata()!["uri"]!
            )
          )
      }

      return nil
    }

    pub fun getNFTMetadata(): InceptionCrystalTemplate {
      return InceptionCrystal.InceptionCrystalMetadata
    }

    init(initID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.serialNumber = serialNumber
    }
  }

  pub resource Collection: InceptionCrystalCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @InceptionCrystal.NFT
      let id: UInt64 = token.id
      let oldToken <- self.ownedNFTs[id] <- token
      emit Deposit(id: id, to: self.owner?.address)
      destroy oldToken
    }

    pub fun batchWithdrawInceptionCrystals(amount: UInt64): @InceptionCrystal.Collection {
      pre {
        UInt64(self.getIDs().length) >= amount:
          "insufficient InceptionCrystal"
      }

      let keys = self.getIDs()

      let withdrawNFTVault <- InceptionCrystal.createEmptyCollection()

      var withdrawIndex = 0 as UInt64
      while withdrawIndex < amount {
        withdrawNFTVault.deposit(token: <- self.withdraw(withdrawID: keys[withdrawIndex]))
        withdrawIndex = withdrawIndex + 1
      }

      return <- (withdrawNFTVault as! @InceptionCrystal.Collection?)!
    }

    pub fun batchDeposit(collection: @Collection) {
      let keys = collection.getIDs()
      for key in keys {
        self.deposit(token: <-collection.withdraw(withdrawID: key))
      }
      destroy collection
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowInceptionCrystal(id: UInt64): &InceptionCrystal.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &InceptionCrystal.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &InceptionCrystal.NFT
      return exampleNFT as &AnyResource{MetadataViews.Resolver}
    }

    destroy() {
      destroy self.ownedNFTs
    }

    init () {
      self.ownedNFTs <- {}
    }
  }
  
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }
  

  pub resource Admin {
    pub fun mintInceptionCrystal(recipient: &{NonFungibleToken.CollectionPublic}) {
      let newNFT: @NFT <- create InceptionCrystal.NFT(initID: InceptionCrystal.totalSupply, serialNumber: InceptionCrystal.totalSupply)
      emit Minted(id: newNFT.id)
      
      recipient.deposit(token: <- newNFT)
      InceptionCrystal.totalSupply = InceptionCrystal.totalSupply + 1
    }

    pub fun updateInceptionCrystalMetadata(newMetadata: {String: String}) {
      InceptionCrystal.InceptionCrystalMetadata.updateMetadata(newMetadata: newMetadata)
    }
  }


  pub fun getInceptionCrystalMetadata(): InceptionCrystal.InceptionCrystalTemplate {
    return InceptionCrystal.InceptionCrystalMetadata
  }

  init() {
    self.CollectionStoragePath = /storage/InceptionCrystalCollection
    self.CollectionPublicPath = /public/InceptionCrystalCollection
    self.AdminStoragePath = /storage/InceptionCrystalAdmin

    self.totalSupply = 1
    self.InceptionCrystalMetadata = InceptionCrystalTemplate(
      name: "Inception Crystal",
      description: "Inception Crystal can be used as a currency in the Inception Animals universe",
      metadata: {}
    )

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}