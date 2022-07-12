import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract SturdyTokens: NonFungibleToken {

  pub event ContractInitialized()
  pub event AccountInitialized()
  pub event SetCreated(setID: UInt64)
  pub event NFTTemplateCreated(templateID: UInt64, metadata: {String: String})
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, templateID: UInt64)
  pub event TemplateAddedToSet(setID: UInt64, templateID: UInt64)
  pub event TemplateLockedFromSet(setID: UInt64, templateID: UInt64)
  pub event TemplateUpdated(template: SturdyTokensTemplate)
  pub event SetLocked(setID: UInt64)
  pub event SetUnlocked(setID: UInt64)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var initialNFTID: UInt64
  pub var nextNFTID: UInt64
  pub var nextTemplateID: UInt64
  pub var nextSetID: UInt64

  access(self) var sturdyTokensTemplates: {UInt64: SturdyTokensTemplate}
  access(self) var sets: @{UInt64: Set}

  pub resource interface SturdyTokensCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowSturdyToken(id: UInt64): &SturdyTokens.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow SturdyTokens reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct SturdyTokensTemplate {
    pub let templateID: UInt64
    pub var name: String
    pub var description: String
    pub var locked: Bool
    pub var addedToSet: UInt64
    access(self) var metadata: {String: String}

    pub fun getMetadata(): {String: String} {
      return self.metadata
    }

    pub fun lockTemplate() {      
      self.locked = true
    }

    pub fun updateMetadata(newMetadata: {String: String}) {
      pre {
        newMetadata.length != 0: "New Template metadata cannot be empty"
      }
      self.metadata = newMetadata
    }
    
    pub fun markAddedToSet(setID: UInt64) {
      self.addedToSet = setID
    }

    init(templateID: UInt64, name: String, description: String, metadata: {String: String}){
      pre {
        metadata.length != 0: "New Template metadata cannot be empty"
      }

      self.templateID = templateID
      self.name = name
      self.description= description
      self.metadata = metadata
      self.locked = false
      self.addedToSet = 0

      emit NFTTemplateCreated(templateID: self.templateID, metadata: self.metadata)
    }
  }

  pub struct Royalty {
    pub let address: Address
    pub let primaryCut: UFix64
    pub let secondaryCut: UFix64
    pub let description: String

    init(address: Address, primaryCut: UFix64, secondaryCut: UFix64, description: String) {
      pre {
          primaryCut >= 0.0 && primaryCut <= 1.0 : "primaryCut value should be in valid range i.e [0,1]"
          secondaryCut >= 0.0 && secondaryCut <= 1.0 : "secondaryCut value should be in valid range i.e [0,1]"
      }
      self.address = address
      self.primaryCut = primaryCut
      self.secondaryCut = secondaryCut
      self.description = description
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let templateID: UInt64
    pub var serialNumber: UInt64
    
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Royalties>()
      ]
    }

     pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: SturdyTokens.sturdyTokensTemplates[self.templateID]!.name,
            description: SturdyTokens.sturdyTokensTemplates[self.templateID]!.description,
            thumbnail: MetadataViews.IPFSFile(
              cid: SturdyTokens.sturdyTokensTemplates[self.templateID]!.getMetadata()["imageCID"]!,
              path: nil
            )
          )
        case Type<MetadataViews.Royalties>():
          let setID = SturdyTokens.sturdyTokensTemplates[self.templateID]!.addedToSet
          let setRoyalties = SturdyTokens.getSetRoyalties(setID: setID)
          let royalties: [MetadataViews.Royalty] = []
          for royalty in setRoyalties {
            royalties.append(
              MetadataViews.Royalty(
                receiver: getAccount(royalty.address)
                    .getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver),
                cut: royalty.secondaryCut,
                description: royalty.description
              )
            )
          }
          return MetadataViews.Royalties(royalties)
      }
      return nil
    }

    pub fun getNFTMetadata(): {String: String} {
      return SturdyTokens.sturdyTokensTemplates[self.templateID]!.getMetadata()
    }

    init(initID: UInt64, initTemplateID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.templateID = initTemplateID
      self.serialNumber = serialNumber
    }
  }

  pub resource Collection: SturdyTokensCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @SturdyTokens.NFT
      let id: UInt64 = token.id
      let oldToken <- self.ownedNFTs[id] <- token
      emit Deposit(id: id, to: self.owner?.address)
      destroy oldToken
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

    pub fun borrowSturdyToken(id: UInt64): &SturdyTokens.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &SturdyTokens.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &SturdyTokens.NFT
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
    emit AccountInitialized()
    return <- create Collection()
  }

  pub resource Set {
    pub let setID: UInt64
    pub let name: String
    access(self) var templateIDs: [UInt64]
    access(self) var availableTemplateIDs: [UInt64]
    access(self) var lockedTemplates: {UInt64: Bool}
    access(self) var metadata: {String: String}
    pub var locked: Bool
    pub var nextSetSerialNumber: UInt64
    pub var isPublic: Bool
    pub var sturdyRoyaltyAddress: Address
    pub var sturdyRoyaltySecondaryCut: UFix64
    pub var artistRoyalties: [Royalty]


    init(name: String, sturdyRoyaltyAddress: Address, sturdyRoyaltySecondaryCut: UFix64) {
      self.name = name
      self.setID = SturdyTokens.nextSetID
      self.templateIDs = []
      self.lockedTemplates = {}
      self.locked = false
      self.availableTemplateIDs = []
      self.nextSetSerialNumber = 1
      self.isPublic = false
      self.sturdyRoyaltyAddress = sturdyRoyaltyAddress
      self.sturdyRoyaltySecondaryCut = sturdyRoyaltySecondaryCut
      self.artistRoyalties = []
      self.metadata = {}
      
      SturdyTokens.nextSetID = SturdyTokens.nextSetID + 1
      emit SetCreated(setID: self.setID)
    }

    pub fun getAvailableTemplateIDs(): [UInt64] {
      return self.availableTemplateIDs
    }

    pub fun makeSetPublic() {
      self.isPublic = true
    }

    pub fun makeSetPrivate() {
      self.isPublic = false
    }

    pub fun updateSturdyRoyaltyAddress(sturdyRoyaltyAddress: Address) {
      self.sturdyRoyaltyAddress = sturdyRoyaltyAddress
    }

    pub fun updateSturdyRoyaltySecondaryCut(sturdyRoyaltySecondaryCut: UFix64) {
      self.sturdyRoyaltySecondaryCut = sturdyRoyaltySecondaryCut
    }

    pub fun addArtistRoyalty(royalty: Royalty) {
      self.artistRoyalties.append(royalty)
    }

    pub fun addTemplate(templateID: UInt64, available: Bool) {
      pre {
        SturdyTokens.sturdyTokensTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot add template - set is locked"
        !self.templateIDs.contains(templateID):
          "Cannot add template - template is already added to the set"
        !(SturdyTokens.sturdyTokensTemplates[templateID]!.addedToSet != 0):
          "Cannot add template - template is already added to another set"
      }

      self.templateIDs.append(templateID)
      if available {
        self.availableTemplateIDs.append(templateID)
      }
      self.lockedTemplates[templateID] = !available
      SturdyTokens.sturdyTokensTemplates[templateID]!.markAddedToSet(setID: self.setID)

      emit TemplateAddedToSet(setID: self.setID, templateID: templateID)
    }

    pub fun addTemplates(templateIDs: [UInt64], available: Bool) {
      for template in templateIDs {
        self.addTemplate(templateID: template, available: available)
      }
    }

    pub fun lockTemplate(templateID: UInt64) {
      pre {
        self.lockedTemplates[templateID] != nil:
          "Cannot lock the template: Template is locked already!"
        !self.availableTemplateIDs.contains(templateID):
          "Cannot lock a not yet minted template!"
      }

      if !self.lockedTemplates[templateID]! {
        self.lockedTemplates[templateID] = true
        emit TemplateLockedFromSet(setID: self.setID, templateID: templateID)
      }
    }

    pub fun lockAllTemplates() {
      for template in self.templateIDs {
        self.lockTemplate(templateID: template)
      }
    }

    pub fun lock() {
      if !self.locked {
          self.locked = true
          emit SetLocked(setID: self.setID)
      }
    }

    pub fun unlock() {
      if self.locked {
          self.locked = false
          emit SetUnlocked(setID: self.setID)
      }
    }

    pub fun mintNFT(): @NFT {
      let templateID = self.availableTemplateIDs[0]
      if (SturdyTokens.sturdyTokensTemplates[templateID]!.locked) {
        panic("template is locked")
      }

      let newNFT: @NFT <- create SturdyTokens.NFT(initID: SturdyTokens.nextNFTID, initTemplateID: templateID, serialNumber: self.nextSetSerialNumber)
      
      SturdyTokens.totalSupply = SturdyTokens.totalSupply + 1
      SturdyTokens.nextNFTID = SturdyTokens.nextNFTID + 1
      self.nextSetSerialNumber = self.nextSetSerialNumber + 1
      self.availableTemplateIDs.remove(at: 0)

      emit Minted(id: newNFT.id, templateID: newNFT.templateID)

      return <-newNFT
    }

    pub fun mintNFTByTemplateID(templateID: UInt64): @NFT {
      let newNFT: @NFT <- create SturdyTokens.NFT(initID: templateID, initTemplateID: templateID, serialNumber: self.nextSetSerialNumber)
      
      SturdyTokens.totalSupply = SturdyTokens.totalSupply + 1
      self.nextSetSerialNumber = self.nextSetSerialNumber + 1
      self.lockTemplate(templateID: templateID)

      emit Minted(id: newNFT.id, templateID: newNFT.templateID)

      return <-newNFT
    }

    pub fun updateTemplateMetadata(templateID: UInt64, newMetadata: {String: String}):SturdyTokensTemplate {
      pre {
        SturdyTokens.sturdyTokensTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot edit template - set is locked"
      }

      SturdyTokens.sturdyTokensTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
      emit TemplateUpdated(template: SturdyTokens.sturdyTokensTemplates[templateID]!)
      return SturdyTokens.sturdyTokensTemplates[templateID]!
    }
  }

  pub fun getSetName(setID: UInt64): String {
    pre {
      SturdyTokens.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
    }
      
    let set = (&SturdyTokens.sets[setID] as &Set?)!
    return set.name
  }

  pub fun getSetRoyalties(setID: UInt64): [Royalty] {
    pre {
      SturdyTokens.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
    }
      
    let set = (&SturdyTokens.sets[setID] as &Set?)!
    var sturdyRoyaltyPrimaryCut: UFix64 = 1.00
    for royalty in set.artistRoyalties {
      sturdyRoyaltyPrimaryCut = sturdyRoyaltyPrimaryCut - royalty.primaryCut
    }
    let royalties = [
      Royalty(
        address: set.sturdyRoyaltyAddress,
        primaryCut: sturdyRoyaltyPrimaryCut,
        secondaryCut: set.sturdyRoyaltySecondaryCut,
        description: "Sturdy Exchange"
      )
    ]
    royalties.appendAll(set.artistRoyalties)
    return royalties
  }

  pub resource Admin {

    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, setID: UInt64) {
      let set = self.borrowSet(setID: setID)
      if (set.getAvailableTemplateIDs()!.length == 0){
        panic("Set is empty")
      }
      if (set.locked) {
        panic("Set is locked")
      }
      recipient.deposit(token: <- set.mintNFT())
    }

    pub fun createAndMintNFT(recipient: &{NonFungibleToken.CollectionPublic}, templateID: UInt64, setID: UInt64, name: String, description: String, metadata: {String: String}) {
      if SturdyTokens.sturdyTokensTemplates[SturdyTokens.nextTemplateID] != nil {
        panic("Template already exists")
      }
      SturdyTokens.sturdyTokensTemplates[templateID] = SturdyTokensTemplate(
        templateID: templateID,
        name: name,
        description: description,
        metadata: metadata
      )
      let set = self.borrowSet(setID: setID)
      set.addTemplate(templateID: templateID, available: false)
      recipient.deposit(token: <- set.mintNFTByTemplateID(templateID: templateID))
    }

    pub fun createSturdyTokensTemplate(name: String, description: String, metadata: {String: String}) {
      SturdyTokens.sturdyTokensTemplates[SturdyTokens.nextTemplateID] = SturdyTokensTemplate(
        templateID: SturdyTokens.nextTemplateID,
        name: name,
        description: description,
        metadata: metadata
      )
      SturdyTokens.nextTemplateID = SturdyTokens.nextTemplateID + 1
    }

    pub fun createSet(name: String, sturdyRoyaltyAddress: Address, sturdyRoyaltySecondaryCut: UFix64): UInt64 {
      var newSet <- create Set(name: name, sturdyRoyaltyAddress: sturdyRoyaltyAddress, sturdyRoyaltySecondaryCut: sturdyRoyaltySecondaryCut)
      let setID = newSet.setID
      SturdyTokens.sets[setID] <-! newSet
      return setID
    }

    pub fun borrowSet(setID: UInt64): &Set {
      pre {
        SturdyTokens.sets[setID] != nil:
          "Cannot borrow Set: The Set doesn't exist"
      }
      
      return (&SturdyTokens.sets[setID] as &Set?)!
    }

    pub fun updateSturdyTokensTemplate(templateID: UInt64, newMetadata: {String: String}) {
      pre {
        SturdyTokens.sturdyTokensTemplates.containsKey(templateID) != nil:
          "Template does not exists."
      }
      SturdyTokens.sturdyTokensTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
    }

    pub fun setInitialNFTID(initialNFTID: UInt64) {
      pre {
        SturdyTokens.initialNFTID == 0:
          "initialNFTID is already initialized"
      }
      SturdyTokens.initialNFTID = initialNFTID
      SturdyTokens.nextNFTID = initialNFTID
      SturdyTokens.nextTemplateID = initialNFTID
    }

  }

  pub fun getSturdyTokensTemplateByID(templateID: UInt64): SturdyTokens.SturdyTokensTemplate {
    return SturdyTokens.sturdyTokensTemplates[templateID]!
  }

  pub fun getSturdyTokensTemplates(): {UInt64: SturdyTokens.SturdyTokensTemplate} {
    return SturdyTokens.sturdyTokensTemplates
  }

  pub fun getAvailableTemplateIDsInSet(setID: UInt64): [UInt64] {
    pre {
        SturdyTokens.sets[setID] != nil:
        "Cannot borrow Set: The Set doesn't exist"
    }
    let set = (&SturdyTokens.sets[setID] as &Set?)!
    return set.getAvailableTemplateIDs()
  }

  init() {
    self.CollectionStoragePath = /storage/SturdyTokensCollection
    self.CollectionPublicPath = /public/SturdyTokensCollection
    self.AdminStoragePath = /storage/SturdyTokensAdmin

    self.totalSupply = 0
    self.nextSetID = 1
    self.initialNFTID = 0
    self.nextNFTID = 0
    self.nextTemplateID = 0
    self.sets <- {}

    self.sturdyTokensTemplates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}