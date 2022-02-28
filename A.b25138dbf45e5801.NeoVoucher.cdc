/*
Code inspired from https://github.com/JambbTeam/flow-nft-vouchers
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
//import NeoMember from "./NeoMember.cdc"
import MetadataViews from 0x1d7e57aa55817448
import Clock from 0xb25138dbf45e5801
import Debug from 0xb25138dbf45e5801

pub contract NeoVoucher: NonFungibleToken {
	// Events
	pub event ContractInitialized()
	pub event Withdraw(id: UInt64, from: Address?)
	pub event Deposit(id: UInt64, to: Address?)
	pub event Minted(id: UInt64, type:UInt64)

	// Redeemed
	// Fires when a user Redeems a NeoVoucher, prepping
	// it for Consumption to receive reward
	//
	pub event Redeemed(voucherId: UInt64, address:Address)

	// Consumed
	// Fires when an Admin consumes a NeoVoucher, deleting it forever
	// NOTE: Reward is not tracked. This is to simplify contract.
	//       It is to be administered in the consume() tx, 
	//       else thoust be punished by thine users.
	//
	pub event Consumed(voucherId:UInt64, address:Address, memberId:UInt64, teamId:UInt64, role: String, edition: UInt64, maxEdition:UInt64, name:String)

	pub event Purchased(voucherId: UInt64, address: Address, amount:UFix64)
	pub event Gifted(voucherId: UInt64, address: Address, full:Bool)
	pub event NotValidCollection(address: Address)

	// NeoVoucher Collection Paths
	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath

	// Contract-Singleton Redeemed NeoVoucher Collection
	pub let RedeemedCollectionPublicPath: PublicPath
	pub let RedeemedCollectionStoragePath: StoragePath

	// totalSupply
	// The total number of NeoVoucher that have been minted
	//
	pub var totalSupply: UInt64

	// metadata
	// the mapping of NeoVoucher TypeID's to their respective Metadata
	//
	access(contract) var metadata: {UInt64: Metadata}

	// redeemed
	// tracks currently redeemed vouchers for consumption
	// 
	access(contract) var redeemers: {UInt64: Address}

	// NeoVoucher Type Metadata Definitions
	// 
	pub struct Metadata {
		pub let name: String
		pub let description: String

		// MIME type: image/png, image/jpeg, video/mp4, audio/mpeg
		pub let mediaType: String 
		// IPFS storage hash
		pub let mediaHash: String

		pub let thumbnailHash: String

		pub let wallet: Capability<&{FungibleToken.Receiver}>
		pub let price: UFix64

		//time this voucher can be opened at, at the latest
		pub let timestamp:UFix64

		init(name: String, description: String, mediaType: String, mediaHash: String, thumbnailHash: String, wallet: Capability<&{FungibleToken.Receiver}>, price: UFix64, timestamp:UFix64) {
			self.name = name
			self.description = description
			self.mediaType = mediaType
			self.mediaHash = mediaHash
			self.thumbnailHash = thumbnailHash
			self.wallet=wallet
			self.price =price
			self.timestamp=timestamp
		}
	}

	/// redeem(token)
	/// This public function represents the core feature of this contract: redemptions.
	/// The NFT's, aka NeoVoucher, can be 'redeemed' into the RedeemedCollection, which
	/// will ultimately consume them to the tune of an externally agreed-upon reward.
	///
	pub fun redeem(collection: &NeoVoucher.Collection, voucherID: UInt64) {

		let voucher=collection.borrowNeoVoucher(id:voucherID)!

		let whitelistAddresses = ["0x467032bcf4403f79"]

		var time= voucher.getMetadata().timestamp
		if whitelistAddresses.contains(collection.owner!.address.toString()) {
			//5th march 8am UTC
			time=1646470800.0
		}

		let timestamp=Clock.time()
		Debug.log("Current=".concat(timestamp.toString()).concat(" voucherTime=").concat(voucher.getMetadata().timestamp.toString()))
		if timestamp < time {
			panic("You cannot open the voucher yet")
		}

		// withdraw their voucher
		let token <- collection.withdraw(withdrawID: voucherID)

		// establish the receiver for Redeeming NeoVoucher
		let receiver = NeoVoucher.account.getCapability<&{NonFungibleToken.Receiver}>(NeoVoucher.RedeemedCollectionPublicPath).borrow()!

		// deposit for consumption
		receiver.deposit(token: <- token)

		// store who redeemed this voucher for consumer to reward
		NeoVoucher.redeemers[voucherID] = collection.owner!.address
		emit Redeemed(voucherId:voucherID, address: collection.owner!.address) 
	}

	// NFT
	// NeoVoucher
	//
	pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
		// The token's ID
		pub let id: UInt64

		// The token's typeID
		access(self) var typeID: UInt64

		// init
		//
		init(initID: UInt64, typeID: UInt64) {
			self.id = initID
			self.typeID = typeID
		}


		access(contract) fun setTypeId(_ id: UInt64) {
			self.typeID=id
		}

		// Expose metadata of this NeoVoucher type
		//
		pub fun getMetadata(): Metadata {
			return NeoVoucher.metadata[self.typeID]!
		}

		pub fun getViews(): [Type] {
			return [
			Type<MetadataViews.Display>(), 
			Type<Metadata>(),
			Type<String>()
			]
		}

		pub fun resolveView(_ view: Type): AnyStruct? {
			let metadata = self.getMetadata()

			let file: AnyStruct{MetadataViews.File} = MetadataViews.IPFSFile(cid: metadata.thumbnailHash, path:nil)

			switch view {
			case Type<MetadataViews.Display>():
				return MetadataViews.Display(
					name: metadata.name,
					description: metadata.description,
					thumbnail: file
				)
			case Type<String>():
				return metadata.name

				case Type<NeoVoucher.Metadata>(): 
				return metadata
			}

			return nil
		}

	}

	pub resource interface CollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun buy(vault: @FungibleToken.Vault, collectionCapability: Capability<&Collection{NonFungibleToken.Receiver}>)  : UInt64
	}

	// Collection
	// A collection of NeoVoucher NFTs owned by an account
	//
	pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection {
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		//
		pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}


		pub fun buy(vault: @FungibleToken.Vault, collectionCapability: Capability<&Collection{NonFungibleToken.Receiver}>) : UInt64 {
			pre {
				self.ownedNFTs.length != 0 : "No more vouchers"
			}

			let vault <- vault as! @FlowToken.Vault
			let key=self.ownedNFTs.keys[0]

			let nftRef = self.borrowViewResolver(id: key)
			let metadata= nftRef.resolveView(Type<Metadata>())! as! Metadata
			let amount=vault.balance

			var fullNFT=false
			if metadata.price != amount {

				if amount == 100.0 {
					fullNFT=true
				} else  {
					panic("Vault does not contain ".concat(metadata.price.toString()).concat(" amount of Flow"))
				}
			}

			metadata.wallet.borrow()!.deposit(from: <- vault)
			let nft <- self.withdraw(withdrawID: key) as! @NFT
			if fullNFT {
				nft.setTypeId(2)
			}

			let token <- nft as @NonFungibleToken.NFT
			collectionCapability.borrow()!.deposit(token: <- token)

			emit Purchased(voucherId: key, address: collectionCapability.address, amount:amount)
			return  key
		}


		// withdraw
		// Removes an NFT from the collection and moves it to the caller
		//
		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

			emit Withdraw(id: token.id, from: self.owner?.address)

			return <-token
		}

		// deposit
		// Takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		//
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @NeoVoucher.NFT

			let id: UInt64 = token.id

			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token

			emit Deposit(id: id, to: self.owner?.address)

			destroy oldToken
		}

		// getIDs
		// Returns an array of the IDs that are in the collection
		//
		pub fun getIDs(): [UInt64] {
			return self.ownedNFTs.keys
		}

		// borrowNFT
		// Gets a reference to an NFT in the collection
		// so that the caller can read its metadata and call its methods
		//
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			return &self.ownedNFTs[id] as &NonFungibleToken.NFT
		}

		// borrowNeoVoucher
		// Gets a reference to an NFT in the collection as a NeoVoucher.NFT,
		// exposing all of its fields.
		// This is safe as there are no functions that can be called on the NeoVoucher.
		//
		pub fun borrowNeoVoucher(id: UInt64): &NeoVoucher.NFT? {
			if self.ownedNFTs[id] != nil {
				let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
				return ref as! &NeoVoucher.NFT
			} else {
				return nil
			}
		}

		pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
			let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
			let exampleNFT = nft as! &NFT
			return exampleNFT 
		}

		// destructor
		//
		destroy() {
			destroy self.ownedNFTs
		}

		// initializer
		//
		init () {
			self.ownedNFTs <- {}
		}
	}

	// createEmptyCollection
	// public function that anyone can call to create a new empty collection
	//
	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	}

	access(account) fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, typeID: UInt64){
		NeoVoucher.totalSupply = NeoVoucher.totalSupply + 1 
		emit Minted(id: NeoVoucher.totalSupply, type:typeID)

		// deposit it in the recipient's account using their reference
		recipient.deposit(token: <- create NeoVoucher.NFT(initID: NeoVoucher.totalSupply, typeID: typeID))
	}

	// batchMintNFT
	// Mints a batch of new NFTs
	// and deposits them in the recipients collection using their collection reference
	//
	access(account) fun batchMintNFT(recipient: &{NonFungibleToken.CollectionPublic}, typeID: UInt64, count: Int) {
		var index = 0

		while index < count {
			self.mintNFT(
				recipient: recipient,
				typeID: typeID
			)

			index = index + 1
		}
	}

	// registerMetadata
	// Registers metadata for a typeID
	//
	access(account)  fun registerMetadata(typeID: UInt64, metadata: Metadata) {
		NeoVoucher.metadata[typeID] = metadata
	}

	/*
	// consume
	// consumes a NeoVoucher from the Redeemed Collection by destroying it
	// NOTE: it is expected the consumer also rewards the redeemer their due
	//          in the case of this repository, an NFT is included in the consume transaction
	access(account)  fun consume(voucherID: UInt64, rewardID:UInt64) {


		// grab the voucher from the redeemed collection
		let redeemedCollection = NeoVoucher.account.borrow<&NeoVoucher.Collection>(from: NeoVoucher.RedeemedCollectionStoragePath)!
		let voucher <- redeemedCollection.withdraw(withdrawID: voucherID)

		// discard the empty collection and the voucher
		destroy voucher

		//the admin burns the voucher and sends the nft to the user

		let redeemer= NeoVoucher.redeemers[voucherID]!

		// get the recipients public account object
		let recipient = getAccount(redeemer)

		// borrow a public reference to the receivers collection
		let receiver = recipient.getCapability(NeoMember.CollectionPublicPath).borrow<&NeoMember.Collection{NonFungibleToken.Receiver}>() 
		?? panic("Could not borrow a reference to the recipient's collection")

		let members=NeoVoucher.account.borrow<&NeoMember.Collection>(from: NeoMember.CollectionStoragePath) ?? panic("Could not borrow a reference to the neo members for neo")

		let memberRef= members.borrow(rewardID)

		emit Consumed(voucherId:voucherID,  address: redeemer, memberId:rewardID, teamId:memberRef.getTeamId(), role: memberRef.role, edition: memberRef.edition, maxEdition: memberRef.maxEdition, name: memberRef.name)
		let member <- members.withdraw(withdrawID: rewardID)
		receiver.deposit(token: <-member)

	}

	*/

	// fetch
	// Get a reference to a NeoVoucher from an account's Collection, if available.
	// If an account does not have a NeoVoucher.Collection, panic.
	// If it has a collection but does not contain the itemID, return nil.
	// If it has a collection and that collection contains the itemID, return a reference to that.
	//
	pub fun fetch(_ from: Address, itemID: UInt64): &NeoVoucher.NFT? {
		let collection = getAccount(from)
		.getCapability(NeoVoucher.CollectionPublicPath)
		.borrow<&NeoVoucher.Collection>()
		?? panic("Couldn't get collection")
		// We trust NeoVoucher.Collection.borrowNeoVoucher to get the correct itemID
		// (it checks it before returning it).
		return collection.borrowNeoVoucher(id: itemID)
	}

	// getMetadata
	// Get the metadata for a specific  of NeoVoucher
	//
	pub fun getMetadata(typeID: UInt64): Metadata? {
		return NeoVoucher.metadata[typeID]
	}

	//This is temp until we have some global admin
	pub resource NeoVoucherAdmin {

		pub fun registerNeoVoucherMetadata(typeID: UInt64, metadata: NeoVoucher.Metadata) {
			NeoVoucher.registerMetadata(typeID: typeID, metadata: metadata)

		}

		pub fun batchMintNeoVoucher(recipient: &{NonFungibleToken.CollectionPublic}, count: Int) {
			//We only have one type right now
			NeoVoucher.batchMintNFT(recipient: recipient, typeID: 1, count: count)
		}

		pub fun giftVoucher(recipient: Capability<&{NonFungibleToken.CollectionPublic}>, fullNFT: Bool) {

			if !recipient.check() {
				emit NotValidCollection(address:recipient.address)
			}
			let source = NeoVoucher.account.borrow<&NeoVoucher.Collection>(from: NeoVoucher.CollectionStoragePath) ?? panic("Could not borrow a reference to the owner's voucher")

			let key =source.getIDs()[0]

			let nft <- source.withdraw(withdrawID: key) as! @NFT
			if fullNFT {
				nft.setTypeId(2)
			}

			let token <- nft as @NonFungibleToken.NFT
			recipient.borrow()!.deposit(token: <- token)

			emit Gifted(voucherId: key, address: recipient.address, full:fullNFT)
		}
	}

	// initializer
	//
	init() {
		self.CollectionStoragePath = /storage/neoVoucherCollection
		self.CollectionPublicPath = /public/neoVoucherCollection

		// only one redeemedCollection should ever exist, in the deployer storage
		self.RedeemedCollectionStoragePath = /storage/neoVoucherRedeemedCollection
		self.RedeemedCollectionPublicPath = /public/neoVoucherRedeemedCollection

		// Initialize the total supply
		self.totalSupply = 0

		// Initialize predefined metadata
		self.metadata = {}
		self.redeemers = {}

		// this contract will hold a Collection that NeoVoucher can be deposited to and Admins can Consume them to grant rewards
		// to the depositing account
		let redeemedCollection <- create Collection()
		// establish the collection users redeem into
		self.account.save(<- redeemedCollection, to: self.RedeemedCollectionStoragePath) 
		// set up a public link to the redeemed collection so they can deposit/view
		self.account.link<&NeoVoucher.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, NeoVoucher.CollectionPublic, MetadataViews.ResolverCollection}>(NeoVoucher.RedeemedCollectionPublicPath, target: NeoVoucher.RedeemedCollectionStoragePath)
		// set up a private link to the redeemed collection as a resource, so 
		emit ContractInitialized()

		let admin <- create NeoVoucherAdmin()
		self.account.save(<- admin, to: /storage/neoVoucherAdmin)


	}
}
