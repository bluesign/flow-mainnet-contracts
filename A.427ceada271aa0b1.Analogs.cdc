import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Analogs: NonFungibleToken {

  pub event ContractInitialized()
  pub event AccountInitialized()
  pub event SetCreated(setID: UInt64)
  pub event NFTTemplateCreated(templateID: UInt64, metadata: {String: String})
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, templateID: UInt64)
  pub event TemplateAddedToSet(setID: UInt64, templateID: UInt64)
  pub event TemplateLockedFromSet(setID: UInt64, templateID: UInt64)
  pub event TemplateUpdated(template: AnalogsTemplate)
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

  access(self) var analogsTemplates: {UInt64: AnalogsTemplate}
  access(self) var sets: @{UInt64: Set}

  pub resource interface AnalogsCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowAnalog(id: UInt64): &Analogs.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow Analogs reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct AnalogsTemplate {
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
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Medias>(),
        Type<MetadataViews.Royalties>()
      ]
    }

     pub fun resolveView(_ view: Type): AnyStruct? {
      let metadata = Analogs.analogsTemplates[self.templateID]!.getMetadata()
      let thumbnailCID = metadata["thumbnailCID"] != nil ? metadata["thumbnailCID"]! : metadata["imageCID"]!
      switch view {
        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL("https://ipfs.io/ipfs/".concat(thumbnailCID))
        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
              storagePath: Analogs.CollectionStoragePath,
              publicPath: Analogs.CollectionPublicPath,
              providerPath: /private/AnalogsCollection,
              publicCollection: Type<&Analogs.Collection{Analogs.AnalogsCollectionPublic}>(),
              publicLinkedType: Type<&Analogs.Collection{Analogs.AnalogsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
              providerLinkedType: Type<&Analogs.Collection{Analogs.AnalogsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
              createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                  return <-Analogs.createEmptyCollection()
              })
          )
        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: "https://ipfs.io/ipfs/bafkreidhuylwtdgug3vuamphju44r7eam5wlels4tejbkz4nvelnluktcm"),
            mediaType: "image/jpeg"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "Heavy Metal Analogs",
            description: "",
            externalURL: MetadataViews.ExternalURL("https://sturdy.exchange/"),
            squareImage: media,
            bannerImage: media,
            socials: {}
          )
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: Analogs.analogsTemplates[self.templateID]!.name,
            description: Analogs.analogsTemplates[self.templateID]!.description,
            thumbnail: MetadataViews.HTTPFile(
              url: "https://ipfs.io/ipfs/".concat(thumbnailCID)
            )
          )
        case Type<MetadataViews.Medias>():
          let medias: [MetadataViews.Media] = [];
          let videoCID = Analogs.analogsTemplates[self.templateID]!.getMetadata()["videoCID"]
          let imageCID = thumbnailCID
          if videoCID != nil {
            medias.append(
              MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                  url: "https://ipfs.io/ipfs/".concat(videoCID!)
                ),
                mediaType: "video/mp4"
              )
            )
          }
          else if imageCID != nil {
            medias.append(
              MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                  url: "https://ipfs.io/ipfs/".concat(imageCID)
                ),
                mediaType: "image/jpeg"
            )
          )
          }
          return MetadataViews.Medias(medias)
        case Type<MetadataViews.Royalties>():
          let setID = Analogs.analogsTemplates[self.templateID]!.addedToSet
          let setRoyalties = Analogs.getSetRoyalties(setID: setID)
          let royalties: [MetadataViews.Royalty] = []
          for royalty in setRoyalties {
            royalties.append(
              MetadataViews.Royalty(
                receiver: getAccount(royalty.address)
                    .getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver),
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
      return Analogs.analogsTemplates[self.templateID]!.getMetadata()
    }

    init(initID: UInt64, initTemplateID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.templateID = initTemplateID
      self.serialNumber = serialNumber
    }
  }

  pub resource Collection: AnalogsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @Analogs.NFT
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

    pub fun borrowAnalog(id: UInt64): &Analogs.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &Analogs.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &Analogs.NFT
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
    pub var analogRoyaltyAddress: Address
    pub var analogRoyaltySecondaryCut: UFix64
    pub var artistRoyalties: [Royalty]


    init(name: String, analogRoyaltyAddress: Address, analogRoyaltySecondaryCut: UFix64, imageCID: String) {
      self.name = name
      self.setID = Analogs.nextSetID
      self.templateIDs = []
      self.lockedTemplates = {}
      self.locked = false
      self.availableTemplateIDs = []
      self.nextSetSerialNumber = 1
      self.isPublic = false
      self.analogRoyaltyAddress = analogRoyaltyAddress
      self.analogRoyaltySecondaryCut = analogRoyaltySecondaryCut
      self.artistRoyalties = []
      self.metadata = { "imageCID": imageCID }
      
      Analogs.nextSetID = Analogs.nextSetID + 1
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

    pub fun updateAnalogRoyaltyAddress(analogRoyaltyAddress: Address) {
      self.analogRoyaltyAddress = analogRoyaltyAddress
    }

    pub fun updateAnalogRoyaltySecondaryCut(analogRoyaltySecondaryCut: UFix64) {
      self.analogRoyaltySecondaryCut = analogRoyaltySecondaryCut
    }

    pub fun addArtistRoyalty(royalty: Royalty) {
      self.artistRoyalties.append(royalty)
    }

    pub fun addTemplate(templateID: UInt64, available: Bool) {
      pre {
        Analogs.analogsTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot add template - set is locked"
        !self.templateIDs.contains(templateID):
          "Cannot add template - template is already added to the set"
        !(Analogs.analogsTemplates[templateID]!.addedToSet != 0):
          "Cannot add template - template is already added to another set"
      }

      self.templateIDs.append(templateID)
      if available {
        self.availableTemplateIDs.append(templateID)
      }
      self.lockedTemplates[templateID] = !available
      Analogs.analogsTemplates[templateID]!.markAddedToSet(setID: self.setID)

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
      if (Analogs.analogsTemplates[templateID]!.locked) {
        panic("template is locked")
      }

      let newNFT: @NFT <- create Analogs.NFT(initID: Analogs.nextNFTID, initTemplateID: templateID, serialNumber: self.nextSetSerialNumber)
      
      Analogs.totalSupply = Analogs.totalSupply + 1
      Analogs.nextNFTID = Analogs.nextNFTID + 1
      self.nextSetSerialNumber = self.nextSetSerialNumber + 1
      self.availableTemplateIDs.remove(at: 0)

      emit Minted(id: newNFT.id, templateID: newNFT.templateID)

      return <-newNFT
    }

    pub fun mintNFTByTemplateID(templateID: UInt64): @NFT {
      let newNFT: @NFT <- create Analogs.NFT(initID: templateID, initTemplateID: templateID, serialNumber: self.nextSetSerialNumber)
      
      Analogs.totalSupply = Analogs.totalSupply + 1
      self.nextSetSerialNumber = self.nextSetSerialNumber + 1
      self.lockTemplate(templateID: templateID)

      emit Minted(id: newNFT.id, templateID: newNFT.templateID)

      return <-newNFT
    }

    pub fun updateTemplateMetadata(templateID: UInt64, newMetadata: {String: String}):AnalogsTemplate {
      pre {
        Analogs.analogsTemplates[templateID] != nil:
          "Template doesn't exist"
        !self.locked:
          "Cannot edit template - set is locked"
      }

      Analogs.analogsTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
      emit TemplateUpdated(template: Analogs.analogsTemplates[templateID]!)
      return Analogs.analogsTemplates[templateID]!
    }

    pub fun getImageCID(): String? {
      return self.metadata["imageCID"]
    }

    pub fun updateImageCID(imageCID: String) {
      self.metadata["imageCID"] = imageCID
    }
  }

  pub fun getSetName(setID: UInt64): String {
    pre {
      Analogs.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
    }
      
    let set = (&Analogs.sets[setID] as &Set?)!
    return set.name
  }

  pub fun getSetImageCID(setID: UInt64): String? {
    pre {
      Analogs.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
    }
      
    let set = (&Analogs.sets[setID] as &Set?)!
    return set.getImageCID()
  }

  pub fun getSetRoyalties(setID: UInt64): [Royalty] {
    pre {
      Analogs.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
    }
      
    let set = (&Analogs.sets[setID] as &Set?)!
    var analogRoyaltyPrimaryCut: UFix64 = 1.00
    for royalty in set.artistRoyalties {
      analogRoyaltyPrimaryCut = analogRoyaltyPrimaryCut - royalty.primaryCut
    }
    let royalties = [
      Royalty(
        address: set.analogRoyaltyAddress,
        primaryCut: analogRoyaltyPrimaryCut,
        secondaryCut: set.analogRoyaltySecondaryCut,
        description: "Sturdy Royalty"
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
      if Analogs.analogsTemplates[Analogs.nextTemplateID] != nil {
        panic("Template already exists")
      }
      Analogs.analogsTemplates[templateID] = AnalogsTemplate(
        templateID: templateID,
        name: name,
        description: description,
        metadata: metadata
      )
      let set = self.borrowSet(setID: setID)
      set.addTemplate(templateID: templateID, available: false)
      recipient.deposit(token: <- set.mintNFTByTemplateID(templateID: templateID))
    }

    pub fun createAnalogsTemplate(name: String, description: String, metadata: {String: String}) {
      Analogs.analogsTemplates[Analogs.nextTemplateID] = AnalogsTemplate(
        templateID: Analogs.nextTemplateID,
        name: name,
        description: description,
        metadata: metadata
      )
      Analogs.nextTemplateID = Analogs.nextTemplateID + 1
    }

    pub fun createSet(name: String, analogRoyaltyAddress: Address, analogRoyaltySecondaryCut: UFix64, imageCID: String): UInt64 {
      var newSet <- create Set(name: name, analogRoyaltyAddress: analogRoyaltyAddress, analogRoyaltySecondaryCut: analogRoyaltySecondaryCut, imageCID: imageCID)
      let setID = newSet.setID
      Analogs.sets[setID] <-! newSet
      return setID
    }

    pub fun borrowSet(setID: UInt64): &Set {
      pre {
        Analogs.sets[setID] != nil:
          "Cannot borrow Set: The Set doesn't exist"
      }
      
      return (&Analogs.sets[setID] as &Set?)!
    }

    pub fun updateSetImageCID(setID: UInt64, imageCID: String) {
      pre {
        Analogs.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
      }
        
      let set = (&Analogs.sets[setID] as &Set?)!
      return set.updateImageCID(imageCID: imageCID)
    }

    pub fun updateAnalogsTemplate(templateID: UInt64, newMetadata: {String: String}) {
      pre {
        Analogs.analogsTemplates.containsKey(templateID) != nil:
          "Template does not exists."
      }
      Analogs.analogsTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
    }

    pub fun setInitialNFTID(initialNFTID: UInt64) {
      pre {
        Analogs.initialNFTID == 0:
          "initialNFTID is already initialized"
      }
      Analogs.initialNFTID = initialNFTID
      Analogs.nextNFTID = initialNFTID
      Analogs.nextTemplateID = initialNFTID
    }

  }

  pub fun getAnalogsTemplateByID(templateID: UInt64): Analogs.AnalogsTemplate {
    return Analogs.analogsTemplates[templateID]!
  }

  pub fun getAnalogsTemplates(): {UInt64: Analogs.AnalogsTemplate} {
    return Analogs.analogsTemplates
  }

  pub fun getAvailableTemplateIDsInSet(setID: UInt64): [UInt64] {
    pre {
        Analogs.sets[setID] != nil:
        "Cannot borrow Set: The Set doesn't exist"
    }
    let set = (&Analogs.sets[setID] as &Set?)!
    return set.getAvailableTemplateIDs()
  }

  init() {
    self.CollectionStoragePath = /storage/AnalogsCollection
    self.CollectionPublicPath = /public/AnalogsCollection
    self.AdminStoragePath = /storage/AnalogsAdmin

    self.totalSupply = 0
    self.nextSetID = 1
    self.initialNFTID = 0
    self.nextNFTID = 0
    self.nextTemplateID = 0
    self.sets <- {}

    self.analogsTemplates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}