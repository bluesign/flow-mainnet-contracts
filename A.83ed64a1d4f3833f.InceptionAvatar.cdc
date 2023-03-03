// SPDX-License-Identifier: MIT

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract InceptionAvatar: NonFungibleToken {

  pub event ContractInitialized()
  pub event SetCreated(setID: UInt64)
  pub event NFTTemplateCreated(templateID: UInt64, metadata: {String: String})
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, templateID: UInt64)
  pub event TemplateAddedToSet(setID: UInt64, templateID: UInt64)
  pub event TemplateLockedFromSet(setID: UInt64, templateID: UInt64)
  pub event TemplateUpdated(template: InceptionAvatarTemplate)
  pub event SetLocked(setID: UInt64)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var nextTemplateID: UInt64
  pub var nextSetID: UInt64

  pub var InceptionAvatarTemplates: {UInt64: InceptionAvatarTemplate}
  pub var sets: @{UInt64: Set}

  pub resource interface InceptionAvatarCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowInceptionAvatar(id: UInt64): &InceptionAvatar.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow InceptionAvatar reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct InceptionAvatarTemplate {
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

      InceptionAvatar.nextTemplateID = InceptionAvatar.nextTemplateID + 1

      emit NFTTemplateCreated(templateID: self.templateID, metadata: self.metadata)
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let templateID: UInt64
    pub let serialNumber: UInt64
    
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Serial>(),
        Type<MetadataViews.Traits>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.Royalties>(),
        Type<MetadataViews.ExternalURL>()
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
            url: "https://www.inceptionanimals.com/"
          )

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(
            self.templateID
          )
          
        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: InceptionAvatar.CollectionStoragePath,
            publicPath: InceptionAvatar.CollectionPublicPath,
            providerPath: /private/InceptionAvatarCollection,
            publicCollection: Type<&InceptionAvatar.Collection{InceptionAvatar.InceptionAvatarCollectionPublic}>(),
            publicLinkedType: Type<&InceptionAvatar.Collection{InceptionAvatar.InceptionAvatarCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&InceptionAvatar.Collection{InceptionAvatar.InceptionAvatarCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
              return <-InceptionAvatar.createEmptyCollection()
            })
          )
        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(
              url: "https://inceptionanimals.com/logo.png"
            ),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "Inception Animals",
            description: "A retro futuristic metaverse brand",
            externalURL: MetadataViews.ExternalURL("https://inceptionanimals.com/"),
            squareImage: media,
            bannerImage: media,
            socials: {
              "twitter": MetadataViews.ExternalURL("https://twitter.com/Inceptionft")
            }
          )
        case Type<MetadataViews.Traits>():
          let excludedTraits = ["mintedTime", "foo"]
          let traitsView = MetadataViews.dictToTraits(dict: self.getNFTTemplate()!.getMetadata(), excludedNames: excludedTraits)
          return traitsView

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties(cutInfos: [])
      }

      return nil
    }

    pub fun getNFTTemplate(): InceptionAvatarTemplate {
      return InceptionAvatar.InceptionAvatarTemplates[self.templateID]!
    }

    pub fun getNFTMetadata(): {String: String} {
      return InceptionAvatar.InceptionAvatarTemplates[self.templateID]!.getMetadata()
    }

    init(initID: UInt64, initTemplateID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.templateID = initTemplateID
      self.serialNumber = serialNumber
    }
  }

  pub resource Collection: InceptionAvatarCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @InceptionAvatar.NFT
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

    pub fun borrowInceptionAvatar(id: UInt64): &InceptionAvatar.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &InceptionAvatar.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &InceptionAvatar.NFT
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
      self.setID = InceptionAvatar.nextSetID
      self.templateIDs = []
      self.lockedTemplates = {}
      self.locked = false
      self.availableTemplateIDs = []
      self.nextSetSerialNumber = 1
      self.isPublic = false
      
      InceptionAvatar.nextSetID = InceptionAvatar.nextSetID + 1
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
        InceptionAvatar.InceptionAvatarTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot add template - set is locked"
        !self.templateIDs.contains(templateID):
          "Cannot add template - template is already added to the set"
        !(InceptionAvatar.InceptionAvatarTemplates[templateID]!.addedToSet != 0):
          "Cannot add template - template is already added to another set"
      }

      self.templateIDs.append(templateID)
      self.availableTemplateIDs.append(templateID)
      self.lockedTemplates[templateID] = false
      InceptionAvatar.InceptionAvatarTemplates[templateID]!.markAddedToSet(setID: self.setID)

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
      if (InceptionAvatar.InceptionAvatarTemplates[templateID]!.locked) {
        panic("template is locked")
      }

      let newNFT: @NFT <- create InceptionAvatar.NFT(initID: InceptionAvatar.totalSupply, initTemplateID: templateID, serialNumber: self.nextSetSerialNumber)
      
      InceptionAvatar.totalSupply = InceptionAvatar.totalSupply + 1
      self.nextSetSerialNumber = self.nextSetSerialNumber + 1
      self.availableTemplateIDs.remove(at: 0)

      emit Minted(id: newNFT.id, templateID: newNFT.getNFTTemplate().templateID)

      return <-newNFT
    }

    pub fun updateTemplateMetadata(templateID: UInt64, newMetadata: {String: String}):InceptionAvatarTemplate {
      pre {
        InceptionAvatar.InceptionAvatarTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot edit template - set is locked"
      }

      InceptionAvatar.InceptionAvatarTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
      emit TemplateUpdated(template: InceptionAvatar.InceptionAvatarTemplates[templateID]!)
      return InceptionAvatar.InceptionAvatarTemplates[templateID]!
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

    pub fun createInceptionAvatarTemplate(name: String, description: String, metadata: {String: String}) {
      InceptionAvatar.InceptionAvatarTemplates[InceptionAvatar.nextTemplateID] = InceptionAvatarTemplate(
        templateID:InceptionAvatar.nextTemplateID,
        name: name,
        description: description,
        metadata: metadata
      )
    }

    pub fun createSet(name: String) {
      var newSet <- create Set(name: name)
      InceptionAvatar.sets[newSet.setID] <-! newSet
    }

    pub fun borrowSet(setID: UInt64): &Set {
      pre {
        InceptionAvatar.sets[setID] != nil:
          "Cannot borrow Set: The Set doesn't exist"
      }
      
      return (&InceptionAvatar.sets[setID] as &Set?)!
    }

    pub fun updateInceptionAvatarTemplate(templateID: UInt64, newMetadata: {String: String}) {
      pre {
        InceptionAvatar.InceptionAvatarTemplates.containsKey(templateID) != nil:
          "Template does not exits."
      }
      InceptionAvatar.InceptionAvatarTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
    }
  }

  pub fun getInceptionAvatarTemplateByID(templateID: UInt64): InceptionAvatar.InceptionAvatarTemplate {
    return InceptionAvatar.InceptionAvatarTemplates[templateID]!
  }

  pub fun getInceptionAvatarTemplates(): {UInt64: InceptionAvatar.InceptionAvatarTemplate} {
    return InceptionAvatar.InceptionAvatarTemplates
  }

  pub fun getAvailableTemplateIDsInSet(setID: UInt64): [UInt64] {
    pre {
        InceptionAvatar.sets[setID] != nil:
        "Cannot borrow Set: The Set doesn't exist"
    }
    let set = (&InceptionAvatar.sets[setID] as &Set?)!
    return set.getAvailableTemplateIDs()
  }

  init() {
    self.CollectionStoragePath = /storage/InceptionAvatarCollection
    self.CollectionPublicPath = /public/InceptionAvatarCollection
    self.AdminStoragePath = /storage/InceptionAvatarAdmin

    self.totalSupply = 0
    self.nextTemplateID = 1
    self.nextSetID = 1
    self.sets <- {}

    self.InceptionAvatarTemplates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}