// CREATED BY: Emerald City DAO
// REASON: For the sake of love

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

pub contract Geeft: NonFungibleToken {

  pub var totalSupply: UInt64

  // Paths
  pub let CollectionPublicPath: PublicPath
  pub let CollectionStoragePath: StoragePath

  // Standard Events
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)

  // Geeft Events
  pub event GeeftCreated(id: UInt64, message: String?, createdBy: Address?, to: Address)
  pub event GeeftOpened(id: UInt64, by: Address)

  pub struct GeeftInfo {
    pub let id: UInt64
    pub let createdBy: Address?
    pub let message: String?
    pub let collections: {String: [MetadataViews.Display?]}
    pub let vaults: {String: UFix64?}
    pub let extra: {String: AnyStruct}

    init(id: UInt64, createdBy: Address?, message: String?, collections: {String: [MetadataViews.Display?]}, vaults: {String: UFix64?}, extra: {String: AnyStruct}) {
      self.id = id
      self.createdBy = createdBy
      self.message = message
      self.collections = collections
      self.vaults = vaults
      self.extra = extra
    }
  }

  pub resource CollectionContainer {
    pub let publicPath: PublicPath
    pub let storagePath: StoragePath
    pub let assets: @[{MetadataViews.Resolver}]
    pub let originalReceiverCap: Capability<&{NonFungibleToken.Receiver}>

    init(
      publicPath: PublicPath,
      storagePath: StoragePath,
      assets: @[{MetadataViews.Resolver}],
      to: Address
    ) {
      self.publicPath = publicPath
      self.storagePath = storagePath
      self.assets <- assets
      self.originalReceiverCap = getAccount(to).getCapability<&{NonFungibleToken.Receiver}>(publicPath)
    }

    pub fun send(to: Address): Bool {
      if let collection = self.getCap(to: to).borrow() {
        while self.assets.length > 0 {
          collection.deposit(token: <- (self.assets.removeFirst() as! @NonFungibleToken.NFT))
        }
        return true
      }
      return false
    }

    access(self) fun getCap(to: Address): Capability<&{NonFungibleToken.Receiver}> {
      if to == self.originalReceiverCap.address {
        return self.originalReceiverCap
      } else {
        return getAccount(to).getCapability<&{NonFungibleToken.Receiver}>(self.publicPath)
      }
    }

    pub fun getDisplays(): [MetadataViews.Display?] {
      var i = 0
      let answer: [MetadataViews.Display?] = []
      while i < self.assets.length {
        let viewResolver = &self.assets[i] as &{MetadataViews.Resolver}
        answer.append(MetadataViews.getDisplay(viewResolver))
        i = i + 1
      }

      return answer
    }

    destroy () {
      destroy self.assets
    }
  }

  pub resource VaultContainer {
    pub let receiverPath: PublicPath
    pub let storagePath: StoragePath
    pub var assets: @FungibleToken.Vault?
    pub let originalReceiverCap: Capability<&{FungibleToken.Receiver}>

    init(
      receiverPath: PublicPath,
      storagePath: StoragePath,
      assets: @FungibleToken.Vault,
      to: Address
    ) {
      self.receiverPath = receiverPath
      self.storagePath = storagePath
      self.assets <- assets
      self.originalReceiverCap = getAccount(to).getCapability<&{FungibleToken.Receiver}>(receiverPath)
    }

    pub fun send(to: Address): Bool {
      if let vault = self.getCap(to: to).borrow() {
        var assets: @FungibleToken.Vault? <- nil
        self.assets <-> assets
        vault.deposit(from: <- assets!)
        return true
      }
      return false
    }

    access(self) fun getCap(to: Address): Capability<&{FungibleToken.Receiver}> {
      if to == self.originalReceiverCap.address {
        return self.originalReceiverCap
      } else {
        return getAccount(to).getCapability<&{FungibleToken.Receiver}>(self.receiverPath)
      }
    }

    pub fun getBalance(): UFix64? {
      return self.assets?.balance
    }

    destroy () {
      destroy self.assets
    }
  }

  // This represents a Geeft
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let createdBy: Address?
    pub let message: String?
    // ex. "FLOAT" -> A bunch of FLOATs and associated information
    pub var storedCollections: @{String: CollectionContainer}
    // ex. "FlowToken" -> Stored $FLOW and associated information
    pub var storedVaults: @{String: VaultContainer}
    pub let extra: {String: AnyStruct}

    pub fun getGeeftInfo(): GeeftInfo {
      let collections: {String: [MetadataViews.Display?]} = {}
      for collectionName in self.storedCollections.keys {
        collections[collectionName] = self.storedCollections[collectionName]?.getDisplays()
      }

      let vaults: {String: UFix64?} = {}
      for vaultName in self.storedVaults.keys {
        vaults[vaultName] = self.storedVaults[vaultName]?.getBalance()
      }

      return GeeftInfo(id: self.id, createdBy: self.createdBy, message: self.message, collections: collections, vaults: vaults, extra: self.extra)
    }

    pub fun open(opener: Address): Bool {
      var completed: Bool = true
      for collectionName in self.storedCollections.keys {
         let succeeded = self.storedCollections[collectionName]?.send(to: opener)!
         if succeeded {
          destroy self.storedCollections.remove(key: collectionName)
         } else if completed {
          completed = false
         }
      }

      for vaultName in self.storedVaults.keys {
         let succeeded = self.storedVaults[vaultName]?.send(to: opener)!
         if succeeded {
          destroy self.storedVaults.remove(key: vaultName)
         } else if completed {
          completed = false
         }
      }

      return completed
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: "Geeft #".concat(self.id.toString()),
            description: self.message ?? (self.createdBy == nil ? "This is a Geeft." : "This is a Geeft created by ".concat(self.createdBy!.toString()).concat(".")),
            thumbnail: MetadataViews.HTTPFile(
              url: "https://i.imgur.com/dZxbOEa.png"
            )
          )
      }
      return nil
    }

    init(createdBy: Address?, message: String?, collections: @{String: CollectionContainer}, vaults: @{String: VaultContainer}, extra: {String: AnyStruct}) {
      self.id = self.uuid
      self.createdBy = createdBy
      self.message = message
      self.storedCollections <- collections
      self.storedVaults <- vaults
      self.extra = extra
      Geeft.totalSupply = Geeft.totalSupply + 1
    }

    destroy() {
      destroy self.storedCollections
      destroy self.storedVaults
    }
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun getGeeftInfo(geeftId: UInt64): GeeftInfo
  }

  pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let geeft <- token as! @NFT
      emit Deposit(id: geeft.id, to: self.owner?.address)
      self.ownedNFTs[geeft.id] <-! geeft
    }

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let geeft <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This Geeft does not exist in this collection.")
      emit Withdraw(id: geeft.id, from: self.owner?.address)
      return <- geeft
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    } 

    pub fun openGeeft(id: UInt64) {
      let token <- self.ownedNFTs.remove(key: id) ?? panic("This Geeft does not exist.")
      let geeft <- token as! @NFT

      let completed = geeft.open(opener: self.owner!.address)
      emit GeeftOpened(id: geeft.id, by: self.owner!.address)

      if completed {
        destroy geeft
      } else {
        self.deposit(token: <- geeft)
      }
    }

    pub fun getGeeftInfo(geeftId: UInt64): GeeftInfo {
      let ref = (&self.ownedNFTs[geeftId] as auth &NonFungibleToken.NFT?)!
      let geeft = ref as! &NFT
      return geeft.getGeeftInfo()
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let geeft = nft as! &NFT
      return geeft as &{MetadataViews.Resolver}
    }

    init() {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  pub fun sendGeeft(
    createdBy: Address?,
    message: String?, 
    collections: @{String: CollectionContainer}, 
    vaults: @{String: VaultContainer}, 
    extra: {String: AnyStruct}, 
    recipient: Address
  ) {
    let geeft <- create NFT(createdBy: createdBy, message: message, collections: <- collections, vaults: <- vaults, extra: extra)
    let collection = getAccount(recipient).getCapability(Geeft.CollectionPublicPath)
                        .borrow<&Collection{NonFungibleToken.Receiver}>()
                        ?? panic("The recipient does not have a Geeft Collection")

    emit GeeftCreated(id: geeft.id, message: message, createdBy: createdBy, to: recipient)
    collection.deposit(token: <- geeft)
  }

  pub fun createCollectionContainer(publicPath: PublicPath, storagePath: StoragePath, assets: @[{MetadataViews.Resolver}], to: Address): @CollectionContainer {
    return <- create CollectionContainer(publicPath: publicPath, storagePath: storagePath, assets: <- assets, to: to)
  }

  pub fun createVaultContainer(receiverPath: PublicPath, storagePath: StoragePath, assets: @FungibleToken.Vault, to: Address): @VaultContainer {
    return <- create VaultContainer(receiverPath: receiverPath, storagePath: storagePath, assets: <- assets, to: to)
  }

  pub fun createEmptyCollection(): @Collection {
    return <- create Collection()
  }

  init() {
    self.CollectionStoragePath = /storage/GeeftCollection
    self.CollectionPublicPath = /public/GeeftCollection

    self.totalSupply = 0

    emit ContractInitialized()
  }

}