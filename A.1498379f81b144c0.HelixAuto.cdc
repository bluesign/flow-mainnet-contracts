
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

pub contract HelixAuto: NonFungibleToken {
pub event ContractInitialized()

// NFT Counter
  pub var totalSupply: UInt64;

// Events
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, vehicle_type: String, )

// Storage Paths
pub let CollectionStoragePath: StoragePath
pub let CollectionPublicPath: PublicPath
pub let MinterStoragePath: StoragePath

pub enum VehicleType: UInt8 {
  pub case hero
  pub case hunter
  pub case hammer
  pub case hype
  pub case hacker
}

pub fun vehicleTypeToString(_ type: VehicleType): String {
  switch type {
    case VehicleType.hero:
      return "Hero"
    case VehicleType.hunter:
      return "Hunter"
    case VehicleType.hammer:
      return "Hammer"
    case VehicleType.hype:
      return "Hype"
    case VehicleType.hacker:
      return "Hacker"
  }

  return ""
}

pub fun vehicleVinType(_ type: VehicleType): String {
  switch type {
    case VehicleType.hero:
      return "HLX-HR-"
    case VehicleType.hunter:
      return "HLX-HU-"
    case VehicleType.hammer:
      return "HLX-HM-"
    case VehicleType.hype:
      return "HLX-HY-"
    case VehicleType.hacker:
      return "HLX-HK-"
  }

  return ""
}

pub fun vehicleDescriptionType(_ type: VehicleType): String {
    switch type {
    case VehicleType.hero:
      return "Agile handling with a relentless swagger to match, the Helix Hero is the epitome of style and performance."
    case VehicleType.hunter:
      return "Unlike its Hacker counterpart, the Helix Hunter is the optimal cryptocycle for fun and gun missions."
    case VehicleType.hammer:
      return "The workhorse of the Helix AI vehicles, the Helix Hammer is a beautiful blend of uncompromising power, durability and design."
    case VehicleType.hype:
      return "The Helix Hype boasts good looks, big wheels and swag for days. Choose this vehicle if you're ready to let the community buy into your Hype!"
    case VehicleType.hacker:
      return "Blaze by the competition in the nimble Helix Hacker. What this cryptocycle lacks in raw power, it makes up for in top notch speed and maneuverability."
  }

  return ""
}

// NFT Resource
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    // Variables
    pub let id: UInt64
    pub let vehicle_type: VehicleType
    pub let glbCID: String
    pub let imageCID: String

    // Attributes
    pub let traits: {String: AnyStruct}

    //  Metadata fields
    access(self) let royalties: [MetadataViews.Royalty]


    // pub function to send back the NFT name
    // used in the metadata resolver
    pub fun name(): String {
        return "Helix "
        .concat(HelixAuto.vehicleTypeToString(self.vehicle_type))
        .concat(" ")
        .concat(HelixAuto.vehicleVinType(self.vehicle_type))
        .concat(self.id.toString())
    }

    // pub function to send back the NFT description
    // used in the metadata resolver
    pub fun description(): String {
        return HelixAuto.vehicleDescriptionType(self.vehicle_type)
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Traits>(),
        Type<MetadataViews.Royalties>(),
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.Serial>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: self.name(),
            description: self.description(),
            thumbnail: MetadataViews.IPFSFile(
              cid: self.imageCID,
              path: nil
            ),
          )
        case Type<MetadataViews.Traits>():
          let traits: [MetadataViews.Trait] = []

          for key in self.traits.keys {
            traits.append(
              MetadataViews.Trait(name: key, value: self.traits[key], displayType: "String", rarity: nil)
            )
          }

          return MetadataViews.Traits(traits)
        case Type<MetadataViews.Serial>():
            return MetadataViews.Serial(
                self.id
            )
        case Type<MetadataViews.Royalties>():
            return MetadataViews.Royalties(
                self.royalties
            )
        case Type<MetadataViews.ExternalURL>():
            return MetadataViews.ExternalURL("https://www.nft.thecela/helix/showcase/".concat(self.id.toString()))
        case Type<MetadataViews.NFTCollectionData>():
            return MetadataViews.NFTCollectionData(
                storagePath: HelixAuto.CollectionStoragePath,
                publicPath: HelixAuto.CollectionPublicPath,
                providerPath: /private/HelixAutoCollection,
                publicCollection: Type<&HelixAuto.Collection{HelixAuto.HelixAutoCollectionPublic}>(),
                publicLinkedType: Type<&HelixAuto.Collection{HelixAuto.HelixAutoCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&HelixAuto.Collection{HelixAuto.HelixAutoCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-HelixAuto.createEmptyCollection()
                }))
        case Type<MetadataViews.NFTCollectionDisplay>():
            let bannerImage = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://helix.infura-ipfs.io/ipfs/QmXMYU4xzL4ChHHCsuodzStQFuMcfXhvpQ3UVfQ98uJvab"
                ),
                mediaType: "image/png"
            )
            let squareImage = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://helix.infura-ipfs.io/ipfs/QmaWP21VobjXmKV18vSuv6kbJUc7isTGaLmEdgc6MusmM8"
                ),
                mediaType: "image/png"
            )
            return MetadataViews.NFTCollectionDisplay(
                name: self.name(),
                description: self.description(),
                externalURL: MetadataViews.ExternalURL("https://www.helix-auto.com"),
                squareImage: squareImage,
                bannerImage: bannerImage,
                socials: {
                    "twitter": MetadataViews.ExternalURL("https://mobile.twitter.com/helix_auto"),
                    "discord": MetadataViews.ExternalURL("https://discord.com/invite/7vVJewPTY4")
                }
            )
      }

      return nil
    }
    init(_traits: {String: AnyStruct},
         _glbCID: String,
         _imageCID: String,
         _vehicle_type: VehicleType,
         royalties: [MetadataViews.Royalty]
  ) {
      self.id = HelixAuto.totalSupply
      HelixAuto.totalSupply = HelixAuto.totalSupply + (1)

      self.vehicle_type = _vehicle_type
      self.glbCID = _glbCID
      self.imageCID = _imageCID
      self.traits = _traits
      self.royalties = royalties
    }
  }

