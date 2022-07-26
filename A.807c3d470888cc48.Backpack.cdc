// SPDX-License-Identifier: UNLICENSED
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Patch from 0x807c3d470888cc48

pub contract Backpack: NonFungibleToken {

  pub event ContractInitialized()
  pub event SetCreated(setID: UInt64)
  pub event NFTTemplateCreated(templateID: UInt64, metadata: {String: String}, slots: UInt64)
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Mint(id: UInt64, templateID: UInt64)
  pub event Burn(id: UInt64)
  pub event TemplateAddedToSet(setID: UInt64, templateID: UInt64)
  pub event TemplateLockedFromSet(setID: UInt64, templateID: UInt64)
  pub event TemplateUpdated(template: BackpackTemplate)
  pub event SetLocked(setID: UInt64)
  pub event PatchAddedToBackpack(backpackId: UInt64, patchIds: [UInt64])
  pub event PatchRemovedFromBackpack(backpackId: UInt64, patchIds: [UInt64])
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var nextTemplateID: UInt64
  pub var nextSetID: UInt64

  access(self) var BackpackTemplates: {UInt64: BackpackTemplate}
  access(self) var sets: @{UInt64: Set}

  pub resource interface BackpackCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowBackpack(id: UInt64): &Backpack.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow Backpack reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct BackpackTemplate {
    pub let templateID: UInt64
    pub var name: String
    pub var description: String
    pub var locked: Bool
    pub var addedToSet: UInt64
    pub var slots: UInt64
    access(self) var metadata: {String: String}

    pub fun getMetadata(): {String: String} {
      return self.metadata
    }

    pub fun lockTemplate() {      
      self.locked = true
    }

    pub fun updateMetadata(newMetadata: {String: String}, newSlots: UInt64) {
      pre {
        newMetadata.length != 0: "New Template metadata cannot be empty"
        newSlots <= 20: "Slot cannot be more than 20"
      }
      self.metadata = newMetadata
      self.slots = newSlots
    }

    pub fun incrementSlot() {
      pre {
        self.slots + 1 <= 20:
          "reached maximum slot capacity"
      }
      self.slots = self.slots + 1
    }
    
    pub fun markAddedToSet(setID: UInt64) {
      self.addedToSet = setID
    }

    init(templateID: UInt64, name: String, description: String, metadata: {String: String}, slots: UInt64) {
      pre {
        metadata.length != 0: "New Template metadata cannot be empty"
      }

      self.templateID = templateID
      self.name = name
      self.description= description
      self.metadata = metadata
      self.slots = slots
      self.locked = false
      self.addedToSet = 0

      Backpack.nextTemplateID = Backpack.nextTemplateID + 1

      emit NFTTemplateCreated(templateID: self.templateID, metadata: self.metadata, slots: slots)
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let templateID: UInt64
    pub let serialNumber: UInt64
    access(self) let patches: @Patch.Collection

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.Royalties>()
      ]
    }

     pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: self.getNFTTemplate().name,
            description: self.getNFTTemplate().description,
            thumbnail: MetadataViews.HTTPFile(
              url: self.getNFTTemplate().getMetadata()["uri"]!
            )
          )

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL(
            url: "https://flunks.io/"
          )

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: Backpack.CollectionStoragePath,
            publicPath: Backpack.CollectionPublicPath,
            providerPath: /private/BackpackPrivateProvider,
            publicCollection: Type<&Backpack.Collection{NonFungibleToken.CollectionPublic}>(),
            publicLinkedType: Type<&Backpack.Collection{NonFungibleToken.CollectionPublic, Backpack.BackpackCollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&Backpack.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollection: (fun (): @NonFungibleToken.Collection {
              return <-Backpack.createEmptyCollection()
            }),
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(
              url: "https://storage.googleapis.com/flunks_public/website-assets/classroom.png"
            ),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "Backpack",
            description: "Backpack #onFlow",
            externalURL: MetadataViews.ExternalURL("https://flunks.io/"),
            squareImage: media,
            bannerImage: media,
            socials: {
              "twitter": MetadataViews.ExternalURL("https://twitter.com/flunks_nft")
            }
          )

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties(cutInfos: [])
      }

      return nil
    }

    pub fun getNFTTemplate(): BackpackTemplate {
      return Backpack.BackpackTemplates[self.templateID]!
    }

    access(contract) fun addPatches(patches: @Patch.Collection) {
      pre {
        UInt64(patches.getIDs().length) + UInt64(self.patches.getIDs().length) <= self.getSlots():
          "reached maximum patch capacity"
      }

      let patchIDs = patches.getIDs()

      self.patches.batchDeposit(collection: <- patches)

      emit PatchAddedToBackpack(backpackId: self.id, patchIds: patchIDs)
    }

    pub fun getSlots(): UInt64 {
      return Backpack.BackpackTemplates[self.templateID]!.slots
    }

    pub fun getPatchIds(): [UInt64] {
      return self.patches.getIDs()
    }

    pub fun getNFTMetadata(): {String: String} {
      return Backpack.BackpackTemplates[self.templateID]!.getMetadata()
    }

    access(contract) fun removePatches(patchTokenIDs: [UInt64]): @Patch.Collection {
      let removedPatches <- Patch.createEmptyCollection() as! @Patch.Collection
      
      for patchTokenId in patchTokenIDs {
        removedPatches.deposit(token: <- self.patches.withdraw(withdrawID: patchTokenId))
      }

      let patchIDs = removedPatches.getIDs()
      emit PatchRemovedFromBackpack(backpackId: self.id, patchIds: patchIDs)
      
      return <- removedPatches
    }

    init(initID: UInt64, initTemplateID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.templateID = initTemplateID
      self.serialNumber = serialNumber
      self.patches <- Patch.createEmptyCollection() as! @Patch.Collection
    }
    
    destroy() {
      destroy self.patches
      emit Burn(id: self.id)
    }
  }

  pub resource Collection: BackpackCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @Backpack.NFT
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

    pub fun borrowBackpack(id: UInt64): &Backpack.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &Backpack.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &Backpack.NFT
      return exampleNFT as &AnyResource{MetadataViews.Resolver}
    }

    pub fun addPatches(tokenID: UInt64, patches: @Patch.Collection) {
      pre {
        self.ownedNFTs.keys.contains(tokenID):
          "invalid tokenID - not in collection"
      }

      let backpackRef = self.borrowBackpack(id: tokenID)!
      backpackRef.addPatches(patches: <- patches)
    }

    pub fun removePatches(tokenID: UInt64, patchTokenIDs: [UInt64]): @Patch.Collection {
      pre {
        self.ownedNFTs.keys.contains(tokenID):
          "invalid tokenID - not in collection"
      }
      
      let backpackRef = self.borrowBackpack(id: tokenID)!
      return <- backpackRef.removePatches(patchTokenIDs: patchTokenIDs)
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

  pub resource Set {
    pub let setID: UInt64
    pub let name: String
    access(self) var templateIDs: [UInt64]
    access(self) var availableTemplateIDs: [UInt64]
    access(self) var lockedTemplates: {UInt64: Bool}
    pub var locked: Bool
    pub var nextSetSerialNumber: UInt64
    pub var isPublic: Bool

    init(name: String) {
      self.name = name
      self.setID = Backpack.nextSetID
      self.templateIDs = []
      self.lockedTemplates = {}
      self.locked = false
      self.availableTemplateIDs = []
      self.nextSetSerialNumber = 1
      self.isPublic = false
      
      Backpack.nextSetID = Backpack.nextSetID + 1
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

    pub fun addTemplate(templateID: UInt64) {
      pre {
        Backpack.BackpackTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot add template - set is locked"
        !self.templateIDs.contains(templateID):
          "Cannot add template - template is already added to the set"
        !(Backpack.BackpackTemplates[templateID]!.addedToSet != 0):
          "Cannot add template - template is already added to another set"
      }

      self.templateIDs.append(templateID)
      self.availableTemplateIDs.append(templateID)
      self.lockedTemplates[templateID] = false
      Backpack.BackpackTemplates[templateID]!.markAddedToSet(setID: self.setID)

      emit TemplateAddedToSet(setID: self.setID, templateID: templateID)
    }

    pub fun addTemplates(templateIDs: [UInt64]) {
      for template in templateIDs {
        self.addTemplate(templateID: template)
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

    pub fun mintNFT(): @NFT {
      let templateID = self.availableTemplateIDs[0]
      if (Backpack.BackpackTemplates[templateID]!.locked) {
        panic("template is locked")
      }

      let newNFT: @NFT <- create Backpack.NFT(initID: Backpack.totalSupply, initTemplateID: templateID, serialNumber: self.nextSetSerialNumber)
      
      Backpack.totalSupply = Backpack.totalSupply + 1
      self.nextSetSerialNumber = self.nextSetSerialNumber + 1
      self.availableTemplateIDs.remove(at: 0)

      emit Mint(id: newNFT.id, templateID: newNFT.getNFTTemplate().templateID)

      return <-newNFT
    }

    pub fun updateTemplateMetadata(templateID: UInt64, newMetadata: {String: String}, newSlots: UInt64):BackpackTemplate {
      pre {
        Backpack.BackpackTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot edit template - set is locked"
      }

      Backpack.BackpackTemplates[templateID]!.updateMetadata(newMetadata: newMetadata, newSlots: newSlots)
      emit TemplateUpdated(template: Backpack.BackpackTemplates[templateID]!)
      return Backpack.BackpackTemplates[templateID]!
    }
  }

  pub resource Admin {

    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, setID: UInt64) {
      let set = self.borrowSet(setID: setID)
      if (set.getAvailableTemplateIDs()!.length == 0){
        panic("set is empty")
      }
      if (set.locked) {
        panic("set is locked")
      }
      recipient.deposit(token: <- set.mintNFT())
    }

    pub fun createBackpackTemplate(name: String, description: String, metadata: {String: String}, slots: UInt64) {
      Backpack.BackpackTemplates[Backpack.nextTemplateID] = BackpackTemplate(
        templateID:Backpack.nextTemplateID,
        name: name,
        description: description,
        metadata: metadata,
        slots: slots
      )
    }

    pub fun createSet(name: String) {
      var newSet <- create Set(name: name)
      Backpack.sets[newSet.setID] <-! newSet
    }

    pub fun borrowSet(setID: UInt64): &Set {
      pre {
        Backpack.sets[setID] != nil:
          "Cannot borrow Set: The Set doesn't exist"
      }
      
      return (&Backpack.sets[setID] as &Set?)!
    }

    pub fun updateBackpackTemplate(templateID: UInt64, newMetadata: {String: String}, newSlots: UInt64) {
      pre {
        Backpack.BackpackTemplates.containsKey(templateID) != nil:
          "Template does not exits."
      }
      Backpack.BackpackTemplates[templateID]!.updateMetadata(newMetadata: newMetadata, newSlots: newSlots)
    }

    pub fun incrementBackpackSlot(templateID: UInt64) {
      pre {
        Backpack.BackpackTemplates.containsKey(templateID) != nil:
          "Template does not exits."
      }
      Backpack.BackpackTemplates[templateID]!.incrementSlot()

      emit TemplateUpdated(template: Backpack.BackpackTemplates[templateID]!)
    }
  }

  pub fun getBackpackTemplateByID(templateID: UInt64): Backpack.BackpackTemplate {
    return Backpack.BackpackTemplates[templateID]!
  }

  pub fun getBackpackTemplates(): {UInt64: Backpack.BackpackTemplate} {
    return Backpack.BackpackTemplates
  }

  pub fun getAvailableTemplateIDsInSet(setID: UInt64): [UInt64] {
    pre {
        Backpack.sets[setID] != nil:
        "Cannot borrow Set: The Set doesn't exist"
    }
    let set = (&Backpack.sets[setID] as &Set?)!
    return set.getAvailableTemplateIDs()
  }

  init() {
    self.CollectionStoragePath = /storage/BackpackCollection
    self.CollectionPublicPath = /public/BackpackCollection
    self.AdminStoragePath = /storage/BackpackAdmin

    self.totalSupply = 0
    self.nextTemplateID = 1
    self.nextSetID = 1
    self.sets <- {}

    self.BackpackTemplates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}
 