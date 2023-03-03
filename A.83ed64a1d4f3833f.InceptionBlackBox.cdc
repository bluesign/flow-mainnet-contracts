// SPDX-License-Identifier: MIT

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract InceptionBlackBox: NonFungibleToken {

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64)
  pub event Opened(id: UInt64)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var crystalPrice: UInt64
  pub var mintLimit: UInt64
  pub var InceptionBlackBoxMetadata: InceptionBlackBoxTemplate

  pub resource interface InceptionBlackBoxCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowInceptionBlackBox(id: UInt64): &InceptionBlackBox.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow InceptionBlackBox reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct InceptionBlackBoxTemplate {
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
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Serial>(),
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
            name: InceptionBlackBox.InceptionBlackBoxMetadata.name,
            description: InceptionBlackBox.InceptionBlackBoxMetadata.description,
            thumbnail: MetadataViews.HTTPFile(
              url: InceptionBlackBox.InceptionBlackBoxMetadata.getMetadata()!["uri"]!
            )
          )

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL(
            url: "https://www.inceptionanimals.com/"
          )

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(
            self.serialNumber
          )

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: InceptionBlackBox.CollectionStoragePath,
            publicPath: InceptionBlackBox.CollectionPublicPath,
            providerPath: /private/InceptionAvatarCollection,
            publicCollection: Type<&InceptionBlackBox.Collection{InceptionBlackBox.InceptionBlackBoxCollectionPublic}>(),
            publicLinkedType: Type<&InceptionBlackBox.Collection{InceptionBlackBox.InceptionBlackBoxCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&InceptionBlackBox.Collection{InceptionBlackBox.InceptionBlackBoxCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
              return <-InceptionBlackBox.createEmptyCollection()
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

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties(cutInfos: [])
      }

      return nil
    }

    pub fun getNFTMetadata(): InceptionBlackBoxTemplate {
      return InceptionBlackBox.InceptionBlackBoxMetadata
    }

    init(initID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.serialNumber = serialNumber
    }
  }

  pub resource Collection: InceptionBlackBoxCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      panic("Cannot withdraw NFT from this collection for now")

      // let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      // emit Withdraw(id: token.id, from: self.owner?.address)
      // return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @InceptionBlackBox.NFT
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

    pub fun borrowInceptionBlackBox(id: UInt64): &InceptionBlackBox.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &InceptionBlackBox.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &InceptionBlackBox.NFT
      return exampleNFT as &AnyResource{MetadataViews.Resolver}
    }

    pub fun openBox(tokenID: UInt64) {
      let token <- self.ownedNFTs.remove(key: tokenID) ?? panic("missing NFT")
      emit Opened(id: token.id)
      destroy <- token
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
    pub fun mintInceptionBlackBox(recipient: &{NonFungibleToken.CollectionPublic}) {
      pre {
        InceptionBlackBox.mintLimit >= InceptionBlackBox.totalSupply:
          "InceptionBlackBox is out of stock"
      }
      let newNFT: @NFT <- create InceptionBlackBox.NFT(initID: InceptionBlackBox.totalSupply, serialNumber: InceptionBlackBox.totalSupply)
      emit Minted(id: newNFT.id)
      
      recipient.deposit(token: <- newNFT)
      InceptionBlackBox.totalSupply = InceptionBlackBox.totalSupply + 1
    }

    pub fun updateInceptionBlackBoxMetadata(newMetadata: {String: String}) {
      InceptionBlackBox.InceptionBlackBoxMetadata.updateMetadata(newMetadata: newMetadata)
    }

    pub fun updateInceptionBlackBoxCrystalPrice(newCrystalPrice: UInt64) {
      InceptionBlackBox.crystalPrice = newCrystalPrice
    }

    pub fun increaseMintLimit(increment: UInt64) {
      pre {
        increment > 0:
          "increment must be a positive number"
      }
      InceptionBlackBox.mintLimit = InceptionBlackBox.mintLimit + increment
    }
  }


  pub fun getInceptionBlackBoxMetadata(): InceptionBlackBox.InceptionBlackBoxTemplate {
    return InceptionBlackBox.InceptionBlackBoxMetadata
  }

  init() {
    self.CollectionStoragePath = /storage/InceptionBlackBoxCollection
    self.CollectionPublicPath = /public/InceptionBlackBoxCollection
    self.AdminStoragePath = /storage/InceptionBlackBoxAdmin

    self.totalSupply = 1
    self.crystalPrice = 10
    self.mintLimit = 0
    self.InceptionBlackBoxMetadata = InceptionBlackBoxTemplate(
      name: "Inception Black Box",
      description: "It's a hidden gem from the brotherhood of tinkers. Shissh!! I heard that it opens up when the merge happens!",
      metadata: {}
    )

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}
 