// Public Collection Interface
  pub resource interface HelixAutoCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowEntireNFT(id: UInt64): &HelixAuto.NFT? {
      // If the result isn't nil, the id of the returned reference
      // should be the same as the argument to the function
      post {
          (result == nil) || (result?.id == id):
              "Cannot borrow VehicleItem reference: The ID of the returned reference is incorrect"
      }
    }
  }

  // Container for NFTs, where users NFT are stored
  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, HelixAutoCollectionPublic, MetadataViews.ResolverCollection {
      // map id of the nft --> nft with that id
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    // Deposit
    pub fun deposit(token: @NonFungibleToken.NFT) {
      // Security to make sure we are depositing an NFT fom this collection
      let ourNft <- token as! @NFT

      emit Deposit(id: ourNft.id, to: self.owner?.address)

      self.ownedNFTs[ourNft.id] <-! ourNft
    }

    // Deposit
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This collection doesn't contain an NFT with that id")

      emit Withdraw(id: withdrawID, from: self.owner?.address)

      return <- token
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
        // get nft from collection
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        // down cast it too this contracts public NFT collection
      let HelixAuto = nft as! &HelixAuto.NFT
        // return downcasted items metadata resolver
      return HelixAuto as &AnyResource{MetadataViews.Resolver}
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // Borrow reference to nft standard
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowEntireNFT(id: UInt64): &HelixAuto.NFT? {
      // If account owns an NFT
      if self.ownedNFTs[id] != nil {
        // get nft, and down cast it too this contracts public NFT collection
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        // Return downcasted item
        return ref as! &HelixAuto.NFT
      } else {
        return nil
      }
    }

    init() {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

    // Create Collection
  pub fun createEmptyCollection():  @Collection {
    return <- create Collection()
  }

    // NFT Minter
  pub resource NFTMinter {
    pub fun mintNFT(
        recipient: &{NonFungibleToken.CollectionPublic},
        _traits: {String: AnyStruct},
        _vehicle_type: VehicleType,
        _glbCID: String,
        _imageCID: String,
        royalties: [MetadataViews.Royalty]
)  {

      recipient.deposit(
        token: <- create HelixAuto.NFT(
            _traits: _traits,
            _glbCID: _glbCID,
            _imageCID: _imageCID,
            _vehicle_type: _vehicle_type,
            royalties: royalties,
            )
        )

       emit Minted(
          id: HelixAuto.totalSupply,
          vehicle_type: HelixAuto.vehicleTypeToString(_vehicle_type),
       )
    }
  }

    // fetch
  // Get a reference to a vehicle item from an account's collection, if available
  // If an account does not have a collection, panic
  // If it has a collection, but does not contain the itemID, return nil
  // If it has a collection and it contains the itemID, return a reference to that
  pub fun fetch(_ from: Address, itemID: UInt64): &HelixAuto.NFT? {
    let collection = getAccount(from)
            .getCapability(HelixAuto.CollectionPublicPath)!
            .borrow<&HelixAuto.Collection{HelixAuto.HelixAutoCollectionPublic}>()
            ?? panic("Couldn't get collection")
    // We trust that HelixAuto.collection.borrowEntireNFT to get the correct itemID
    // (it checks it before returning it)
    return collection.borrowEntireNFT(id: itemID)
  }

  // Contract initialiser, ran everytime contract is deployed
  init() {

    // Init the total supply
    self.totalSupply = 0;

    // set named paths
    self.CollectionStoragePath = /storage/HelixAutoStorageV3
    self.CollectionPublicPath = /public/HelixAutoCollectionV3
    self.MinterStoragePath = /storage/HelixAutoMinterV3

        // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // create a public capability for the collection
    self.account.link<&HelixAuto.Collection{NonFungibleToken.CollectionPublic, HelixAuto.HelixAutoCollectionPublic, MetadataViews.ResolverCollection}>(
        self.CollectionPublicPath,
        target: self.CollectionStoragePath
    )

    // Create the Minter resource and save to storage
    self.account.save(<- create NFTMinter(), to: self.MinterStoragePath)

    emit ContractInitialized()
  }
}
