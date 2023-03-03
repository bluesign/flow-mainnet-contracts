// SPDX-License-Identifier: UNLICENSED

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Wine: NonFungibleToken {
  // Emitted when the Wine contract is created
  pub event ContractInitialized()

  // Emitted when a new Set is created
  pub event SetCreated(id: UInt64, name: String)
  // Emitted when a Set is locked, meaning Set data cannot be updated
  pub event SetLocked(id: UInt64, name: String)
  // Emitted when a Set is unlocked, meaning Set data can be updated
  pub event SetUnlocked(id: UInt64, name: String)
  // Emitted when a Set is updated
  pub event SetUpdated(id: UInt64, name: String)

  // Emitted when a new Template is created
  pub event TemplateCreated(id: UInt64, name: String)
  // Emitted when a Template is locked, meaning Template data cannot be updated
  pub event TemplateLocked(id: UInt64, name: String)
  // Emitted when a Template is updated
  pub event TemplateUpdated(id: UInt64, name: String)
  // Emitted when a Template is added to a Set
  pub event TemplateAddedToSet(id: UInt64, name: String, setID: UInt64, setName: String)

  // Emitted when an NFT is minted
  pub event Minted(id: UInt64, templateID: UInt64, setID: UInt64)
  // Emitted when an NFT is withdrawn from a Collection
  pub event Withdraw(id: UInt64, from: Address?)
  // Emitted when an NFT is deposited into a Collection
  pub event Deposit(id: UInt64, to: Address?)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath
  pub let AdminPrivatePath: PrivatePath

  // The total number of Wine NFT that have been minted
  pub var totalSupply: UInt64
  pub var nextTemplateID: UInt64
  pub var nextSetID: UInt64

  // Variable size dictionary of Template structs
  access(self) var Templates: {UInt64: Template}

  // Variable size dictionary of SetData structs
  access(self) var SetsData: {UInt64: SetData}
  
  // Variable size dictionary of Set resources
  access(self) var sets: @{UInt64: Set}

  // An Template is a Struct that holds data associated with a specific NFT
  pub struct Template {
    pub let id: UInt64

    pub var name: String
    pub var description: String
    pub var image: String

    pub var maxSupply: UInt64

    pub var locked: Bool
    pub var addedToSet: UInt64

    access(self) var metadata: {String: AnyStruct}

    init(id: UInt64, name: String, description: String, image: String, maxSupply: UInt64, metadata: {String: AnyStruct}){
      pre {
        maxSupply > 0: "Supply must be more than zero"
        metadata.length != 0: "New template metadata cannot be empty"
      }

      self.id = id
      self.name = name
      self.description = description
      self.image = image
      self.metadata = metadata
      self.maxSupply = maxSupply
      self.locked = false
      self.addedToSet = 0

      Wine.nextTemplateID = Wine.nextTemplateID + 1

      emit TemplateCreated(id: self.id, name: self.name)
    }

    pub fun updateName(newName: String) {
      pre {
        self.locked == false: "Cannot update name: template is locked"
      }

      self.name = newName
      emit TemplateUpdated(id: self.id, name: self.name)
    }

    pub fun updateDescription(newDescription: String) {
      pre {
        self.locked == false: "Cannot update description: template is locked"
      }

      self.description = newDescription
      emit TemplateUpdated(id: self.id, name: self.name)
    }

    pub fun updateImage(newImage: String) {
      pre {
        self.locked == false: "Cannot update image: template is locked"
      }

      self.image = newImage
      emit TemplateUpdated(id: self.id, name: self.name)
    }

    pub fun updateMaxSupply(newMaxSupply: UInt64) {
      pre {
        self.locked == false: "Cannot update image: template is locked"
        self.maxSupply > newMaxSupply: "Cannot reduce max supply"
      }

      self.maxSupply = newMaxSupply
      emit TemplateUpdated(id: self.id, name: self.name)
    }

    pub fun updateMetadata(newMetadata: {String: AnyStruct}) {
      pre {
        self.locked == false: "Cannot update metadata: template is locked"
        newMetadata.length != 0: "New template metadata cannot be empty"
      }

      self.metadata = newMetadata
      emit TemplateUpdated(id: self.id, name: self.name)
    }
    
    pub fun markAddedToSet(setID: UInt64) {
      pre {
        self.addedToSet == 0: "Template is already to a set"
      }

      self.addedToSet = setID

      let setName = Wine.SetsData[setID]!.name
      emit TemplateAddedToSet(id: self.id, name: self.name, setID: setID, setName: setName)
    }

    pub fun lock() {      
      pre {
        self.locked == false: "Template is already locked"
      }

      self.locked = true
      emit TemplateLocked(id: self.id, name: self.name)
    }

    pub fun getMetadata(): {String: AnyStruct} {
      return self.metadata
    }
  }

  // An SetData is a Struct that holds data associated with a specific Set
  pub struct SetData {
    pub let id: UInt64

    pub var name: String
    pub var description: String
    pub var image: String

    access(self) var metadata: {String: AnyStruct}

    init(id: UInt64, name: String, description: String, image: String, metadata: {String: AnyStruct}) {
      self.id = id
      self.name = name
      self.description = description
      self.image = image
      self.metadata = metadata
    }

    pub fun getMetadata(): {String: AnyStruct} {
      return self.metadata
    }
  }

  // A resource that represents the Wine NFT
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64

    pub let setID: UInt64
    pub let templateID: UInt64
    pub let editionNumber: UInt64
    pub let serialNumber: UInt64
    pub let mintingDate: UFix64

    init(id: UInt64, templateID: UInt64, editionNumber: UInt64, serialNumber: UInt64) {
      pre {
        Wine.getTemplate(id: templateID) != nil: "Template not found"
      }

      let setID = Wine.getTemplate(id: templateID)!.addedToSet

      self.id = id
      self.setID = setID
      self.templateID = templateID
      self.editionNumber = editionNumber
      self.serialNumber = serialNumber
      self.mintingDate = getCurrentBlock().timestamp
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Serial>(),
        Type<MetadataViews.Royalties>(),
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.Editions>(),
        Type<MetadataViews.Traits>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
        let nftName = self.getTemplate().name.concat(" #").concat(self.editionNumber.toString())
          return MetadataViews.Display(
            name: nftName,
            description: self.getTemplate().description,
            thumbnail: MetadataViews.HTTPFile(
              url: self.getTemplate().image
            )
          )
        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(
            self.serialNumber
          )
        case Type<MetadataViews.Royalties>():
          var royalties: [MetadataViews.Royalty] = []
          return MetadataViews.Royalties(royalties)
        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL(self.getExternalUrl())
        case Type<MetadataViews.Editions>():
          let template = Wine.Templates[self.templateID]!
          let editionInfo = MetadataViews.Edition(
            name: template.name,
            number: self.editionNumber,
            max: template.maxSupply
          )
          let editionList: [MetadataViews.Edition] = [editionInfo]
          return MetadataViews.Editions(
            editionList
          )
        case Type<MetadataViews.Traits>():
          let excludedTraits = ["external_base_url"]
          let traitsView = MetadataViews.dictToTraits(dict: self.getMetadata(), excludedNames: excludedTraits)

          // mintingDate is a unix timestamp, we should mark it with a displayType so platforms know how to show it
          let mintingDateTrait = MetadataViews.Trait(name: "minting_date", value: self.mintingDate, displayType: "Date", rarity: nil)
          traitsView.addTrait(mintingDateTrait)

          return traitsView
        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: Wine.CollectionStoragePath,
            publicPath: Wine.CollectionPublicPath,
            providerPath: /private/WineCollection,
            publicCollection: Type<&Wine.Collection{Wine.NFTCollectionPublic}>(),
            publicLinkedType: Type<&Wine.Collection{Wine.NFTCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&Wine.Collection{Wine.NFTCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
              return <- Wine.createEmptyCollection()
            })
          )
        case Type<MetadataViews.NFTCollectionDisplay>():
          let setData = Wine.SetsData[self.setID]!
          let squareImageUrl = setData.getMetadata()["image.media_type"] as! String?
          return MetadataViews.NFTCollectionDisplay(
            name: setData.name,
            description: setData.description,
            externalURL: MetadataViews.ExternalURL(
              url: (setData.getMetadata()["external_url"] as! String?)!
            ),
            squareImage: MetadataViews.Media(
              file: MetadataViews.HTTPFile(
                url: setData.image
              ),
              mediaType: squareImageUrl ?? "image/jpeg"
            ),
            bannerImage: MetadataViews.Media(
              file: MetadataViews.HTTPFile(
                url: (setData.getMetadata()["banner_image.url"] as! String?)!
              ),
              mediaType: (setData.getMetadata()["banner_image.media_type"] as! String?)!
            ),
            socials: {
              "twitter": MetadataViews.ExternalURL(
                url: "https://twitter.com/cuveecollective"
              ),
              "instagram": MetadataViews.ExternalURL(
                url: "https://twitter.com/cuveecollectivehq"
              ),
              "discord": MetadataViews.ExternalURL(
                url: "https://cuveecollective.com/discord"
              )
            }
          )
      }

      return nil
    }

    pub fun getSetData(): SetData {
      return Wine.SetsData[self.setID]!
    }

    pub fun getTemplate(): Template {
      return Wine.Templates[self.templateID]!
    }

    pub fun getMetadata(): {String: AnyStruct} {
      return Wine.Templates[self.templateID]!.getMetadata()
    }
    
    pub fun getExternalUrl(): String {
      let template = self.getTemplate()
      let extBaseUrl = template.getMetadata()["external_base_url"] as! String?
      return extBaseUrl!.concat("/").concat(template.id.toString())
    }
  }

  pub resource interface NFTCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowWine(id: UInt64): &Wine.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow wine reference: the ID of the returned reference is incorrect"
      }
    }
  }

  pub resource Collection: NFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @Wine.NFT
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
      let ref = &self.ownedNFTs[id] as &NonFungibleToken.NFT?
      return ref!
    }

    pub fun borrowWine(id: UInt64): &Wine.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
        return ref! as! &Wine.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
      let wineNFT = nft! as! &Wine.NFT
      return wineNFT as &AnyResource{MetadataViews.Resolver}
    }

    destroy() {
      destroy self.ownedNFTs
    }

    init() {
      self.ownedNFTs <- {}
    }
  }
  
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // A Set is special resource type that contains functions to mint Wine NFTs, 
  // add Templates, update Templates and Set metadata, and lock Sets and Templates.
  pub resource Set {
    pub let id: UInt64

    pub var locked: Bool
    pub var isPublic: Bool
    pub var nextSerialNumber: UInt64

    access(self) var templateIDs: [UInt64]
    access(self) var templateSupplies: {UInt64: UInt64}

    init(name: String, description: String, image: String, metadata: {String: AnyStruct}) {
      pre {
        metadata.length != 0: "Set metadata cannot be empty"
      }

      self.id = Wine.nextSetID

      self.locked = false
      self.isPublic = false
      self.nextSerialNumber = 1

      self.templateIDs = []
      self.templateSupplies = {}

      Wine.SetsData[self.id] = SetData(
        id: self.id,
        name: name,
        description: description,
        image: image,
        metadata: metadata
      )

      Wine.nextSetID = Wine.nextSetID + 1

      emit SetCreated(id: self.id, name: name)
    }

    pub fun updateImage(newImage: String) {
      pre {
        self.locked == false: "Cannot update image: set is locked"
      }

      let oldData = Wine.SetsData[self.id]!

      Wine.SetsData[self.id] = SetData(
        id: self.id,
        name: oldData.name,
        description: oldData.description,
        image: newImage,
        metadata: oldData.getMetadata()
      )

      emit SetUpdated(id: self.id, name: oldData.name)
    }

    pub fun updateMetadata(newMetadata: {String: AnyStruct}) {
      pre {
        self.locked == false: "Cannot update metadata: set is locked"
        newMetadata.length != 0: "New set metadata cannot be empty"
      }

      let oldData = Wine.SetsData[self.id]!

      Wine.SetsData[self.id] = SetData(
        id: self.id,
        name: oldData.name,
        description: oldData.description,
        image: oldData.image,
        metadata: newMetadata
      )

      emit SetUpdated(id: self.id, name: oldData.name)
    }

    pub fun makePublic() {
      pre {
        self.isPublic == false: "Set is already public"
      }

      self.isPublic = true
    }

    pub fun makePrivate() {
      pre {
        self.isPublic == true: "Set is already private"
      }

      self.isPublic = false
    }

    pub fun addTemplate(id: UInt64) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot add template: set is locked"
        !self.templateIDs.contains(id):
          "Cannot add template: template is already added to the set"
        !(Wine.Templates[id]!.addedToSet != 0):
          "Cannot add template: template is already added to another set"
      }

      self.templateIDs.append(id)
      self.templateSupplies[id] = 0

      // This function will automatically emit TemplateAddedToSet event
      Wine.Templates[id]!.markAddedToSet(setID: self.id)
    }

    pub fun addTemplates(templateIDs: [UInt64]) {
      for templateID in templateIDs {
        self.addTemplate(id: templateID)
      }
    }

    pub fun lock() {
      pre {
        self.locked == false: "Set is already locked"
      }

      self.locked = true
      emit SetLocked(id: self.id, name: Wine.SetsData[self.id]!.name)
    }

    pub fun unlock() {
      pre {
        self.locked == true: "Set is already unlocked"
      }

      self.locked = false
      emit SetUnlocked(id: self.id, name: Wine.SetsData[self.id]!.name)
    }

    pub fun mintNFT(templateID: UInt64): @NFT {
      let nextEditionNumber = self.templateSupplies[templateID]! + 1

      if nextEditionNumber >= Wine.Templates[templateID]!.maxSupply {
        panic("Supply unavailable")
      }

      let newNFT: @NFT <- create Wine.NFT(
        id: Wine.totalSupply + 1,
        templateID: templateID,
        editionNumber: nextEditionNumber,
        serialNumber: self.nextSerialNumber
      )
      
      Wine.totalSupply = Wine.totalSupply + 1
      self.nextSerialNumber = self.nextSerialNumber + 1
      self.templateSupplies[templateID] = self.templateSupplies[templateID]! + 1

      emit Minted(id: newNFT.id, templateID: newNFT.templateID, setID: newNFT.setID)
      return <- newNFT
    }

    pub fun updateTemplateName(id: UInt64, newName: String) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        self.templateIDs.contains(id):
          "Cannot edit template: template is not part of this set"
        !self.locked:
          "Cannot edit template: set is locked"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateName(newName: newName)
    }

    pub fun updateTemplateDescription(id: UInt64, newDescription: String) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        self.templateIDs.contains(id):
          "Cannot edit template: template is not part of this set"
        !self.locked:
          "Cannot edit template: set is locked"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateDescription(newDescription: newDescription)
    }

    pub fun updateTemplateImage(id: UInt64, newImage: String) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        self.templateIDs.contains(id):
          "Cannot edit template: template is not part of this set"
        !self.locked:
          "Cannot edit template: set is locked"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateImage(newImage: newImage)
    }

    pub fun updateTemplateMaxSupply(id: UInt64, newMaxSupply: UInt64) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        self.templateIDs.contains(id):
          "Cannot edit template: template is not part of this set"
        !self.locked:
          "Cannot edit template: set is locked"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateMaxSupply(newMaxSupply: newMaxSupply)
    }

    pub fun updateTemplateMetadata(id: UInt64, newMetadata: {String: AnyStruct}) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        self.templateIDs.contains(id):
          "Cannot edit template: template is not part of this set"
        !self.locked:
          "Cannot edit template: set is locked"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateMetadata(newMetadata: newMetadata)
    }

    pub fun lockTemplate(id: UInt64) {
      pre {
        Wine.Templates[id] != nil:
          "Template doesn't exist"
        self.templateIDs.contains(id):
          "Cannot lock template: template is not part of this set"
        !self.locked:
          "Cannot lock template: set is locked"
      }

      // This function will automatically emit TemplateLocked event
      Wine.Templates[id]!.lock()
    }

    pub fun getMetadata(): {String: AnyStruct} {
      return Wine.SetsData[self.id]!.getMetadata()
    }

    pub fun getTemplateIDs(): [UInt64] {
      return self.templateIDs
    }
  }

  pub resource Admin {
    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, setID: UInt64, templateID: UInt64) {
      let set = self.borrowSet(id: setID)
      if (set.getTemplateIDs().length == 0){
        panic("Set is empty")
      }
      recipient.deposit(token: <- set.mintNFT(templateID: templateID))
    }

    pub fun createTemplate(name: String, description: String, image: String, maxSupply: UInt64, metadata: {String: AnyStruct}): UInt64 {
      let templateID = Wine.nextTemplateID

      // This function will automatically emit TemplateCreated event
      Wine.Templates[templateID] = Template(
        id: templateID,
        name: name,
        description: description,
        image: image,
        maxSupply: maxSupply,
        metadata: metadata
      )

      return templateID
    }

    pub fun updateTemplateName(id: UInt64, newName: String) {
      pre {
        Wine.Templates.containsKey(id) != nil:
          "Template doesn't exits"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateName(newName: newName)
    }

    pub fun updateTemplateDescription(id: UInt64, newDescription: String) {
      pre {
        Wine.Templates.containsKey(id) != nil:
          "Template doesn't exits"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateDescription(newDescription: newDescription)
    }

    pub fun updateTemplateImage(id: UInt64, newImage: String) {
      pre {
        Wine.Templates.containsKey(id) != nil:
          "Template doesn't exits"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateImage(newImage: newImage)
    }

    pub fun updateTemplateMaxSupply(id: UInt64, newMaxSupply: UInt64) {
      pre {
        Wine.Templates.containsKey(id) != nil:
          "Template doesn't exits"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateMaxSupply(newMaxSupply: newMaxSupply)
    }

    pub fun updateTemplateMetadata(id: UInt64, newMetadata: {String: String}) {
      pre {
        Wine.Templates.containsKey(id) != nil:
          "Template doesn't exits"
      }

      // This function will automatically emit TemplateUpdated event
      Wine.Templates[id]!.updateMetadata(newMetadata: newMetadata)
    }

    pub fun lockTemplate(id: UInt64) {
      pre {
        Wine.Templates.containsKey(id) != nil:
          "Template doesn't exits"
      }

      // This function will automatically emit TemplateLocked event
      Wine.Templates[id]!.lock()
    }

    pub fun createSet(name: String, description: String, image: String, metadata: {String: String}) {
      var newSet <- create Set(
        name: name,
        description: description,
        image: image,
        metadata: metadata
      )
      Wine.sets[newSet.id] <-! newSet
    }

    pub fun borrowSet(id: UInt64): &Set {
      pre {
        Wine.sets[id] != nil: "Cannot borrow set: set doesn't exist"
      }
      
      let ref = &Wine.sets[id] as &Set?
      return ref!
    }

    pub fun updateSetImage(id: UInt64, newImage: String) {
      let set = self.borrowSet(id: id)
      set.updateImage(newImage: newImage)
    }

    pub fun updateSetMetadata(id: UInt64, newMetadata: {String: AnyStruct}) {
      let set = self.borrowSet(id: id)
      set.updateMetadata(newMetadata: newMetadata)
    }
  }

  pub fun getTemplate(id: UInt64): Wine.Template? {
    return self.Templates[id]
  }

  pub fun getTemplates(): {UInt64: Wine.Template} {
    return self.Templates
  }

  pub fun getSetIDs(): [UInt64] {
    return self.sets.keys
  }

  pub fun getSetData(id: UInt64): Wine.SetData? {
    return Wine.SetsData[id]
  }

  pub fun getSetsData(): {UInt64: Wine.SetData} {
    return self.SetsData
  }

  pub fun getSetSize(id: UInt64): UInt64 {
    pre {
      self.sets[id] != nil: "Cannot borrow set: set doesn't exist"
    }

    let set = &self.sets[id] as &Set?

    return set!.nextSerialNumber - 1
  }

  pub fun getTemplateIDsInSet(id: UInt64): [UInt64] {
    pre {
      self.sets[id] != nil: "Cannot borrow set: set doesn't exist"
    }

    let set = &self.sets[id] as &Set?
    return set!.getTemplateIDs()
  }

  init() {
    self.CollectionStoragePath = /storage/WineCollection
    self.CollectionPublicPath = /public/WineCollection
    self.AdminStoragePath = /storage/WineAdmin
    self.AdminPrivatePath = /private/WineAdminUpgrade

    self.totalSupply = 0
    self.nextTemplateID = 1
    self.nextSetID = 1
    self.sets <- {}

    self.SetsData = {}
    self.Templates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    self.account.link<&Wine.Admin>(
      self.AdminPrivatePath,
      target: self.AdminStoragePath
    ) ?? panic("Could not get a capability to the admin")

    emit ContractInitialized()
  }
}
 