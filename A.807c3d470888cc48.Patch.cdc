// SPDX-License-Identifier: UNLICENSED

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Patch: NonFungibleToken {

  pub event ContractInitialized()
  pub event NFTTemplateCreated(templateID: UInt64, template: Patch.PatchTemplate)
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Mint(id: UInt64, templateID: UInt64, serialNumber: UInt64)
  pub event Burn(id: UInt64)
  pub event TemplateUpdated(template: PatchTemplate)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var nextTemplateID: UInt64

  access(self) var PatchTemplates: {UInt64: PatchTemplate}
  access(self) var tokenMintedPerType: {UInt64: UInt64}

  pub resource interface PatchCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowPatch(id: UInt64): &Patch.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow Patch reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct PatchTemplate {
    pub let templateID: UInt64
    pub var name: String
    pub var description: String
    pub var mintLimit: UInt64
    pub var locked: Bool
    pub var nextSerialNumber: UInt64
    access(self) var metadata: {String: String}

    pub fun getMetadata(): {String: String} {
      return self.metadata
    }

    pub fun incrementSerialNumber() {
      self.nextSerialNumber = self.nextSerialNumber + 1
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

    init(templateID: UInt64, name: String, description: String, mintLimit: UInt64, metadata: {String: String}){
      pre {
        metadata.length != 0: "New Template metadata cannot be empty"
      }

      self.templateID = templateID
      self.name = name
      self.description= description
      self.mintLimit = mintLimit
      self.metadata = metadata
      self.locked = false
      self.nextSerialNumber = 1

      Patch.nextTemplateID = Patch.nextTemplateID + 1

      emit NFTTemplateCreated(templateID: self.templateID, template: self)
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let templateID: UInt64
    pub let serialNumber: UInt64
    
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
            storagePath: Patch.CollectionStoragePath,
            publicPath: Patch.CollectionPublicPath,
            providerPath: /private/PatchPrivateProvider,
            publicCollection: Type<&Patch.Collection{NonFungibleToken.CollectionPublic}>(),
            publicLinkedType: Type<&Patch.Collection{NonFungibleToken.CollectionPublic, Patch.PatchCollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&Patch.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollection: (fun (): @NonFungibleToken.Collection {
              return <-Patch.createEmptyCollection()
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
            name: "Backpack Patch",
            description: "Backpack Patches #onFlow",
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

    pub fun getNFTTemplate(): PatchTemplate {
      return Patch.PatchTemplates[self.templateID]!
    }

    pub fun getNFTMetadata(): {String: String} {
      return Patch.PatchTemplates[self.templateID]!.getMetadata()
    }

    init(initID: UInt64, initTemplateID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.templateID = initTemplateID
      self.serialNumber = serialNumber
    }

    destroy() {
      emit Burn(id: self.id)
    }
  }

  pub resource Collection: PatchCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @Patch.NFT
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

    pub fun borrowPatch(id: UInt64): &Patch.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &Patch.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &Patch.NFT
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

    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, templateID: UInt64) {
      pre {
        Patch.PatchTemplates[templateID] != nil:
          "Template doesn't exist"
        !Patch.PatchTemplates[templateID]!.locked:
          "Cannot mint Patch - template is locked"
        Patch.PatchTemplates[templateID]!.nextSerialNumber <= Patch.PatchTemplates[templateID]!.mintLimit:
          "Cannot mint Patch - mint limit reached"
      }

      // TODO: mint Patch NFT
      let nftTemplate = Patch.PatchTemplates[templateID]!
      let newNFT: @NFT <- create Patch.NFT(initID: Patch.totalSupply, initTemplateID: templateID, serialNumber: nftTemplate.nextSerialNumber)
      emit Mint(id: newNFT.id, templateID: nftTemplate.templateID, serialNumber: nftTemplate.nextSerialNumber)
      Patch.totalSupply = Patch.totalSupply + 1
      Patch.PatchTemplates[templateID]!.incrementSerialNumber()
      recipient.deposit(token: <- newNFT)
    }

    pub fun createPatchTemplate(name: String, description: String, mintLimit: UInt64, metadata: {String: String}) {
      Patch.PatchTemplates[Patch.nextTemplateID] = PatchTemplate(
        templateID:Patch.nextTemplateID,
        name: name,
        description: description,
        mintLimit: mintLimit,
        metadata: metadata
      )
    }

    pub fun updatePatchTemplate(templateID: UInt64, newMetadata: {String: String}) {
      pre {
        Patch.PatchTemplates.containsKey(templateID) != nil:
          "Template does not exits."
      }
      Patch.PatchTemplates[templateID]!.updateMetadata(newMetadata: newMetadata)
    }
  }

  pub fun getPatchTemplateByID(templateID: UInt64): Patch.PatchTemplate {
    return Patch.PatchTemplates[templateID]!
  }

  pub fun getPatchTemplates(): {UInt64: Patch.PatchTemplate} {
    return Patch.PatchTemplates
  }

  init() {
    self.CollectionStoragePath = /storage/PatchCollection
    self.CollectionPublicPath = /public/PatchCollection
    self.AdminStoragePath = /storage/PatchAdmin

    self.totalSupply = 0
    self.nextTemplateID = 1
    self.tokenMintedPerType = {}

    self.PatchTemplates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}