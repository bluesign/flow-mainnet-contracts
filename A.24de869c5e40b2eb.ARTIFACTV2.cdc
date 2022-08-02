// SPDX-License-Identifier: Unlicense

import NonFungibleToken, MetadataViews from 0x1d7e57aa55817448
import ARTIFACTViews, Interfaces from 0x24de869c5e40b2eb

pub contract ARTIFACTV2: NonFungibleToken {

  // -----------------------------------------------------------------------
  // ARTIFACTV2 contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------
  
  // The total supply that is used to create NFT. 
  // Every time a NFT is created,  
  // totalSupply is incremented by 1 and then is assigned to NFT's ID.
  pub var totalSupply: UInt64
    
  // The next NFT ID that is used to create NFT. 
  // Every time a NFT is created, nextNFTId is assigned 
  // to the new NFT's ID and then is incremented by 1.
  pub var nextNFTId: UInt64
  
  /// Path where the public capability for the `Collection` is available
  pub let collectionPublicPath: PublicPath

  /// Path where the `Collection` is stored
  pub let collectionStoragePath: StoragePath

  /// Path where the private capability for the `Collection` is available
  pub let collectionPrivatePath: PrivatePath

  /// Event used on destroy NFT from collection
  pub event NFTDestroyed(nftId: UInt64)

  /// Event used on withdraw NFT from collection
  pub event Withdraw(id: UInt64, from: Address?)

  /// Event used on deposit NFT to collection
  pub event Deposit(id: UInt64, to: Address?)
  
  /// Event used on mint NFT
  pub event NFTMinted(nftId: UInt64, packID: UInt64, templateOffChainId: String, owner: Address)

  /// Event used on mint NFT
  pub event NFTRevealed(templateOffChainId: String)

  /// Event used on contract initiation
  pub event ContractInitialized()
    
  // -----------------------------------------------------------------------
  // ARTIFACTV2 contract-level Composite Type definitions
  // -----------------------------------------------------------------------
  // These are just *definitions* for Types that this contract
  // and other accounts can use. These definitions do not contain
  // actual stored values, but an instance (or object) of one of these Types
  // can be created by this contract that contains stored values.
  // ----------------------------------------------------------------------- 

  pub struct HashMetadata : Interfaces.IHashMetadata {
    pub let hash: String
    pub let start: UInt64
    pub let end: UInt64

    init(hash: String, start: UInt64, end: UInt64) {
        self.hash = hash
        self.start = start
        self.end = end
    }
  }

  // NFTData is a Struct that holds template's ID, metadata, 
  // edition number and rarity field
  //
  pub struct NFTData {
    pub let templateOffChainId: String
    pub var edition: UInt64
    pub var rarity: UInt64
    pub let packID: UInt64
    pub let hashMetadata: HashMetadata
    access(account) var metadata: {String: String}
    access(account) let royalties: [MetadataViews.Royalty]

    init(templateOffChainId: String, packID: UInt64, royalties: [MetadataViews.Royalty], hashMetadata: HashMetadata) {
      self.templateOffChainId = templateOffChainId
      self.packID = packID
      self.royalties = royalties
      self.hashMetadata = hashMetadata

      self.metadata = {}
      self.edition = 0
      self.rarity = 0
    }

    access(account) fun reveal(metadata: {String: String}, edition: UInt64, rarity: UInt64) {
      self.metadata = metadata
      self.edition = edition
      self.rarity = rarity
    }
  }

  // The resource that represents the NFT
  //
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let data: NFTData

    init(templateId: String, packID: UInt64, owner: Address, royalties: [MetadataViews.Royalty], hashMetadata: HashMetadata) {
      self.id = ARTIFACTV2.nextNFTId

      self.data = NFTData(templateOffChainId: templateId, packID: packID, royalties: royalties, hashMetadata: hashMetadata)

      emit NFTMinted(nftId: self.id, packID: self.data.packID, templateOffChainId: templateId, owner: owner)
      ARTIFACTV2.nextNFTId = ARTIFACTV2.nextNFTId + UInt64(1)
      ARTIFACTV2.totalSupply = ARTIFACTV2.totalSupply + 1
    }

    pub fun getViews(): [Type] {
        return [
            Type<MetadataViews.Display>(),
            Type<ARTIFACTViews.ArtifactsDisplay>(),
            Type<MetadataViews.Royalties>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      let artifactFileUri = self.data.metadata["artifactFileUri"]!
      let artifactFileUriFormatted = artifactFileUri.slice(from: 7, upTo: artifactFileUri.length - 1)
      switch view {
          case Type<MetadataViews.Display>():
              return MetadataViews.Display(
                  name: self.data.metadata["artifactName"]!,
                  description: self.data.metadata["artifactShortDescription"]!,
                  thumbnail: MetadataViews.IPFSFile(
                      cid: artifactFileUriFormatted,
                      path: nil
                  )
              )
          case Type<ARTIFACTViews.ArtifactsDisplay>():
              return ARTIFACTViews.ArtifactsDisplay(
                  name: self.data.metadata["artifactName"]!,
                  description: self.data.metadata["artifactShortDescription"]!,
                  thumbnail: MetadataViews.IPFSFile(
                      cid: artifactFileUriFormatted,
                      path: nil
                  ),
                  metadata: self.data.metadata
              )
          
          case Type<MetadataViews.Royalties>():
              return MetadataViews.Royalties(
                  self.data.royalties
              )

          case Type<MetadataViews.NFTCollectionData>():
              return MetadataViews.NFTCollectionData(
                  storagePath: ARTIFACTV2.collectionStoragePath,
                  publicPath: ARTIFACTV2.collectionPublicPath,
                  providerPath: ARTIFACTV2.collectionPrivatePath,
                  publicCollection: Type<&ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic}>(),
                  publicLinkedType: Type<&ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                  providerLinkedType: Type<&ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                  createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                      return <-ARTIFACTV2.createEmptyCollection()
                  })
              )

          case Type<MetadataViews.NFTCollectionDisplay>():
              let media = MetadataViews.Media(
                  file: MetadataViews.HTTPFile(
                      url: self.data.metadata["collectionFileUri"]!
                  ),
                  mediaType: self.data.metadata["collectionMediaType"]!
              )

              return MetadataViews.NFTCollectionDisplay(
                  name: self.data.metadata["collectionName"]!,
                  description: self.data.metadata["collectionDescription"]!,
                  externalURL: MetadataViews.ExternalURL("https://artifact.scmp.com/"),
                  squareImage: media,
                  bannerImage: media,
                  socials: {
                      "twitter": MetadataViews.ExternalURL("https://twitter.com/artifactsbyscmp"),
                      "discord": MetadataViews.ExternalURL("https://discord.gg/PwbEbFbQZX")
                  }
              )
        }

        return nil
    }

    access(account) fun reveal(metadata: {String: String}, edition: UInt64, rarity: UInt64) {
      metadata["artifactIdentifier"] = self.id.toString()
      metadata["artifactEditionNumber"] = edition.toString()
      
      self.data.reveal(metadata: metadata, edition: edition, rarity: rarity)

      emit NFTRevealed(templateOffChainId: self.data.templateOffChainId)
    }

    destroy() {
      ARTIFACTV2.totalSupply = ARTIFACTV2.totalSupply - 1
      emit NFTDestroyed(nftId: self.id)
    }
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT) 
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT 
    pub fun borrow(id: UInt64): &ARTIFACTV2.NFT?
  }
  
  pub resource interface IRevealNFT {
    access(account) fun revealNFT(id: UInt64, metadata: {String: String}, edition: UInt64, rarity: UInt64)
  }

  // Collection is a resource that every user who owns NFTs 
  // will store in their account to manage their NFTS
  //
  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection, IRevealNFT { 
    
    // Dictionary of NFTs conforming tokens
    // NFT is a resource type with a UInt64 ID field
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init() {
      self.ownedNFTs <- {}
    }

    // withdraw removes an ARTIFACTV2 from the Collection and moves it to the caller
    //
    // Parameters: withdrawID: The ID of the NFT 
    // that is to be removed from the Collection
    //
    // returns: @NFT the token that was withdrawn
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      // Remove the nft from the Collection
      let token <- self.ownedNFTs.remove(key: withdrawID) 
          ?? panic("Cannot withdraw: ARTIFACTV2 does not exist in the collection")

      emit Withdraw(id: token.id, from: self.owner?.address)
      
      // Return the withdrawn token
      return <-token
    }


    // deposit takes a ARTIFACTV2 and adds it to the Collections dictionary
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

    // getIDs returns an array of the IDs that are in the Collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrow Returns a borrowed reference to a ARTIFACTV2 in the Collection
    // so that the caller can read its ID
    //
    // Parameters: id: The ID of the NFT to get the reference for
    //
    // Returns: A reference to the NFT
    //
    pub fun borrow(id: UInt64): &ARTIFACTV2.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &ARTIFACTV2.NFT
      } else {
        return nil
      }
    }
    
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {      
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let artifactsNFT = nft as! &NFT
      return artifactsNFT as &{MetadataViews.Resolver}
    }

    access(account) fun revealNFT(id: UInt64, metadata: {String: String}, edition: UInt64, rarity: UInt64) {
      if self.ownedNFTs[id] != nil {
        let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        let artifactNFT = nft as! &NFT
        artifactNFT.reveal(metadata: metadata, edition: edition, rarity: rarity)
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

  // -----------------------------------------------------------------------
  // ARTIFACTV2 contract-level function definitions
  // -----------------------------------------------------------------------

  // createEmptyCollection creates a new Collection a user can store 
  // it in their account storage.
  //
  pub fun createEmptyCollection(): @Collection {
    return <-create ARTIFACTV2.Collection()
  }

  // createNFT create a NFT used by ARTIFACTAdmin
  //
  access(account) fun createNFT(templateId: String, packID: UInt64, owner: Address, royalties: [MetadataViews.Royalty], hashMetadata: HashMetadata): @NFT {
    return <- create NFT(templateId: templateId, packID: packID, owner: owner, royalties: royalties, hashMetadata: hashMetadata)
  }

  init() {
    // Paths
    self.collectionPublicPath = /public/ARTIFACTV2Collection
    self.collectionStoragePath = /storage/ARTIFACTV2Collection
    self.collectionPrivatePath = /private/ARTIFACTV2Collection

    self.nextNFTId = 1
    self.totalSupply = 0
    
    emit ContractInitialized()
  }
}