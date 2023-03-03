/*
    Description: Central Smart Contract for Chapter2 Bikes
    
    This smart contract contains the core functionality for 
    Chapter2 Bikes, created by Ethos Multiverse Inc.
    
    The contract manages the data associated with each NFT and 
    the distribution of each NFT to recipients.
    
    Admins throught their admin resource object have the power 
    to do all of the important actions in the smart contract such 
    as minting and batch minting.
    
    When NFTs are minted, they are initialized with a metadata object and an Edition type and then
    stored in the admins Collection.
    
    The contract also defines a Collection resource. This is an object that 
    every Chapter2 NFT owner will store in their account
    to manage their NFT collection.
    
    The main Chapter2 Bikes account operated by Ethos Multiverse Inc. 
    will also have its own Chapter2 collection it can use to hold its 
    own NFT's that have not yet been sent to a user.
    
    Note: All state changing functions will panic if an invalid argument is
    provided or one of its pre-conditions or post conditions aren't met.
    Functions that don't modify state will simply return 0 or nil 
    and those cases need to be handled by the caller.
*/

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Chapter2Bikes: NonFungibleToken {

  // -----------------------------------------------------------------------
  // Chapter2Bikes contract Events
  // -----------------------------------------------------------------------

  // Emited when the Chapter2Bikes contract is created
  pub event ContractInitialized()

  // Emmited when a user transfers a Chapter2Bikes NFT out of their collection
  pub event Withdraw(id: UInt64, from: Address?)

  // Emmited when a user recieves a Chapter2Bikes NFT into their collection
  pub event Deposit(id: UInt64, to: Address?)

  // Emmited when a Chapter2Bikes NFT is minted
  pub event Minted(id: UInt64)

  // -----------------------------------------------------------------------
  // Chapter2Bikes Named Paths
  // -----------------------------------------------------------------------

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath
  pub let AdminPrivatePath: PrivatePath

  // -----------------------------------------------------------------------
  // Chapter2Bikes contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------

  // The total number of Chapter2Bikes NFTs that have been created
  // Because NFTs can be destroyed, it doesn't necessarily mean that this
  // reflects the total number of NFTs in existence, just the number that
  // have been minted to date. Also used as NFT IDs for minting.
  pub var totalSupply: UInt64

  // The total number of Chapter2Bikes Frame edition NFTs that have been created
  // Because NFTs can be destroyed, it doesn't necessarily mean that this
  // reflects the total number of NFTs in existence, just the number that
  // have been minted to date. Also used as NFT IDs for minting.
  pub var frameEditionSupply: UInt64

  // The total number of Chapter2Bikes Painting edition NFTs that have been created
  // Because NFTs can be destroyed, it doesn't necessarily mean that this
  // reflects the total number of NFTs in existence, just the number that
  // have been minted to date. Also used as NFT IDs for minting.
  pub var paintingEditionSupply: UInt64

  // -----------------------------------------------------------------------
  // Chapter2Bikes contract-level Composite Type definitions
  // -----------------------------------------------------------------------
  // These are just *definitions* for Types that this contract
  // and other accounts can use. These definitions do not contain
  // actual stored values, but an instance (or object) of one of these Types
  // can be created by this contract that contains stored values.
  // -----------------------------------------------------------------------

  // Enum that represents a Chapter2Bikes NFT Edition type
  //
  pub enum Edition: UInt8 {
    pub case Frame
    pub case Painting
  }

  // The resource that represents the Chapter2Bikes NFTs
  //
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64

    pub let edition: Edition

    pub var metadata: {String: String}

    init(_edition: Chapter2Bikes.Edition, _metadata: {String: String}) {
      self.id = Chapter2Bikes.totalSupply
      self.edition = _edition
      self.metadata = _metadata

      // Total Supply
      Chapter2Bikes.totalSupply = Chapter2Bikes.totalSupply + 1

      // Edition Supply
      if (_edition == Edition.Frame) {
        Chapter2Bikes.frameEditionSupply = Chapter2Bikes.frameEditionSupply + 1
      } else if (_edition == Edition.Painting) {
        Chapter2Bikes.paintingEditionSupply = Chapter2Bikes.paintingEditionSupply + 1
      } else {
        // Invalid Edition
        panic("Edition is invalid. Options: 0(Frame) or 1(Painting)")
      }

      // Emit Minted Event
      emit Minted(id: self.id)
    }

    pub fun getViews(): [Type] {
      return [
          Type<MetadataViews.Display>(),
          Type<MetadataViews.Editions>(),
          Type<MetadataViews.NFTCollectionData>(),
          Type<MetadataViews.NFTCollectionDisplay>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
          case Type<MetadataViews.Display>():
            return MetadataViews.Display(
                name: self.metadata["name"]!,
                description: self.metadata["description"]!,
                thumbnail: MetadataViews.HTTPFile(url: self.metadata["external_url"]!)
            )
          case Type<MetadataViews.Editions>():
            // 50 Frame editions and 20 Painting editions
            let frameEditionInfo = MetadataViews.Edition(name: "Chapter2 B Harms Special Projects: Owners NFT 2022", number: self.id, max: 50)
            let paintingEditionInfo = MetadataViews.Edition(name: "B Harms Special Projects: “the second chapter”", number: self.id, max: 20)
            let editionList: [MetadataViews.Edition] = [frameEditionInfo, paintingEditionInfo]
            return MetadataViews.Editions(editionList)
          case Type<MetadataViews.ExternalURL>():
            return MetadataViews.ExternalURL("https://chapter2bikes.ethosnft.com")
          case Type<MetadataViews.NFTCollectionData>():
            return MetadataViews.NFTCollectionData(
                storagePath: Chapter2Bikes.CollectionStoragePath,
                publicPath: Chapter2Bikes.CollectionPublicPath,
                providerPath: /private/Chapter2BikesCollection,
                publicCollection: Type<&Chapter2Bikes.Collection{Chapter2Bikes.CollectionPublic}>(),
                publicLinkedType: Type<&Chapter2Bikes.Collection{Chapter2Bikes.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&Chapter2Bikes.Collection{Chapter2Bikes.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                  return <- Chapter2Bikes.createEmptyCollection()
                })
            )
          case Type<MetadataViews.NFTCollectionDisplay>():
            let ipfsHash = self.metadata["ipfsHash"]!
            let url = "https://ethos.mypinata.cloud/ipfs/".concat(ipfsHash)
            let frameMedia = MetadataViews.Media(
              file: MetadataViews.HTTPFile(url: url.concat("chapter2-bharms-koko-aero-frame.mp4")),
              mediaType: "video/mp4"
            )
            let paintingMedia = MetadataViews.Media(
              file: MetadataViews.HTTPFile(url: url.concat("chapter2-bharms-the-second-chapter.mp4")),
              mediaType: "video/mp4"
            )
            return MetadataViews.NFTCollectionDisplay(
              name: "Chapter2 Frame and Painting Collection",
              description: "For the past number of years, Bradley Harms has taken a leading role in a new and forward-looking wave of Canadian abstraction, building upon traditions within the medium, while creating work that both reflects and critiques contemporary social and technological developments.",
              externalURL: MetadataViews.ExternalURL("https://chapter2.ethosnft.com"),
              frameImage: frameMedia,
              paintingImage: paintingMedia,
              socials: {
                "instagram": MetadataViews.ExternalURL("https://www.instagram.com/chapter2bikes")
              }
            )
      }
      return nil 
    }

  }

  // The interface that users can cast their Chapter2Bikes Collection as
  // to allow others to deposit Chapter2Bikes into thier Collection. It also
  // allows for the reading of the details of Chapter2Bikes
  pub resource interface CollectionPublic {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowEntireNFT(id: UInt64): &Chapter2Bikes.NFT?
  }

  // Collection is a resource that every user who owns NFTs
  // will store in their account to manage their NFTs
  pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection {
    // dictionary of NFT conforming tokens
    // NFT is a resource type with an UInt64 ID field
    //
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    
    // withdraw
    // Removes an NFT from the collection and moves it to the caller
    //
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Token not found")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <- token
    }

    // deposit
    // Takes a NFT and adds it to the collections dictionary
    //
    pub fun deposit(token: @NonFungibleToken.NFT) {
      let myToken <- token as! @Chapter2Bikes.NFT
      emit Deposit(id: myToken.id, to: self.owner?.address)
      self.ownedNFTs[myToken.id] <-! myToken
    }

    // getIDs returns an arrat of the IDs that are in the collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrowNFT Returns a borrowed reference to a Chapter2Bikes NFT in the Collection
    // so that the caller can read its ID
    //
    // Parameters: id: The ID of the NFT to get the reference for
    //
    // Returns: A reference to the NFT
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    // borrowEntireNFT returns a borrowed reference to a Chapter2Bikes 
    // NFT so that the caller can read its data.
    // They can use this to read its id, description, and edition.
    //
    // Parameters: id: The ID of the NFT to get the reference for
    //
    // Returns: A reference to the NFT
    pub fun borrowEntireNFT(id: UInt64): &Chapter2Bikes.NFT? {
      if self.ownedNFTs[id] != nil {
        let reference = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return reference as! &Chapter2Bikes.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let chapter2NFT = nft as! &Chapter2Bikes.NFT
      return chapter2NFT as &AnyResource{MetadataViews.Resolver}
    }

    init() {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs 
    }
  }

  // Admin is a special authorization resource that
  // allows the owner to perform important NFT
  // functions
  pub resource Admin {
    // mint
    // Mints an new NFT
    // and deposits it in the Admins collection
    //
    pub fun mint(recipient: &{NonFungibleToken.CollectionPublic}, edition: Chapter2Bikes.Edition, metadata: {String: String}) {
        // create a new NFT 
        var newNFT <- create NFT(_edition: edition, _metadata: metadata)

        // Deposit it in Admins account using their reference
        recipient.deposit(token: <- newNFT)
    }

    // batchMint
    // Batch mints Chapter2Bikes NFTs
    // and deposits in the Admins collection
    //
    pub fun batchMint(recipient: &{NonFungibleToken.CollectionPublic}, edition: Chapter2Bikes.Edition, metadataArray: [{String: String}]) {
        var i: Int = 0
        while i < metadataArray.length {
            self.mint(recipient: recipient, edition: edition, metadata: metadataArray[i])
            i = i + 1;
        }
    }

    pub fun createNewAdmin(): @Admin {
        return <- create Admin()
    }
  }

  // The interface that Admins can use to give adminRights to other users
  pub resource interface AdminProxyPublic {
    pub fun giveAdminRights(cap: Capability<&Admin>)
  }

  // AdminProxy is a resource that allows the owner to give admin rights to other users
  pub resource AdminProxy: AdminProxyPublic {
    access(self) var cap: Capability<&Admin>

    init() {
      self.cap = nil!
    }

    pub fun giveAdminRights(cap: Capability<&Admin>) {
      pre {
        self.cap == nil : "Capability is already set."
      }
      self.cap = cap
    }

    pub fun checkAdminRights(): Bool {
      return self.cap.check()
    }

    access(self) fun borrow(): &Admin {
      pre {
        self.cap != nil : "Capability is not set."
        self.checkAdminRights() : "Admin unliked capability."
      }
      return self.cap.borrow()!
    }

    pub fun mint(recipient: &{NonFungibleToken.CollectionPublic}, edition: Chapter2Bikes.Edition, metadata: {String: String}) {
      let admin = self.borrow()
      admin.mint(recipient: recipient, edition: edition, metadata: metadata)
    }

    pub fun batchMint(recipient: &{NonFungibleToken.CollectionPublic}, edition: Chapter2Bikes.Edition, metadataArray: [{String: String}]) {
      let admin = self.borrow()
      admin.batchMint(recipient: recipient, edition: edition, metadataArray:metadataArray)
    }
  }

  // -----------------------------------------------------------------------
  // Chapter2Bikes contract-level function definitions
  // -----------------------------------------------------------------------

  // createEmptyCollection
  // public function that anyone can call to create a new empty collection
  //
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // editionToString
  // public function that anyone can call to convert an edition to a string
  //
  pub fun editionString(_ edition: Edition): String {
    switch edition {
      case Edition.Frame:
        return "Frame"
      case Edition.Painting:
        return "Painting"
    }
    return ""
  }

  // -----------------------------------------------------------------------
  // Chapter2Bikes initialization function
  // -----------------------------------------------------------------------
  //

  // initializer
  //
  init() {
    // Initialize supply: total, frame, painting
    self.totalSupply = 0
    self.frameEditionSupply = 0
    self.paintingEditionSupply = 0

    // Set named paths
    self.CollectionStoragePath = /storage/Chapter2BikesCollection
    self.CollectionPublicPath = /public/Chapter2BikesCollection
    self.AdminStoragePath = /storage/Chapter2BikesAdmin
    self.AdminPrivatePath = /private/Chapter2BikesAdminUpgrade

    // Create admin resource and save it to storage
    self.account.save(<-create Admin(), to: self.AdminStoragePath)

    // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // Create a public capability for the collection
    self.account.link<&Chapter2Bikes.Collection{NonFungibleToken.CollectionPublic, Chapter2Bikes.CollectionPublic, MetadataViews.ResolverCollection}>(
      self.CollectionPublicPath,
      target: self.CollectionStoragePath
    )

    // Create a private capability fot the admin resource
    self.account.link<&Chapter2Bikes.Admin>(self.AdminPrivatePath, target: self.AdminStoragePath) ?? panic("Could not get Admin capability")

    emit ContractInitialized()
  }

}