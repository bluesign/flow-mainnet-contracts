import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Slush: NonFungibleToken {
  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  init() {
    self.totalSupply = 0

    // Set the named paths
    self.CollectionStoragePath = /storage/SlushCollection
    self.CollectionPublicPath = /public/SlushCollection
    self.MinterStoragePath = /storage/SlushMinter

    // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // create a public capability for the collection
    self.account.link<&Slush.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
      self.CollectionPublicPath,
      target: self.CollectionStoragePath
    )

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    emit ContractInitialized()
  }

    pub struct SlushDisplay {
      pub let name: String
      pub let description: String

      pub let thumbnail: AnyStruct{MetadataViews.File}
      pub let videoURI: String
      pub let ipfsVideo: MetadataViews.IPFSFile

      init(
          name: String,
          description: String,
          thumbnail: AnyStruct{MetadataViews.File},
          videoURI: String,
          ipfsVideo: MetadataViews.IPFSFile,
      ) {
          self.name = name
          self.description = description
          self.thumbnail = thumbnail
          self.videoURI = videoURI
          self.ipfsVideo = ipfsVideo
      }
    }

	pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
		pub let id: UInt64
    pub let name: String
    pub let description: String
    pub let thumbnail: String
    pub let videoURI: String
    pub let videoCID: String
    access(self) let metadata: {String: AnyStruct}
        
    init(
      name: String,
      description: String,
      thumbnail: String,
      videoURI: String,
      videoCID: String,
      metadata: {String: AnyStruct},
    ) {
      self.id = Slush.totalSupply
      self.name = name
      self.description = description
      self.thumbnail = thumbnail
      self.videoURI = videoURI
      self.videoCID = videoCID
      self.metadata = metadata
    }

    pub fun getViews(): [Type] {
      return [
          Type<MetadataViews.Display>(),
          Type<Slush.SlushDisplay>(),
          Type<MetadataViews.ExternalURL>(),
          Type<MetadataViews.NFTCollectionData>(),
          Type<MetadataViews.NFTCollectionDisplay>(),
          Type<MetadataViews.Serial>(),
          Type<MetadataViews.Royalties>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.Display>():
                return MetadataViews.Display(
                    name: self.name,
                    description: self.description,
                    thumbnail: MetadataViews.HTTPFile(
                        url: self.thumbnail
                    ),
                )
            case Type<Slush.SlushDisplay>():
                return Slush.SlushDisplay(
                    name: self.name,
                    description: self.description,
                    thumbnail: MetadataViews.HTTPFile(
                        url: self.thumbnail
                    ),
                    videoURI: self.videoURI,
                    ipfsVideo: MetadataViews.IPFSFile(cid: self.videoCID, path: nil)
                )
            case Type<MetadataViews.Serial>():
                return MetadataViews.Serial(
                    self.id
                )
            case Type<MetadataViews.Royalties>():
                return MetadataViews.Royalties([])
            case Type<MetadataViews.ExternalURL>():
                return MetadataViews.ExternalURL("https://www.slush.org/web3")
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: Slush.CollectionStoragePath,
                    publicPath: Slush.CollectionPublicPath,
                    providerPath: /private/SlushCollection,
                    publicCollection: Type<&Slush.Collection{MetadataViews.ResolverCollection}>(),
                    publicLinkedType: Type<&Slush.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                    providerLinkedType: Type<&Slush.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                    createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                        return <-Slush.createEmptyCollection()
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let squareImageMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://mint.slush.org/media/slush-icon.png"
                    ),
                    mediaType: "image/png"
                )
                let bannerImageMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://mint.slush.org/media/slush-logo.png"
                    ),
                    mediaType: "image/png"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "Slush Ticket NFTs",
                    description: "Slush is bringing the global startup ecosystem under one roof. A curated group of speakers from across the globe, showcases, and unique networking opportunities will all be in Helsinki.",
                    externalURL: MetadataViews.ExternalURL("https://www.slush.org/"),
                    squareImage: squareImageMedia,
                    bannerImage: bannerImageMedia,
                    socials: {
                      "twitter": MetadataViews.ExternalURL("https://twitter.com/SlushHQ")
                    }
                )
        }
        return nil
    }
  }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    pub resource NFTMinter {
      pub fun mintNFT(
        recipient: &{NonFungibleToken.CollectionPublic},
        name: String,
        description: String,
        thumbnail: String,
        videoURI: String,
        videoCID: String,
      ) {
        let metadata: {String: AnyStruct} = {}

        let currentBlock = getCurrentBlock()
        metadata["mintedBlock"] = currentBlock.height
        metadata["mintedTime"] = currentBlock.timestamp
        metadata["minter"] = recipient.owner!.address

        var newNFT <- create NFT(
          name: name,
          description: description,
          thumbnail: thumbnail,
          videoURI: videoURI,
          videoCID: videoCID,
          metadata: metadata
        )

        recipient.deposit(token: <- newNFT)
        Slush.totalSupply = Slush.totalSupply + 1
    }
  }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
      pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

      init() {
        self.ownedNFTs <- {}
      }

      // withdraw removes an NFT from the collection and moves it to the caller
      pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
        let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

        emit Withdraw(id: token.id, from: self.owner?.address)

        return <-token
      }

      // deposit takes a NFT and adds it to the collections dictionary
      // and adds the ID to the id array
      pub fun deposit(token: @NonFungibleToken.NFT) {
        let token <- token as! @Slush.NFT

        let id: UInt64 = token.id

        // add the new token to the dictionary which removes the old one
        let oldToken <- self.ownedNFTs[id] <- token

        emit Deposit(id: id, to: self.owner?.address)

        destroy oldToken
      }

      // getIDs returns an array of the IDs that are in the collection
      pub fun getIDs(): [UInt64] {
          return self.ownedNFTs.keys
      }

      // borrowNFT gets a reference to an NFT in the collection
      // so that the caller can read its metadata and call its methods
      pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
          return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
      }

      pub fun borrowSlushNFT(id: UInt64): &Slush.NFT? {
        if self.ownedNFTs[id] != nil {
          // Create an authorized reference to allow downcasting
          let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
          return ref as! &Slush.NFT
        }

        return nil
      }

      pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
        let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        let Slush = nft as! &Slush.NFT
        return Slush as &AnyResource{MetadataViews.Resolver}
      }

      destroy() {
        destroy self.ownedNFTs
      }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
      return <- create Collection()
    }
}
 