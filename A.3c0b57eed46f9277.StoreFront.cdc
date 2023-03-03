// SPDX-License-Identifier: Unlicense

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import StoreFrontViews from 0x3c0b57eed46f9277

// TOKEN RUNNERS: Contract responsable for NFT and Collection
pub contract StoreFront: NonFungibleToken {

  // -----------------------------------------------------------------------
  // StoreFront contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------

  // The total supply that is used to create FNT.
  // Every time a NFT is created,
  // totalSupply is incremented by 1 and then is assigned to NFT's ID.
  pub var totalSupply: UInt64

  // The next template ID that is used to create Template.
  // Every time a Template is created, nextTemplateId is assigned
  // to the new Template's ID and then is incremented by 1.
  access(account) var nextTemplateId: UInt64

  // The next NFT ID that is used to create NFT.
  // Every time a NFT is created, nextNFTId is assigned
  // to the new NFT's ID and then is incremented by 1.
  access(account) var nextNFTId: UInt64

  // Variable size dictionary of Template structs by storefront
  access(self) var templateDatas: {UInt64: Template}

  // Variable size dictionary of minted templates structs
  access(self) var numberMintedByTemplate: {UInt64: UInt64}

  /// Path where the public capability for the `Collection` is available
  pub let collectionPublicPath: PublicPath

  /// Path where the `Collection` is stored
  pub let collectionStoragePath: StoragePath

  /// Path where the private capability for the `Collection` is available
  pub let collectionPrivatePath: PrivatePath

  /// Event used on create template
  pub event TemplateCreated(templateId: UInt64)

  /// Event used on destroy NFT from collection
  pub event NFTDestroyed(nftId: UInt64)

  /// Event used on withdraw NFT from collection
  pub event Withdraw(id: UInt64, from: Address?)

  /// Event used on deposit NFT to collection
  pub event Deposit(id: UInt64, to: Address?)

  /// Event used on mint NFT
  pub event NFTMinted(nftId: UInt64, edition: UInt64, templateId: UInt64, databaseID: String, hashMetadata: HashMetadata)

  /// Event used on contract initiation
  pub event ContractInitialized()

  /// Event used on reveal process
  pub event NFTReveal(nftId: UInt64)

  /// Event used once the NFT is airdropped
  pub event NFTAirdrop(nftId: UInt64, to: Address?)

  // -----------------------------------------------------------------------
  // StoreFront contract-level Composite Type definitions
  // -----------------------------------------------------------------------
  // These are just *definitions* for Types that this contract
  // and other accounts can use. These definitions do not contain
  // actual stored values, but an instance (or object) of one of these Types
  // can be created by this contract that contains stored values.
  // -----------------------------------------------------------------------

  // Template is a Struct that holds metadata associated with a specific
  // nft
  //
  // NFT resource will all reference a single template as the owner of
  // its metadata. The templates are publicly accessible, so anyone can
  // read the metadata associated with a specific NFT ID
  //
  pub struct Template {
    pub let templateId: UInt64
    pub let maxEditions: UInt64
    pub let creationDate: UInt64
    access(contract) let metadata: {String: String}

    init(metadata: {String: String}, maxEditions: UInt64, creationDate: UInt64) {
      self.templateId = StoreFront.nextTemplateId
      self.metadata = metadata
      self.maxEditions = maxEditions
      self.creationDate = creationDate

      emit TemplateCreated(templateId: self.templateId)

      StoreFront.nextTemplateId = StoreFront.nextTemplateId + UInt64(1)
    }
  }

  pub struct HashMetadata {
    pub let hash: String
    pub let start: UInt64
    pub let end: UInt64

    init(hash: String, start: UInt64, end: UInt64) {
      self.hash = hash
      self.start = start
      self.end = end
    }
  }

  // NFTData is a Struct that holds template's ID and a metadata
  //
  pub struct NFTData {
    pub let templateId: UInt64
    pub let edition: UInt64
    access(contract) var metadata: {String: String}
    pub let hashMetadata: HashMetadata

    init(metadata: {String: String}, templateId: UInt64, edition: UInt64, hashMetadata: HashMetadata) {
      self.templateId = templateId
      self.metadata = metadata
      self.edition = edition
      self.hashMetadata = hashMetadata
    }

    access(account) fun updateMetadata(metadata: {String: String}) {
      self.metadata = metadata
    }
  }

  // The resource that represents the NFT
  //
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver  {
    pub let id: UInt64
    pub let data: NFTData

    init(edition: UInt64, metadata: {String: String}, templateId: UInt64, databaseID: String, hashMetadata: HashMetadata) {
      self.id = StoreFront.nextNFTId

      self.data = NFTData(metadata:metadata, templateId: templateId, edition: edition, hashMetadata: hashMetadata)

      emit NFTMinted(nftId: self.id, edition: edition, templateId: templateId, databaseID: databaseID, hashMetadata: hashMetadata)

      StoreFront.nextNFTId = StoreFront.nextNFTId + UInt64(1)
    }

    pub fun getViews(): [Type] {
        return [
            Type<MetadataViews.Display>(),
            Type<StoreFrontViews.StoreFrontDisplay>(),
            Type<MetadataViews.Royalties>(),
            Type<MetadataViews.Editions>(),
            Type<MetadataViews.Serial>(),
            Type<MetadataViews.ExternalURL>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>(),
            Type<MetadataViews.Traits>()
        ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      let metadata = self.data.metadata
      switch view {
          case Type<MetadataViews.Display>():
              return MetadataViews.Display(
                  name: metadata["name"]!,
                  description: metadata["description"]!,
                  thumbnail: MetadataViews.IPFSFile(
                      cid: metadata["image"]!,
                      path: nil
                  )
              )
          case Type<StoreFrontViews.StoreFrontDisplay>():
              return StoreFrontViews.StoreFrontDisplay(
                  name: metadata["name"]!,
                  description: metadata["description"]!,
                  thumbnail: MetadataViews.IPFSFile(
                      cid: metadata["image"]!,
                      path: nil
                  ),
                  metadata: metadata
              )
          case Type<MetadataViews.Royalties>():
              return MetadataViews.Royalties(
                  []
              )
          case Type<MetadataViews.Editions>(): 
                let editionInfo = MetadataViews.Edition(name: metadata["name"]!, number: self.data.edition, max: nil)
                let editionList: [MetadataViews.Edition] = [editionInfo]
              return MetadataViews.Editions(
                  editionList
              )
          case Type<MetadataViews.Serial>(): 
              return MetadataViews.Serial(
                  self.id
              )
          case Type<MetadataViews.ExternalURL>(): 
              return MetadataViews.ExternalURL(metadata["external_url"]!)
          case Type<MetadataViews.NFTCollectionData>():
              return MetadataViews.NFTCollectionData(
                  storagePath: StoreFront.collectionStoragePath,
                  publicPath: StoreFront.collectionPublicPath,
                  providerPath: /private/storeFrontNFTCollection,
                  publicCollection: Type<&StoreFront.Collection{StoreFront.CollectionPublic}>(),
                  publicLinkedType: Type<&StoreFront.Collection{StoreFront.CollectionPublic,StoreFront.IRevealNFT,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                  providerLinkedType: Type<&StoreFront.Collection{StoreFront.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                  createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                      return <-StoreFront.createEmptyCollection()
                  })
              )
          case Type<MetadataViews.NFTCollectionDisplay>():
              let template: Template = StoreFront.getTemplate(templateId: self.data.templateId)!
              let media = MetadataViews.Media(
                  file: MetadataViews.HTTPFile(
                      url: self.data.metadata["collectionFileUri"]!
                  ),
                  mediaType: self.data.metadata["collectionMediaType"]!
              )

              return MetadataViews.NFTCollectionDisplay(
                  name: metadata["name"]!,
                  description: metadata["description"]!,
                  externalURL: MetadataViews.ExternalURL(template.metadata["externalLink"]!),
                  squareImage: media,
                  bannerImage: media,
                  socials: {
                      "twitter": MetadataViews.ExternalURL(metadata["twitterLink"]!),
                      "discord": MetadataViews.ExternalURL(metadata["discordLink"]!)
                  }
              )

          case Type<MetadataViews.Traits>():
              return MetadataViews.dictToTraits(dict: self.data.metadata, excludedNames: [])
        }

        return nil
    }

    access(account) fun reveal(admin: &Admin, metadata: {String: String}) {
      self.data.updateMetadata(metadata: metadata)
    }

    destroy() {
      StoreFront.totalSupply = StoreFront.totalSupply - 1
      emit NFTDestroyed(nftId: self.id)
    }
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun airdrop(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrow(id: UInt64): &StoreFront.NFT?
  }

  pub resource interface IRevealNFT {
    pub fun revealNFT(id: UInt64, admin: &Admin, metadata: {String: String})
  }

  // Collection is a resource that every user who owns NFTs
  // will store in their account to manage their NFTS
  //
  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection, IRevealNFT {

    // Dictionary of StarvingChildren conforming tokens
    // NFT is a resource type with a UInt64 ID field
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init() {
      self.ownedNFTs <- {}
    }

    // withdraw removes an StoreFront from the Collection and moves it to the caller
    //
    // Parameters: withdrawID: The ID of the NFT
    // that is to be removed from the Collection
    //
    // returns: @NFT the token that was withdrawn
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      // Remove the nft from the Collection
      let token <- self.ownedNFTs.remove(key: withdrawID)
          ?? panic("Cannot withdraw: NFT does not exist in the collection")

      emit Withdraw(id: token.id, from: self.owner?.address)

      // Return the withdrawn token
      return <-token
    }

    // deposit takes a StoreFront and adds it to the Collections dictionary
    //
    // Paramters: token: the NFT to be deposited in the collection
    //
    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @NFT

      let id = token.id

      let oldToken <-self.ownedNFTs[id] <-token

      if self.owner?.address != nil {
        emit Deposit(id: id, to: self.owner?.address)
      }

      destroy oldToken
    }

    // airdrop takes a StoreFront and adds it to the Collections dictionary
    //
    // Parameters: token: the NFT to be airdropped in the collection
    //
    pub fun airdrop(token: @NonFungibleToken.NFT) {
      let token <- token as! @NFT

      let id = token.id

      let oldToken <-self.ownedNFTs[id] <-token

      if self.owner?.address != nil {
        emit NFTAirdrop(nftId: id, to: self.owner?.address)
      }

      destroy oldToken
    }

    // getIDs returns an array of the IDs that are in the Collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrow Returns a borrowed reference to a StoreFront in the Collection
    // so that the caller can read its ID
    //
    // Parameters: id: The ID of the NFT to get the reference for
    //
    // Returns: A reference to the NFT
    //
    pub fun borrow(id: UInt64): &StoreFront.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &StoreFront.NFT
      } else {
        return nil
      }
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let storeFrontNFT = nft as! &NFT
      return storeFrontNFT as &{MetadataViews.Resolver}
    }

    pub fun revealNFT(id: UInt64, admin: &Admin, metadata: {String: String}) {
      if self.ownedNFTs[id] != nil {
        let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        let storeFrontNFT = nft as! &NFT
        storeFrontNFT.reveal(admin: admin, metadata: metadata)

        emit NFTReveal(nftId: id)
      } else {
        panic("can't find nft id")
      }
    }

    // If a transaction destroys the Collection object,
    // All the NFTs contained within are also destroyed!
    // Much like when Damian Lillard destroys the hopes and
    // dreams of the entire city of Houston.
    //
    destroy() {
      destroy self.ownedNFTs
    }
  }

  // Admin is a resource that storefront creator has
  // to mint NFT and create templates
  //
  pub resource Admin {

    pub fun mintNFT(templateId: UInt64, databaseID: String, hash: String, start: UInt64, end: UInt64): @NonFungibleToken.NFT {
      return <- StoreFront.mintNFT(templateId: templateId, databaseID: databaseID, hashMetadata: HashMetadata(hash: hash, start: start, end: end))
    }

    pub fun createTemplate(metadata: {String: String}, maxEditions: UInt64, creationDate: UInt64): UInt64 {
      return StoreFront.createTemplate(metadata: metadata, maxEditions: maxEditions, creationDate: creationDate)
    }
  }

  // -----------------------------------------------------------------------
  // StoreFront contract-level function definitions
  // -----------------------------------------------------------------------

  // createEmptyCollection creates a new Collection a user can store
  // it in their account storage.
  //
  pub fun createEmptyCollection(): @Collection {
    return <-create StoreFront.Collection()
  }

  // getTemplate get a specific templates stored in the contract by id
  //
  pub fun getTemplate(templateId: UInt64): Template?{
    return StoreFront.templateDatas[templateId]
  }

  // getAllTemplates get all templates stored in the contract
  //
  pub fun getAllTemplates(): [Template]{
    return StoreFront.templateDatas.values
  }

  // mintNFT create a new NFT using a template ID
  //
  // Parameters: templateId: The ID of the Template
  // Parameters: databaseID: The database ID of external source, used to link transaction to db item
  // Parameters: hashMetadata: The hashMetadata is the collection hash, used to check if the nft metadata has changed
  //
  // returns: @NFT the token that was created
  access(account) fun mintNFT(templateId: UInt64, databaseID: String, hashMetadata: HashMetadata): @NFT {
    pre {
        StoreFront.templateDatas.containsKey(templateId) : "templateId not found"
        StoreFront.templateDatas[templateId]!.maxEditions > StoreFront.numberMintedByTemplate[templateId]! : "template not available"
    }

    var template = StoreFront.templateDatas[templateId]!

    StoreFront.numberMintedByTemplate[templateId] = StoreFront.numberMintedByTemplate[templateId]! + 1

    let edition = StoreFront.numberMintedByTemplate[templateId]!
    let newNFT: @NFT <- create NFT(edition: edition, metadata: template!.metadata, templateId: templateId, databaseID: databaseID, hashMetadata: hashMetadata)
    StoreFront.totalSupply = StoreFront.totalSupply + 1

    return <- newNFT
  }

  // createTemplate create a template using a metadata
  //
  // Parameters: metadata: The buyer's metadata to save inside Template
  // Parameters: maxEditions: The max amount of editions
  // Parameters: creationDate: The creation date of the template
  //
  // returns: UInt64 the new template ID
  access(account) fun createTemplate(metadata: {String: String}, maxEditions: UInt64, creationDate: UInt64): UInt64 {
    var newTemplate = Template(metadata: metadata, maxEditions: maxEditions, creationDate: creationDate)

    StoreFront.numberMintedByTemplate[newTemplate.templateId] = 0
    StoreFront.templateDatas[newTemplate.templateId] = newTemplate

    return newTemplate.templateId
  }

  // create a admin
  //
  access(account) fun createStoreFrontAdmin(): @Admin {
    return <- create Admin()
  }

  init() {
    // Paths
    self.collectionPublicPath = /public/StoreFrontCollection0x3c0b57eed46f9277
    self.collectionStoragePath = /storage/StoreFrontCollection0x3c0b57eed46f9277
    self.collectionPrivatePath = /private/StoreFrontCollection0x3c0b57eed46f9277

    self.nextTemplateId = 1
    self.nextNFTId = 1
    self.totalSupply = 0
    self.templateDatas = {}
    self.numberMintedByTemplate = {}

    emit ContractInitialized()
  }
}