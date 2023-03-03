/*
    Description: Central Smart Contract for ethosFutureRewardsProgram
    
    This smart contract contains the core functionality for 
    ethosFutureRewardsProgram, created by ethos Multiverse Inc.
    
    The contract manages the data associated with each NFT and 
    the distribution of each NFT to recipients.
    
    Admins throught their admin resource object have the power 
    to do all of the important actions in the smart contract such 
    as minting and batch minting.
    
    When NFTs are minted, they are initialized with a metadata object and then
    stored in the admins Collection.
    
    The contract also defines a Collection resource. This is an object that 
    every ethosFutureRewardsProgram NFT owner will store in their account
    to manage their NFT collection.
    
    The main ethosFutureRewardsProgram account operated by ethos Multiverse Inc. 
    will also have its own ethosFutureRewardsProgram collection it can use to hold its 
    own NFT's that have not yet been sent to users.
    
    Note: All state changing functions will panic if an invalid argument is
    provided or one of its pre-conditions or post conditions aren't met.
    Functions that don't modify state will simply return 0 or nil 
    and those cases need to be handled by the caller.
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import FlowToken from 0x1654653399040a61

pub contract ethosFutureRewardsProgram: NonFungibleToken {

  // -----------------------------------------------------------------------
  // ethosFutureRewardsProgram contract Events
  // -----------------------------------------------------------------------

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, metadataId: UInt64)
  pub event BatchMint(metadataIds: [UInt64])

  // -----------------------------------------------------------------------
  // ethosFutureRewardsProgram Named Paths
  // -----------------------------------------------------------------------

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
	pub let CollectionPrivatePath: PrivatePath
  pub let AdminStoragePath: StoragePath
  pub let AdminPrivatePath: PrivatePath

  // -----------------------------------------------------------------------
  // ethosFutureRewardsProgram contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------

  // Collection Information
  access(self) let collectionInfo: {String: AnyStruct}

  // Array of all existing ethosFutureRewardsProgram NFTs
	access(account) let metadatas: {UInt64: NFTMetadata}

  access(account) let nftStorage: @{Address: {UInt64: NFT}}

	// Contract Information
	pub var nextEditionId: UInt64
	pub var nextMetadataId: UInt64
	pub var totalSupply: UInt64

  // -----------------------------------------------------------------------
  // ethosFutureRewardsProgram contract-level Composite Type definitions
  // -----------------------------------------------------------------------

  // The struct that represents the ethosFutureRewardsProgram Metadata
	pub struct NFTMetadata {
		pub let metadataId: UInt64
		pub let name: String
		pub let description: String 
		// The main image of the NFT
		pub let image: MetadataViews.IPFSFile
		// An optional thumbnail that can go along with it
		// for easier loading
		pub let thumbnail: MetadataViews.IPFSFile?

		pub var extra: {String: AnyStruct}

		init(_name: String, _description: String, _image: MetadataViews.IPFSFile, _thumbnail: MetadataViews.IPFSFile?, _extra: {String: AnyStruct}) {
			self.metadataId = ethosFutureRewardsProgram.nextMetadataId
			self.name = _name
			self.description = _description
			self.image = _image
			self.thumbnail = _thumbnail
			self.extra = _extra
		}
	}

  // The resource that represents the ethosFutureRewardsProgram NFTs
  //
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
      // The 'id' is the same as the 'uuid'
      pub let id: UInt64
      // The 'metadataId' is what maps this NFT to its 'NFTMetadata'
      pub let metadataId: UInt64

      pub fun getMetadata(): NFTMetadata {
        return ethosFutureRewardsProgram.getNFTMetadata(self.metadataId)!
      }

      pub fun getViews(): [Type] {
        return [
            Type<MetadataViews.Display>(),
            Type<MetadataViews.ExternalURL>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>(),
            Type<MetadataViews.Royalties>(),
            Type<MetadataViews.Traits>(),
            Type<MetadataViews.NFTView>()

        ]
      }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          let metadata = self.getMetadata()
          return MetadataViews.Display(
            name: metadata.name,
            description: metadata.description,
            thumbnail: metadata.thumbnail ?? metadata.image
          )
        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: ethosFutureRewardsProgram.CollectionStoragePath,
            publicPath: ethosFutureRewardsProgram.CollectionPublicPath,
            providerPath: ethosFutureRewardsProgram.CollectionPrivatePath,
            publicCollection: Type<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection, NonFungibleToken.Provider}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                return <- ethosFutureRewardsProgram.createEmptyCollection()
            })
          )
        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL("https://future.ethosnft.com")
        case Type<MetadataViews.NFTCollectionDisplay>():
          let squareMedia = MetadataViews.Media(
            file: ethosFutureRewardsProgram.getCollectionAttribute(key: "image") as! MetadataViews.IPFSFile,
            mediaType: "image"
          )

          // If a banner image exists, use it
          // Otherwise, default to the main square image
          var bannerMedia: MetadataViews.Media? = nil
          if let bannerImage = ethosFutureRewardsProgram.getOptionalCollectionAttribute(key: "bannerImage") as! MetadataViews.IPFSFile? {
            bannerMedia = MetadataViews.Media(
              file: bannerImage,
              mediaType: "image"
            )
          }
          return MetadataViews.NFTCollectionDisplay(
            name: ethosFutureRewardsProgram.getCollectionAttribute(key: "name") as! String,
            description: ethosFutureRewardsProgram.getCollectionAttribute(key: "description") as! String,
            externalURL: MetadataViews.ExternalURL("https://future.ethosnft.com"),
            squareImage: squareMedia,
            bannerImage: bannerMedia ?? squareMedia,
            socials: ethosFutureRewardsProgram.getCollectionAttribute(key: "socials") as! {String: MetadataViews.ExternalURL}
          )
        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties([
            // For ethos Multiverse Inc. in favor of producing Jade, a tool for deploying NFT contracts and minting/managing collections.
            MetadataViews.Royalty(
              recepient: getAccount(0xf92e92030f2701df).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
              cut: 0.025, // 2.5% royalty on secondary sales
              description: "ethos Multiverse Inc. receives a 2.5% royalty from secondary sales because this collection was created using Jade (https://jade.ethosnft.com), a tool for deploying NFT contracts and minting/managing collections, created by ethos Multiverse Inc."
            )
          ])
        case Type<MetadataViews.Traits>():
          return MetadataViews.dictToTraits(dict: self.getMetadata().extra, excludedNames: nil)
        case Type<MetadataViews.NFTView>():
          return MetadataViews.NFTView(
            id: self.id,
            uuid: self.uuid,
            display: self.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?,
            externalURL: self.resolveView(Type<MetadataViews.ExternalURL>()) as! MetadataViews.ExternalURL?,
            collectionData: self.resolveView(Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?,
            collectionDisplay: self.resolveView(Type<MetadataViews.NFTCollectionDisplay>()) as! MetadataViews.NFTCollectionDisplay?,
            royalties: self.resolveView(Type<MetadataViews.Royalties>()) as! MetadataViews.Royalties?,
            traits: self.resolveView(Type<MetadataViews.Traits>()) as! MetadataViews.Traits?
          )
      }
      return nil
    }

		init(_metadataId: UInt64) {
			pre {
				ethosFutureRewardsProgram.metadatas[_metadataId] != nil:
					"This NFT does not exist yet."
			}
			self.id = ethosFutureRewardsProgram.totalSupply + 1 // Start at 1
			self.metadataId = _metadataId

			ethosFutureRewardsProgram.totalSupply = ethosFutureRewardsProgram.totalSupply + 1
			emit Minted(id: self.id, metadataId: _metadataId)
		}
  }

  // Collection is a resource that every user who owns NFTs
  // will store in their account to manage their NFTs
  pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    // dictionary of NFT conforming tokens
    // NFT is a resource type with an UInt64 ID field
    //
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    
    // withdraw
    // Removes an NFT from the collection and moves it to the caller
    //
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

      emit Withdraw(id: token.id, from: self.owner?.address)

      return <- token
    }

    // deposit
    // Takes a NFT and adds it to the collections dictionary
    //
    pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @NFT

			let id: UInt64 = token.id

			// add the new token to the dictionary
			self.ownedNFTs[id] <-! token

			emit Deposit(id: id, to: self.owner?.address)
    }

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrowNFT Returns a borrowed reference to a ethosFutureRewardsProgram NFT in the Collection
    // so that the caller can read its ID
    //
    // Parameters: id: The ID of the NFT to get the reference for
    //
    // Returns: A reference to the NFT
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

		pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
			let token = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
			let nft = token as! &NFT
			return nft as &AnyResource{MetadataViews.Resolver}
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

		pub fun createNFTMetadata(name: String, description: String, imagePath: String, thumbnailPath: String?, ipfsCID: String, extra: {String: AnyStruct}) {
			ethosFutureRewardsProgram.metadatas[ethosFutureRewardsProgram.nextMetadataId] = NFTMetadata(
				_name: name,
				_description: description,
				_image: MetadataViews.IPFSFile(
					cid: ipfsCID,
					path: imagePath
				),
				_thumbnail: thumbnailPath == nil ? nil : MetadataViews.IPFSFile(cid: ipfsCID, path: thumbnailPath),
				_extra: extra
			)
			ethosFutureRewardsProgram.nextMetadataId = ethosFutureRewardsProgram.nextMetadataId + 1
		}

    // mint
    // Mints an new NFT
    // and deposits it in the Admins collection
    //
    pub fun mintNFT(metadataId: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
			let nft <- create NFT(_metadataId: metadataId)

      // Deposit it in Admins account using their reference
      recipient.deposit(token: <- nft)
    }

    // batchMint
    // Batch mints ethosFutureRewardsProgram NFTs
    // and deposits in the Admins collection
    //
    pub fun batchMint(metadataIds: [UInt64], recipient: &{NonFungibleToken.CollectionPublic}) {
			// pre {
			// 	metadataIds.length == recipients.length: "You need to pass in an equal number of metadataIds and recipients."
			// }
			var i = 0
			while i < metadataIds.length {
				self.mintNFT(metadataId: metadataIds[i], recipient: recipient)
				i = i + 1
			}

			emit BatchMint(metadataIds: metadataIds)
    }

    // updateCollectionInfo
    // change piece of collection info
    pub fun updateCollectionInfo(key: String, value: AnyStruct) {
      ethosFutureRewardsProgram.collectionInfo[key] = value
    }

    pub fun createNewAdmin(): @Admin {
        return <- create Admin()
    }
  }

  // The interface that Admins can use to give adminRights to other users
  pub resource interface AdminProxyPublic {
    pub fun giveAdminRights(cap: Capability<&Admin>)
  }

  // AdminProxy is a special proxy resource that
  // allows the owner to give adminRights to other users
  // to perform important NFT functions
  // This proxy resource an also be unlinked, which
  // removes the adminRights from the user
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

    pub fun mintNFT(metadataId: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
			let nft <- create NFT(_metadataId: metadataId)

      // Deposit it in Admins account using their reference
      recipient.deposit(token: <- nft)
    }

    pub fun batchMint(metadataIds: [UInt64], recipient: &{NonFungibleToken.CollectionPublic}) {
			// pre {
			// 	metadataIds.length == recipients.length: "You need to pass in an equal number of metadataIds and recipients."
			// }
			var i = 0
			while i < metadataIds.length {
				self.mintNFT(metadataId: metadataIds[i], recipient: recipient)
				i = i + 1
			}

			emit BatchMint(metadataIds: metadataIds)
    }

    pub fun updateCollectionInfo(key: String, value: AnyStruct) {
      let admin = self.borrow()
      admin.updateCollectionInfo(key: key, value: value)
    }
  }

  // -----------------------------------------------------------------------
  // ethosFutureRewardsProgram contract-level function definitions
  // -----------------------------------------------------------------------

  // createEmptyCollection
  // public function that anyone can call to create a new empty collection
  //
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // getNFTMetadata
  // public function that anyone can call to get information about a NFT
  //
  pub fun getNFTMetadata(_ metadataId: UInt64): NFTMetadata? {
		return self.metadatas[metadataId]
  }

  // getNFTMetadatas
  // public function that anyone can call to get all NFT metadata
  pub fun getNFTMetadatas(): {UInt64: NFTMetadata} {
		return self.metadatas
	}

  // getCollectionInfo
  // public function that anyone can call to get information about the collection
  //
  pub fun getCollectionInfo(): {String: AnyStruct} {
		let collectionInfo = self.collectionInfo
		collectionInfo["metadatas"] = self.metadatas
		collectionInfo["totalSupply"] = self.totalSupply
		collectionInfo["nextMetadataId"] = self.nextMetadataId
		collectionInfo["version"] = 1
		return collectionInfo
	}

  // getCollectionAttribute
  // public function that anyone can call to get a specific piece of collection info
  //
  pub fun getCollectionAttribute(key: String): AnyStruct {
		return self.collectionInfo[key] ?? panic(key.concat(" is not an attribute in this collection."))
	}

  // getOptionalCollectionAttribute
  // public function that anyone can call to get an optional piece of collection info
  //
  pub fun getOptionalCollectionAttribute(key: String): AnyStruct? {
		return self.collectionInfo[key]
	}

  // canMint
  // public function that anyone can call to check if the contract can mint more NFTs
  //
  pub fun canMint(): Bool {
		return self.getCollectionAttribute(key: "minting") as! Bool
	}

  // -----------------------------------------------------------------------
  // ethosFutureRewardsProgram initialization function
  // -----------------------------------------------------------------------

  // initializer
  //
  init(_collectionName: String, _description: String, _imagePath: String, _bannerImagePath: String?, _minting: Bool, _ipfsCID: String) {
    // Set contract level fields
    self.collectionInfo = {}
    self.collectionInfo["name"] = _collectionName
    self.collectionInfo["description"] = _description
    self.collectionInfo["image"] = MetadataViews.IPFSFile(cid: _ipfsCID, path: _imagePath)
		if let bannerImagePath = _bannerImagePath {
			self.collectionInfo["bannerImage"] = MetadataViews.IPFSFile(
				cid: _ipfsCID,
				path: _bannerImagePath
			)
		}
		self.collectionInfo["ipfsCID"] = _ipfsCID
		self.collectionInfo["minting"] = _minting
		self.collectionInfo["dateCreated"] = getCurrentBlock().timestamp

    self.nextMetadataId = 1
    self.nextEditionId = 0
    self.totalSupply = 0
    self.metadatas = {}
    self.nftStorage <- {} 

    // Set named paths
    self.CollectionStoragePath = /storage/ethosFutureRewardsProgramCollection
    self.CollectionPublicPath = /public/ethosFutureRewardsProgramCollection
    self.CollectionPrivatePath = /private/ethosFutureRewardsProgramCollection
    self.AdminStoragePath = /storage/ethosFutureRewardsProgramAdmin
    self.AdminPrivatePath = /private/ethosFutureRewardsProgramAdminUpgrade

    // Create admin resource and save it to storage
    self.account.save(<-create Admin(), to: self.AdminStoragePath)

    // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // Create a public capability for the collection
		self.account.link<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
			self.CollectionPublicPath,
			target: self.CollectionStoragePath
		)

    // Create a private capability for the admin resource
    self.account.link<&ethosFutureRewardsProgram.Admin>(self.AdminPrivatePath, target: self.AdminStoragePath) ?? panic("Could not get Admin capability")

    emit ContractInitialized()
  }
}
 