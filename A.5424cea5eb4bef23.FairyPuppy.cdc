import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract FairyPuppy: NonFungibleToken {
  pub var totalSupply: UInt64
  access(self) var BaseURL: String;

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, metadata: {String:String})
  pub event Burned(id: UInt64, address: Address?)

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    access(self) let metadata: {String:String}
    access(self) let royalties: [MetadataViews.Royalty]

    init(
      metadata: {String:String},
      royalties: [MetadataViews.Royalty]
    ) {
      self.id = FairyPuppy.totalSupply
      self.metadata = metadata
      self.royalties = royalties

      emit Minted(
        id: self.id,
        metadata: self.metadata
      )

      FairyPuppy.totalSupply = FairyPuppy.totalSupply + 1
    }
  
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Royalties>(),
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.Serial>(),
        Type<MetadataViews.Traits>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: self.metadata["name"] ?? "",
            description: self.metadata["description"] ?? "",
            thumbnail: MetadataViews.HTTPFile(
              url: FairyPuppy.BaseURL.concat(self.metadata["fileURI"] ?? "")
            )
          )

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(self.id)
        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties(self.royalties)

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.HTTPFile(
            url: FairyPuppy.BaseURL.concat(self.metadata["fileURI"] ?? "")
          )

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: FairyPuppy.CollectionStoragePath,
            publicPath: FairyPuppy.CollectionPublicPath,
            providerPath: /private/FairyPuppyCollection,
            publicCollection: Type<&FairyPuppy.Collection{NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&FairyPuppy.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&FairyPuppy.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                return <-FairyPuppy.createEmptyCollection()
            })
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: FairyPuppy.BaseURL.concat("logo.png")),
            mediaType: "image/svg"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "FairyPuppy Collection",
            description: "Fairy Puppy starts with a collection of 789 avatars that give you access to The Puppy Wonderland. Fairy Puppy holders receive access to exclusive drops, experiences, and more.",
            externalURL: MetadataViews.ExternalURL("https://twitter.com/fairypuppy_"),
            squareImage: media,
            bannerImage: media,
            socials: {
              "twitter": MetadataViews.ExternalURL("https://twitter.com/fairypuppy_")
            }
          )
        case Type<MetadataViews.Traits>():
          return MetadataViews.dictToTraits(dict: self.metadata, excludedNames: [])      
      }
      return nil
    }

    destroy() {
      emit Burned(id: self.id, address: self.owner?.address)
    }
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowFairyPuppy(id: UInt64): &FairyPuppy.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow FairyPuppy reference: the ID of the returned reference is incorrect"
      }
    }
  }

  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    // dictionary of NFT conforming tokens
    // NFT is a resource type with an `UInt64` ID field
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init () {
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
      let token <- token as! @FairyPuppy.NFT

      let id: UInt64 = token.id

      // add the new token to the dictionary which removes the old one
      let oldToken <- self.ownedNFTs[id] <- token

      emit Deposit(id: id, to: self.owner?.address)

      destroy oldToken
    }

    // transfer takes an NFT ID and a reference to a recipient's collection
    // and transfers the NFT corresponding to that ID to the recipient
    pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not transferred"
        recipient.borrowNFT(id: id) != nil: "Recipient did not receive the intended NFT"
      }

      let nft <- self.withdraw(withdrawID: id)
      
      recipient.deposit(token: <- nft)
    }

    // burn destroys an NFT
    pub fun burn(id: UInt64) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not burned"
      }

      // This will emit a burn event
      destroy <- self.withdraw(withdrawID: id)
    }

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrowNFT gets a reference to an NFT in the collection
    // so that the caller can read its metadata and call its methods
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      if self.ownedNFTs[id] != nil {
        return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
      }
      panic("NFT not found in collection.")
    }

    pub fun borrowFairyPuppy(id: UInt64): &FairyPuppy.NFT? {  
      if self.ownedNFTs[id] != nil {
        // Create an authorized reference to allow downcasting
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &FairyPuppy.NFT
      }
      return nil
    }
      
    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      if self.ownedNFTs[id] != nil {
        let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
        if nft != nil {
          return nft! as! &FairyPuppy.NFT
        }
      }
      panic("NFT not found in collection.")
    }

    destroy() {
        destroy self.ownedNFTs
    }
  }

  // public function that anyone can call to create a new empty collection
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // Resource that an admin or something similar would own to be
  // able to mint new NFTs
  //
  pub resource NFTMinter {
    // transformMetadata ensures that the NFT metadata follows a particular
    // schema. At the moment, it is much more convenient to use functions
    // rather than structs to enforce a metadata schema because functions 
    // are much more flexible, easier to maintain, and safer to update.
    access(self) fun transformMetadata(_ metadata: {String:String}): {String:String} {
      pre {
        metadata.containsKey("name")
        && metadata.containsKey("description")
        && metadata.containsKey("fileURI")
        && metadata.containsKey("background")
        && metadata.containsKey("fur")
        && metadata.containsKey("dominance")
        && metadata.containsKey("ears")
        && metadata.containsKey("accessories")
        : "Metadata does not conform to schema"
      }
      return {
        "name": metadata["name"]!,
        "description": metadata["description"]!,
        "fileURI": metadata["fileURI"]!,
        "background": metadata["background"]!,
        "fur": metadata["fur"]!,
        "dominance": metadata["dominance"]!,
        "ears": metadata["ears"]!,
        "accessories": metadata["accessories"]!
      }
    }

    // mintNFT mints a new NFT with a new ID
    // and deposit it in the recipients collection using their collection reference
    pub fun mintNFT(
      recipient: &{NonFungibleToken.CollectionPublic},
      royalties: [MetadataViews.Royalty],
      metadata: {String:String},
    ) {
      // create a new NFT
      let newNFT <- create NFT(
        metadata: self.transformMetadata(metadata),
        royalties: royalties
      )

      // deposit it in the recipient's account using their reference
      recipient.deposit(token: <-newNFT)
    }

    pub fun setBaseUrl(url: String) {
      FairyPuppy.BaseURL = url
    }
  }

  init() {
    // Initialize the total supply
    self.totalSupply = 0
    self.BaseURL = "";

    // Set the named paths
    self.CollectionStoragePath = /storage/fairyPuppyCollection
    self.CollectionPublicPath = /public/fairyPuppyCollection
    self.MinterStoragePath = /storage/fairyPuppyMinter

    // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // create a public capability for the collection
    self.account.link<&FairyPuppy.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
      self.CollectionPublicPath, 
      target: self.CollectionStoragePath
    )

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    emit ContractInitialized()
  }
}
 