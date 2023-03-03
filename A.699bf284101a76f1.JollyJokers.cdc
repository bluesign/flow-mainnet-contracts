// SPDX-License-Identifier: MIT

/*
*  This is a 5,000 supply based NFT collection named Jolly Jokers with minimal metadata.
*/

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract JollyJokers: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var maxSupply: UInt64
    pub var baseURI: String
    pub var price: UFix64
    pub var name: String
    pub var description: String
    pub var thumbnails: {UInt64: String}
    access(contract) var metadatas: {UInt64: {String: AnyStruct}}
    access(contract) var traits: {UInt64: {String: String}}

    pub event ContractInitialized()
    pub event BaseURISet(newBaseURI: String)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, to: Address?)
    pub event Withdraw(id: UInt64, from: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let name: String
        pub let description: String
        access(self) let metadata: {String: AnyStruct}

        init(id: UInt64, metadata: {String: AnyStruct}) {
            self.id = id
            self.name = JollyJokers.name.concat(" #").concat(id.toString())
            self.description = JollyJokers.description
            self.metadata = metadata
        }

        pub fun getThumbnail(): String {
            return JollyJokers.thumbnails[self.id] ?? JollyJokers.baseURI.concat(self.id.toString()).concat(".png")
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(url: self.getThumbnail())
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Jolly Jokers Edition", number: self.id, max: JollyJokers.maxSupply)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(editionList)
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://otmnft-jj.s3.amazonaws.com/Jolly_Jokers.png")
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                          url: "https://otmnft-jj.s3.amazonaws.com/Jolly_Jokers.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Jolly Jokers",
                        description: "The Jolly Joker Sports Society is a collection of 5,000 NFTs living on the Flow blockchain",
                        externalURL: MetadataViews.ExternalURL("https://www.jollyjokersnft.com/"), // TODO: jolly jokers minting page
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                          "twitter": MetadataViews.ExternalURL("https://twitter.com/jollyjokersnft") // TODO: jolly jokers twitter url
                        }
                    )
                case Type<MetadataViews.Traits>():
                    return MetadataViews.dictToTraits(dict: JollyJokers.traits[self.id] ?? {}, excludedNames: [])

                case Type<MetadataViews.Royalties>():
                  return MetadataViews.Royalties([])

                case Type<MetadataViews.NFTCollectionData>():
                  return MetadataViews.NFTCollectionData(
                    storagePath: JollyJokers.CollectionStoragePath,
                    publicPath: JollyJokers.CollectionPublicPath,
                    providerPath: /private/findCharityCollection,
                    publicCollection: Type<&JollyJokers.Collection{JollyJokers.JollyJokersCollectionPublic}>(),
                    publicLinkedType: Type<&JollyJokers.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, JollyJokers.JollyJokersCollectionPublic, MetadataViews.ResolverCollection}>(),
                    providerLinkedType: Type<&JollyJokers.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, JollyJokers.JollyJokersCollectionPublic, MetadataViews.ResolverCollection}>(),
                    createEmptyCollectionFunction: fun () : @NonFungibleToken.Collection {
                      return <- JollyJokers.createEmptyCollection()
                    }
                  )
            }
            return nil
        }
    }

    pub resource interface JollyJokersCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowJollyJokers(id: UInt64): &JollyJokers.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow JollyJokers reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: JollyJokersCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
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
            let token <- token as! @JollyJokers.NFT

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

        pub fun borrowJollyJokers(id: UInt64): &JollyJokers.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &JollyJokers.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let jokersNFT = nft as! &JollyJokers.NFT
            return jokersNFT as &AnyResource{MetadataViews.Resolver}
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
        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}) {
            pre {
                JollyJokers.totalSupply < JollyJokers.maxSupply: "Total supply reached maximum limit"
            }
            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedAt"] = currentBlock.timestamp
            metadata["minter"] = recipient.owner!.address

            // create a new NFT
            JollyJokers.totalSupply = JollyJokers.totalSupply + UInt64(1)

            var newNFT <- create NFT(id: JollyJokers.totalSupply, metadata: metadata)

            emit Mint(id: JollyJokers.totalSupply, to: recipient.owner?.address)

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }
    }

	// Admin is a special authorization resource that allows the owner
	// to create or update SKUs and to manage baseURI
	//
	pub resource Admin {
		pub fun setBaseURI(newBaseURI: String) {
			JollyJokers.baseURI = newBaseURI
			emit BaseURISet(newBaseURI: newBaseURI)
		}

      pub fun setMaxSupply(newMaxSupply: UInt64) {
          JollyJokers.maxSupply = newMaxSupply
      }

      pub fun setPrice(newPrice: UFix64) {
          JollyJokers.price = newPrice
      }

      pub fun setMetadata(name: String, description: String) {
          JollyJokers.name = name
          JollyJokers.description = description
      }

      pub fun setThumbnail(id: UInt64, thumbnail: String) {
          JollyJokers.thumbnails[id] = thumbnail
      }

      pub fun updateTraits(id: UInt64, traits: {String: String}) {
          JollyJokers.traits[id] = traits
      }
  }

	// fetch
	// Get a reference to a JollyJokers from an account's Collection, if available.
	// If an account does not have a JollyJokers.Collection, panic.
	// If it has a collection but does not contain the jokerId, return nil.
	// If it has a collection and that collection contains the jokerId, return a reference to that.
	//
	pub fun fetch(_ from: Address, jokerId: UInt64): &JollyJokers.NFT? {
		let collection = getAccount(from)
			.getCapability(JollyJokers.CollectionPublicPath)
			.borrow<&JollyJokers.Collection{JollyJokers.JollyJokersCollectionPublic}>()
			?? panic("Couldn't get collection")
		// We trust JollyJokers.Collection.borowJollyJokers to get the correct jokerId
		// (it checks it before returning it).
		return collection.borrowJollyJokers(id: jokerId)
	}

  init() {
    // Initialize the total, max supply and base uri
    self.totalSupply = 0
    self.maxSupply = 0
    self.baseURI = ""
    self.price = 0.0
    self.name = ""
    self.description = ""
    self.thumbnails = {}
    self.metadatas = {}
    self.traits = {}

    // Set the named paths
    self.CollectionStoragePath = /storage/JollyJokersCollection
    self.CollectionPublicPath = /public/JollyJokersCollection
    self.MinterStoragePath = /storage/JollyJokersMinter
    self.AdminStoragePath = /storage/JollyJokersAdmin
    self.AdminPrivatePath = /private/JollyJokersAdmin

    // Create resources and save it to storage
    self.account.save(<-create Collection(), to: self.CollectionStoragePath)
    self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)
    self.account.save(<-create Admin(), to: self.AdminStoragePath)

    // create a public capability for the collection
    self.account.link<&JollyJokers.Collection{NonFungibleToken.CollectionPublic, JollyJokers.JollyJokersCollectionPublic, MetadataViews.ResolverCollection}>(
        self.CollectionPublicPath,
        target: self.CollectionStoragePath
    )

    // create a public capability for the admin
    self.account.link<&JollyJokers.Admin>(self.AdminPrivatePath, target: self.AdminStoragePath)

    emit ContractInitialized()
  }
}
