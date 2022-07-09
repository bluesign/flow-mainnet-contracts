/* SPDX-License-Identifier: UNLICENSED */

import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448

pub contract DimeCollectibleV4: NonFungibleToken {

	// Events
	pub event ContractInitialized()
	pub event Withdraw(id: UInt64, from: Address?)
	pub event Deposit(id: UInt64, to: Address?)
	pub event Minted(id: UInt64)

	// Named Paths
	pub let CollectionStoragePath: StoragePath
	pub let CollectionPrivatePath: PrivatePath
	pub let CollectionPublicPath: PublicPath
	pub let MinterStoragePath: StoragePath
	pub let MinterPublicPath: PublicPath

	// The total number of NFTs minted using this contract. Doubles as the most recent
	// id to be created.
	pub var totalSupply: UInt64

	pub enum NFTType: UInt8 {
		pub case standard
		pub case royalty
		pub case release
	}

	pub struct Transaction {
		pub let seller: Address
		pub let buyer: Address
		pub let price: UFix64
		pub let time: UFix64

		init(seller: Address, buyer: Address, price: UFix64, time: UFix64) {
			self.seller = seller
			self.buyer = buyer
			self.price = price
			self.time = time
		}
	}

	// DimeCollectible NFT, representing three distinct NFTTypes
	pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
		pub let id: UInt64
		pub let type: NFTType
		pub let name: String
		pub let description: String

		access(self) let creators: [Address]
		pub fun getCreators(): [Address] {
			return self.creators
		}

		pub let content: String
		pub let hiddenContent: String?
		pub fun hasHiddenContent(): Bool {
			return self.hiddenContent != nil
		}

		pub let blueprintId: UInt64
		pub let serialNumber: UInt64
		pub let editions: UInt64

		access(self) var history: [Transaction]
		pub fun getHistory(): [Transaction] {
			return self.history
		}
		access(self) let previousHistory: [Transaction]?
		pub fun getPreviousHistory(): [Transaction]? {
			return self.previousHistory
		}

		access(self) let royalties: MetadataViews.Royalties
		pub fun getRoyalties(): MetadataViews.Royalties {
			return self.royalties!
		}

		pub let tradeable: Bool
		pub let creationTime: UFix64

		init(id: UInt64, type: NFTType, name: String, description: String, creators: [Address],
			content: String, hiddenContent: String?, blueprintId: UInt64, serialNumber: UInt64,
			editions: UInt64, tradeable: Bool, history: [Transaction], previousHistory: [Transaction]?,
			royalties: MetadataViews.Royalties) {
			if (type == NFTType.standard || type == NFTType.release) {
				assert(royalties != nil,
					message: "Royalties must be provided for standard and release NFTs")
			}

			self.id = id
			self.type = type
			self.name = name
			self.description = description
			self.creators = creators
			self.content = content
			self.hiddenContent = hiddenContent
			self.blueprintId = blueprintId
			self.serialNumber = serialNumber
			self.editions = editions
			self.history = history
			self.previousHistory = previousHistory
			self.royalties = royalties
			self.tradeable = tradeable
			self.creationTime = getCurrentBlock().timestamp
		}

		pub fun addSale(toUser: Address, atPrice: UFix64) {
			self.history.append(Transaction(seller: self.owner!.address, buyer: toUser,
				price: atPrice, time: getCurrentBlock().timestamp))
		}

		pub fun getViews(): [Type] {
			return [
				Type<MetadataViews.Display>(),
				Type<MetadataViews.Editions>(),
				Type<MetadataViews.Serial>(),
				Type<MetadataViews.Royalties>(),
				Type<MetadataViews.ExternalURL>(),
				Type<MetadataViews.NFTCollectionData>()
			]
		}

		pub fun resolveView(_ view: Type): AnyStruct? {
			switch view {
				case Type<MetadataViews.Display>():
					return MetadataViews.Display(
						name: self.name,
						description: self.description,

						thumbnail: MetadataViews.HTTPFile(
							url: self.content
						)
					)
				case Type<MetadataViews.Editions>():
					let editionInfo = MetadataViews.Edition(name: "Editions of ".concat(self.name),
						number: self.serialNumber, max: self.editions)
					let editionList: [MetadataViews.Edition] = [editionInfo]
					return MetadataViews.Editions(
						editionList
					)
				case Type<MetadataViews.Serial>():
					return MetadataViews.Serial(
						self.serialNumber
					)
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties.getRoyalties()
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://dime.io/".concat(self.owner!.address.toString())
						.concat("/items/").concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: DimeCollectibleV4.CollectionStoragePath,
                        publicPath: DimeCollectibleV4.CollectionPublicPath,
                        providerPath: DimeCollectibleV4.CollectionPrivatePath,
                        publicCollection: Type<&DimeCollectibleV4.Collection{DimeCollectibleV4.DimeCollectionPublic}>(),
                        publicLinkedType: Type<&DimeCollectibleV4.Collection{DimeCollectibleV4.DimeCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&DimeCollectibleV4.Collection{DimeCollectibleV4.DimeCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-DimeCollectibleV4.createEmptyCollection()
                        })
                    )
			}
			return nil
		}
	}
	

	// This is the interface that users can cast their Collection as
	// to allow others to deposit into it. It also allows for
	// reading the details of items in the Collection.
	pub resource interface DimeCollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowCollectible(id: UInt64): &DimeCollectibleV4.NFT? {
			// If the result isn't nil, the id of the returned reference
			// should be the same as the argument to the function
			post {
				(result == nil) || (result?.id == id):
					"Cannot borrow reference: The ID of the returned reference is incorrect"
			}
		}
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
	}

	// Collection
	// A collection of NFTs owned by an account
	//
	pub resource Collection: DimeCollectionPublic, NonFungibleToken.Provider,
		NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic,
		MetadataViews.ResolverCollection {
		// Dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

		// Removes an NFT from the collection and moves it to the caller
		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

			emit Withdraw(id: token.id, from: self.owner?.address)

			return <-token
		}

		// Takes a NFT and adds it to the collection dictionary
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @DimeCollectibleV4.NFT

			let id: UInt64 = token.id

			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token

			emit Deposit(id: id, to: self.owner?.address)

			destroy oldToken
		}

		// Returns an array of the IDs that are in the collection
		pub fun getIDs(): [UInt64] {
			return self.ownedNFTs.keys
		}

		// We don't use this function (we use our own version, borrowCollectible),
		// but it's required by the NonFungibleToken.CollcetionPublic interface
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
		}

		// Gets a reference to an NFT in the collection as a DimeCollectibleV4.
		pub fun borrowCollectible(id: UInt64): &DimeCollectibleV4.NFT? {
			if self.ownedNFTs[id] == nil {
				return nil
			}
			let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
			return ref as! &DimeCollectibleV4.NFT?
		}

		destroy() {
			destroy self.ownedNFTs
		}

		init () {
			self.ownedNFTs <- {}
		}
		
		pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let dimeNFT = nft as! &DimeCollectibleV4.NFT
            return dimeNFT as &AnyResource{MetadataViews.Resolver}
        }
	}

	// Public function that anyone can call to create a new empty collection
	pub fun createEmptyCollection(): @DimeCollectibleV4.Collection {
		return <- create Collection()
	}

	pub resource NFTMinter {
		// Mint a standard DimeCollectible NFT
		pub fun mintNFTs(collection: &{NonFungibleToken.CollectionPublic}, name: String,
			description: String, blueprintId: UInt64, numCopies: UInt64, creators: [Address],
			content: String, hiddenContent: String?, tradeable: Bool,
			previousHistory: [Transaction]?, royalties: MetadataViews.Royalties,
			initialSale: Transaction?) {
			let history: [Transaction] = initialSale != nil ? [initialSale!] : []
			var counter = 1 as UInt64
			while counter <= numCopies {
				let tokenId = DimeCollectibleV4.totalSupply + counter
				collection.deposit(token: <- create DimeCollectibleV4.NFT(
					id: tokenId, type: NFTType.standard, name: name, description: description,
					creators: creators, content: content, hiddenContent: hiddenContent,
					blueprintId: blueprintId, serialNumber: counter, editions: numCopies,
					tradeable: tradeable, history: history, previousHistory: previousHistory,
					royalties: royalties
				))

				emit Minted(id: tokenId)
				counter = counter + 1
			}
			DimeCollectibleV4.totalSupply = DimeCollectibleV4.totalSupply + numCopies
		}

		pub fun mintRoyaltyNFTs(collection: &{NonFungibleToken.CollectionPublic}, name: String,
			description: String,blueprintId: UInt64, numCopies: UInt64, creators: [Address],
			content: String, tradeable: Bool, royalties: MetadataViews.Royalties,
			initialSale: Transaction?):
			[UInt64] {
			let history: [Transaction] = initialSale != nil ? [initialSale!] : []
			var counter = 1 as UInt64
			let idsUsed: [UInt64] = []
			while counter <= numCopies {
				let tokenId = DimeCollectibleV4.totalSupply + counter
				collection.deposit(token: <- create DimeCollectibleV4.NFT(
					id: tokenId, type: NFTType.royalty, name: name, description: description,
					creators: creators, content: content, hiddenContent: nil,
					blueprintId: blueprintId, serialNumber: counter, editions: numCopies,
					tradeable: tradeable, history: history, previousHistory: nil,
					royalties: royalties
				))

				emit Minted(id: tokenId)
				idsUsed.append(tokenId)
				counter = counter + 1
			}
			DimeCollectibleV4.totalSupply = DimeCollectibleV4.totalSupply + numCopies
			return idsUsed
		}

		pub fun mintReleaseNFTs(collection: &{NonFungibleToken.CollectionPublic}, name: String,
			description: String, blueprintId: UInt64, numCopies: UInt64, creators: [Address],
			content: String, hiddenContent: String?, tradeable: Bool,
			previousHistory:[Transaction]?, royalties: MetadataViews.Royalties,
			initialSale: Transaction?) {
			let history: [Transaction] = initialSale != nil ? [initialSale!] : []
			var counter = 1 as UInt64
			while counter <= numCopies {
				let tokenId = DimeCollectibleV4.totalSupply + counter
				collection.deposit(token: <- create DimeCollectibleV4.NFT(
					id: tokenId, type: NFTType.release, name: name, description: description,
					creators: creators, content: content, hiddenContent: hiddenContent,
					blueprintId: blueprintId, serialNumber: counter, editions: numCopies,
					tradeable: tradeable, history: history, previousHistory: previousHistory,
					royalties: royalties
				))

				emit Minted(id: tokenId)
				counter = counter + 1
			}
			DimeCollectibleV4.totalSupply = DimeCollectibleV4.totalSupply + numCopies
		}
	}

	init() {
		// Set our named paths
		self.CollectionStoragePath = /storage/DimeCollectionV4
		self.CollectionPrivatePath = /private/DimeCollectionV4
		self.CollectionPublicPath = /public/DimeCollectionV4
		self.MinterStoragePath = /storage/DimeMinterV4
		self.MinterPublicPath = /public/DimeMinterV4

		// Initialize the total supply
		self.totalSupply = 0

		// Create a Minter resource and save it to storage.
		// Create a public link so all users can use the same global one
		let minter <- create NFTMinter()
		self.account.save(<- minter, to: self.MinterStoragePath)
		self.account.link<&NFTMinter>(self.MinterPublicPath, target: self.MinterStoragePath)

		emit ContractInitialized()
	}
}
