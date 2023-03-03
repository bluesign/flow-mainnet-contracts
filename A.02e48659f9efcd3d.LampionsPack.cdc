import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import Crypto
import Clock from 0x02e48659f9efcd3d
import Debug from 0x02e48659f9efcd3d
import FLOAT from 0x2d4c3caffbeab845


pub contract LampionsPack: NonFungibleToken {
	// Events
	pub event ContractInitialized()
	pub event Withdraw(id: UInt64, from: Address?)
	pub event Deposit(id: UInt64, to: Address?)
	pub event Minted(id: UInt64, typeId:UInt64)

	pub event Requeued(packId: UInt64, address:Address)

	pub event Opened(packId: UInt64, address:Address, packTypeId:UInt64)
	pub event Fulfilled(packId:UInt64, address:Address)
	pub event PackReveal(packId:UInt64, address:Address, packTypeId:UInt64, rewardId:UInt64, rewardType:String, rewardFields:{String:String})

	pub event Purchased(packId: UInt64, address: Address, amount:UFix64, packTypeId:UInt64)
	pub event MetadataRegistered(typeId:UInt64)
	pub event FulfilledError(packId:UInt64, address:Address?, reason:String)

	pub let PackMetadataStoragePath: StoragePath

	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath

	pub let OpenedCollectionPublicPath: PublicPath
	pub let OpenedCollectionStoragePath: StoragePath


	pub let DLQCollectionPublicPath: PublicPath
	pub let DLQCollectionStoragePath: StoragePath

	pub var totalSupply: UInt64

	access(contract) let packMetadata: {UInt64: Metadata}

	pub struct PackRevealData {

		pub let data: {String:String}

		init(_ data: {String:String}) {
			self.data=data
		}
	}

	pub struct Metadata {
		pub let name: String
		pub let description: String

		pub let thumbnailHash: String?
		pub let thumbnailUrl:String?

		pub let wallet: Capability<&{FungibleToken.Receiver}>
		pub let walletType: Type
		pub let price: UFix64

		pub let buyTime:UFix64

		pub let openTime:UFix64
		pub let whiteListTime:UFix64?

		pub let floatEventId: UInt64?

		pub let storageRequirement: UInt64

		access(contract) let providerCap: Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}> 

		access(contract) let royaltyCap: Capability<&{FungibleToken.Receiver}>?
		access(contract) let royaltyCut: UFix64

		pub let requiresReservation: Bool

		init(name: String, description: String, thumbnailUrl: String?,thumbnailHash: String?, wallet: Capability<&{FungibleToken.Receiver}>, price: UFix64, buyTime:UFix64, openTime:UFix64, walletType:Type, providerCap: Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>, requiresReservation:Bool, royaltyCut: UFix64, royaltyWallet: Capability<&{FungibleToken.Receiver}>?, floatEventId:UInt64?, whiteListTime: UFix64?, storageRequirement: UInt64) {
			self.name = name
			self.description = description
			self.thumbnailUrl = thumbnailUrl
			self.thumbnailHash = thumbnailHash
			self.wallet=wallet
			self.walletType=walletType
			self.price =price
			self.buyTime=buyTime
			self.openTime=openTime
			self.providerCap=providerCap

			//If this pack has royalties then they can be added here later. For the current implementations royalties appear to be handled offchain. 
			self.royaltyCap=royaltyWallet
			self.royaltyCut=royaltyCut

			self.floatEventId=floatEventId
			self.whiteListTime=whiteListTime

			self.storageRequirement= storageRequirement

			self.requiresReservation=requiresReservation
		}

		pub fun getThumbnail() : AnyStruct{MetadataViews.File} {
			if let hash = self.thumbnailHash {
				return MetadataViews.IPFSFile(cid: hash, path:nil)
			}
			return MetadataViews.HTTPFile(url:self.thumbnailUrl!)
		}

		//TODO: This is a bug
		pub fun canBeOpened() : Bool {
			return self.openTime >= Clock.time()
		}
	}

	access(account) fun registerMetadata(typeId: UInt64, metadata: Metadata) {
		emit MetadataRegistered(typeId:typeId)
		self.packMetadata[typeId]= metadata
	}

	pub fun getMetadata(typeId: UInt64): Metadata? {
		return self.packMetadata[typeId]
	}

	pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
		// The token's ID
		pub let id: UInt64

		// The token's typeId
		access(self) var typeId: UInt64

		//this is added to the NFT when it is opened
		access(self) var openedBy: Capability<&{NonFungibleToken.Receiver}>?

		access(account) let hash: String

		// init
		//
		init(typeId: UInt64, hash:String) {
			self.id = self.uuid
			self.typeId = typeId
			self.openedBy=nil
			self.hash=hash
		}

		pub fun getOpenedBy() : Capability<&{NonFungibleToken.Receiver}> {
			if self.openedBy== nil {
				panic("Pack is not opened")
			}
			return self.openedBy!
		}

		pub fun getHash() : String{
			return self.hash
		}

		access(contract) fun setTypeId(_ id: UInt64) {
			self.typeId=id
		}

		access(contract) fun resetOpendBy() : Address {
			if self.openedBy==nil {
				panic("Pack is not opened")
			}
  		let cap = self.openedBy!

			self.openedBy=nil
			return cap.address
		}

		access(contract) fun setOpenedBy(_ cap:Capability<&{NonFungibleToken.Receiver}>) {
			if self.openedBy!=nil {
				panic("Pack has already been opened")
			}
			self.openedBy=cap
		}

		pub fun getTypeID() :UInt64 {
			return self.typeId
		}

		pub fun getMetadata(): Metadata {
			return LampionsPack.getMetadata(typeId: self.typeId)!
		}

		pub fun getViews(): [Type] {
			return [
			Type<MetadataViews.Display>(), 
			Type<Metadata>(),
			Type<String>()
			]
		}

		pub fun getThumbnail() : AnyStruct{MetadataViews.File} {
			return self.getMetadata().getThumbnail()
		}

		pub fun resolveView(_ view: Type): AnyStruct? {
			let metadata = self.getMetadata()
			switch view {
			case Type<MetadataViews.Display>():
				return MetadataViews.Display(
					name: metadata.name,
					description: metadata.description,
					thumbnail: self.getThumbnail()
				)
			case Type<String>():
				return metadata.name

				case Type<LampionsPack.Metadata>(): 
				return metadata
			}

			return nil
		}

	}

	pub resource interface CollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun getPacksLeftForType(_ type:UInt64) : UInt64
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun borrowLampionsPack(id: UInt64): &LampionsPack.NFT? 
		pub fun buy(id: UInt64, vault: @FungibleToken.Vault, collectionCapability: Capability<&Collection{NonFungibleToken.Receiver}>) 
		pub fun buyWithSignature(packId: UInt64, signature:String, vault: @FungibleToken.Vault, collectionCapability: Capability<&Collection{NonFungibleToken.Receiver}>) 
	}

	// Collection
	// A collection of LampionsPack NFTs owned by an account
	//
	pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection {
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		//
		pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

		pub var nftsPerType: {UInt64:UInt64}

		// since maps are not ordered in cadence this will pick any random key and that works really well
		access(self) fun getPackIdForType(_ typeId: UInt64): UInt64? {
			for key in self.ownedNFTs.keys {
				if let pack= self.borrowLampionsPack(id: key) {
					if pack.getTypeID() == typeId {
						return key
					}
				}
			}
			return nil
		}

		//this has to be called on the DLQ collection
		pub fun requeue(packId:UInt64) {
			let token <- self.withdraw(withdrawID: packId) as! @NFT

			let address=token.resetOpendBy()
			let cap=getAccount(address).getCapability<&Collection{NonFungibleToken.Receiver}>(LampionsPack.CollectionPublicPath)
			let receiver = cap.borrow()!
			receiver.deposit(token: <- token)
			emit Requeued(packId:packId, address: cap.address)
		}

		pub fun open(packId: UInt64, receiverCap: Capability<&{NonFungibleToken.Receiver}>) {
			if !receiverCap.check() {
				panic("Receiver cap is not valid")
			}
			let pack=self.borrowLampionsPack(id:packId)!

			var time= pack.getMetadata().openTime
			let timestamp=Clock.time()
			if timestamp < time {
				panic("You cannot open the pack yet")
			}

			let token <- self.withdraw(withdrawID: packId) as! @LampionsPack.NFT
			token.setOpenedBy(receiverCap)

			// establish the receiver for Redeeming LampionsPack
			let receiver = LampionsPack.account.getCapability<&{NonFungibleToken.Receiver}>(LampionsPack.OpenedCollectionPublicPath).borrow()!

			let typeId=token.getTypeID()
			// deposit for consumption
			receiver.deposit(token: <- token)

			emit Opened(packId:packId, address: self.owner!.address, packTypeId: typeId) 
		}

		pub fun buyWithSignature(packId: UInt64, signature:String, vault: @FungibleToken.Vault, collectionCapability: Capability<&Collection{NonFungibleToken.Receiver}>) {
			pre {
				self.owner!.address == LampionsPack.account.address : "You can only buy pack directly from the LampionsPack account"
			}

			let nft <- self.withdraw(withdrawID: packId) as!  @NFT
			let metadata= nft.getMetadata()

			if !metadata.requiresReservation {
				panic("This pack type does not require reservation, use the open buy method")
			}

			var time= metadata.buyTime
			let timestamp=Clock.time()
			let user=collectionCapability.address
			var whitelisted= false
			if let whiteListTime = metadata.whiteListTime {

				//TODO: test
				if timestamp < whiteListTime {
					panic("You cannot buy the pack yet")
				}

				//TODO: test
				if let float=metadata.floatEventId {
					whitelisted=LampionsPack.hasFloat(floatEventId:float, user:collectionCapability.address)
				}
			} else {

				if let float=metadata.floatEventId {
					//TODO:test
					if !LampionsPack.hasFloat(floatEventId:float, user:collectionCapability.address) {
						panic("Your user does not have the required float with eventId ".concat(float.toString()))
					}
				}
			}

			if !whitelisted && timestamp < time {
				panic("You cannot buy the pack yet")
			}

			if vault.getType() != metadata.walletType {
				panic("The vault sent in is not of the desired type ".concat(metadata.walletType.identifier))
			}


			if metadata.price != vault.balance {
				panic("Vault does not contain required amount of FT ".concat(metadata.price.toString()))
			}
			let keyList = Crypto.KeyList()
			let accountKey = self.owner!.keys.get(keyIndex: 0)!.publicKey

			// Adds the public key to the keyList
			keyList.add(
				PublicKey(
					publicKey: accountKey.publicKey,
					signatureAlgorithm: accountKey.signatureAlgorithm
				),
				hashAlgorithm: HashAlgorithm.SHA3_256,
				weight: 1.0
			)

			// Creates a Crypto.KeyListSignature from the signature provided in the parameters
			let signatureSet: [Crypto.KeyListSignature] = []
			signatureSet.append(
				Crypto.KeyListSignature(
					keyIndex: 0,
					signature: signature.decodeHex()
				)
			)

			// Verifies that the signature is valid and that it was generated from the
			// owner of the collection
			if(!keyList.verify(signatureSet: signatureSet, signedData: nft.hash.utf8)){
				panic("Unable to validate the signature for the pack!")
			}

			let packTypeId=nft.getTypeID()

			if metadata.royaltyCut != 0.0 && metadata.royaltyCap != nil && metadata.royaltyCap!.check() {
				metadata.royaltyCap!.borrow()!.deposit(from: <- vault.withdraw(amount: vault.balance * metadata.royaltyCut))
			} 

			metadata.wallet.borrow()!.deposit(from: <- vault)
			collectionCapability.borrow()!.deposit(token: <- nft)

			emit Purchased(packId: packId, address: collectionCapability.address, amount:metadata.price, packTypeId: packTypeId)
		}

		pub fun buy(id: UInt64, vault: @FungibleToken.Vault, collectionCapability: Capability<&Collection{NonFungibleToken.Receiver}>) {
			pre {
				self.owner!.address == LampionsPack.account.address : "You can only buy pack directly from the LampionsPack account"
			}

			let nft <- self.withdraw(withdrawID: id) as! @NFT
			let metadata= nft.getMetadata()

			let user=collectionCapability.address
			let timestamp=Clock.time()

			var time= metadata.buyTime
			if metadata.price != vault.balance {
				panic("Vault does not contain required amount of FT".concat(metadata.price.toString()))
			}
			if metadata.royaltyCut != 0.0 && metadata.royaltyCap != nil && metadata.royaltyCap!.check() {
				metadata.royaltyCap!.borrow()!.deposit(from: <- vault.withdraw(amount: vault.balance * metadata.royaltyCut))
			} 

			metadata.wallet.borrow()!.deposit(from: <- vault)
			collectionCapability.borrow()!.deposit(token: <- nft)

			emit Purchased(packId: id, address: collectionCapability.address, amount:metadata.price, packTypeId: 1)
		}


		// withdraw
		// Removes an NFT from the collection and moves it to the caller
		//
		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Could not withdraw nft")

			let nft <- token as! @NFT

//			let oldNumber= self.nftsPerType[nft.getTypeID()]!
//			self.nftsPerType[nft.getTypeID()]=oldNumber-1

			emit Withdraw(id: nft.id, from: self.owner?.address)


			return <-nft
		}

		// deposit
		// Takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		//
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @LampionsPack.NFT

			let id: UInt64 = token.id

			let oldNumber= self.nftsPerType[token.getTypeID()] ?? 0
			self.nftsPerType[token.getTypeID()]=oldNumber+1
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

		//return the number of packs left of a type
		pub fun getPacksLeftForType(_ type:UInt64) : UInt64 {
			return self.nftsPerType[type] ?? 0
		}

		// borrowNFT
		// Gets a reference to an NFT in the collection
		// so that the caller can read its metadata and call its methods
		//
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
		}

		// borrowLampionsPack
		// Gets a reference to an NFT in the collection as a LampionsPack.NFT,
		// exposing all of its fields.
		// This is safe as there are no functions that can be called on the LampionsPack.
		//
		pub fun borrowLampionsPack(id: UInt64): &LampionsPack.NFT? {
			if self.ownedNFTs[id] != nil {
				let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
				return ref as! &LampionsPack.NFT
			} else {
				return nil
			}
		}

		pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
			let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
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
			self.nftsPerType= {}
		}
	}

	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	}

	access(account) fun mintNFT(recipient: &{NonFungibleToken.Receiver}, typeId: UInt64, hash: String){

		let nft <- create LampionsPack.NFT(typeId: typeId, hash:hash)
		emit Minted(id: nft.id, typeId:typeId)

		// deposit it in the recipient's account using their reference
		recipient.deposit(token: <- nft)
	}

	access(account) fun fulfill(packId: UInt64, rewardIds:[UInt64], salt:String) {

		let openedPacksCollection = LampionsPack.account.borrow<&LampionsPack.Collection>(from: LampionsPack.OpenedCollectionStoragePath)!
		let pack <- openedPacksCollection.withdraw(withdrawID: packId) as! @LampionsPack.NFT

		let receiver= pack.getOpenedBy()
		if !receiver.check() {
			emit FulfilledError(packId:packId, address:receiver.address, reason: "The receiver registered in this pack is not valid")
			self.transferToDLQ(<- pack)
			return
		}

		let hash= pack.getHash()
		let rewards=pack.getMetadata().providerCap

		if !rewards.check() {
			emit FulfilledError(packId:packId, address:receiver.address, reason: "Cannot borrow provider capability to withdraw nfts")
			self.transferToDLQ(<- pack)
			return
		}

		let receiverAccount=getAccount(receiver.address)
		let freeStorage=receiverAccount.storageCapacity - receiverAccount.storageUsed
		Debug.log("Free capacity from account ".concat(freeStorage.toString()))

		if pack.getMetadata().storageRequirement > freeStorage {
			emit FulfilledError(packId:packId, address:receiver.address, reason: "Not enough flow to hold the content of the pack. Please top up your account")
			self.transferToDLQ(<- pack)
			return
		}

		var string=salt
		for id in rewardIds {
			var seperator="-" 
			if string!=salt {
				seperator=","
			}
			string=string.concat(seperator).concat(id.toString())
		}

		let digest = HashAlgorithm.SHA3_384.hash(string.utf8)
		let digestAsString=String.encodeHex(digest)
		if digestAsString != hash {
			emit FulfilledError(packId:packId, address:receiver.address, reason: "The content of the pack was not verified with the hash provided at mint")
			self.transferToDLQ(<- pack)
			return
		}

		let target=receiver.borrow()!
		let source=rewards.borrow()!
		for reward in rewardIds {

			let viewType= Type<PackRevealData>()
			let nft=source.borrowViewResolver(id: reward)

			var fields : {String: String}= {}
			if nft.getViews().contains(viewType) {
				let view=nft.resolveView(viewType)! as! PackRevealData
				fields=view.data
			}
			let token <- source.withdraw(withdrawID: reward)

			emit PackReveal(packId:packId, address:receiver.address, packTypeId: pack.getTypeID(), rewardId: reward, rewardType: token.getType().identifier, rewardFields: fields)
			target.deposit(token: <-token)
		}
		emit Fulfilled(packId:packId, address:receiver.address)

		destroy pack
	}

	access(account) fun transferToDLQ(_ pack: @NFT) {
		let dlq = LampionsPack.account.borrow<&LampionsPack.Collection>(from: LampionsPack.DLQCollectionStoragePath)!
		dlq.deposit(token: <- pack)
	}


	pub fun getPacksCollection() : &LampionsPack.Collection{CollectionPublic} {
		return LampionsPack.account.getCapability<&LampionsPack.Collection{LampionsPack.CollectionPublic}>(LampionsPack.CollectionPublicPath).borrow() ?? panic("Could not borow LampionsPack collection")
	}

	pub fun canBuy(packTypeId:UInt64, user:Address) : Bool {

		let packs=LampionsPack.getPacksCollection()

		let packsLeft= packs.getPacksLeftForType(packTypeId)
		if packsLeft == 0 {
			return false
		}

		let packMetadata=LampionsPack.getMetadata(typeId: packTypeId)

		if packMetadata==nil {
			return false
		}
		let timestamp=Clock.time() 

		let metadata=packMetadata!
		var whitelisted= false
		if let whiteListTime = metadata.whiteListTime {
			if timestamp < whiteListTime {
				return false
			}

			if let float=metadata.floatEventId {
				whitelisted=LampionsPack.hasFloat(floatEventId:float, user:user)
			}
		} else {
			if let float=metadata.floatEventId {
				if !LampionsPack.hasFloat(floatEventId:float, user:user) {
					return false
				}
			}
		}

		var time= metadata.buyTime
		if !whitelisted && timestamp < time {
			return false
		}
		return true
	}

	pub fun hasFloat(floatEventId:UInt64, user:Address) : Bool {

		let float = getAccount(user).getCapability(FLOAT.FLOATCollectionPublicPath).borrow<&FLOAT.Collection{FLOAT.CollectionPublic}>() 

		if float == nil {
			return false
		}

		let floatsCollection=float!

		let ids = floatsCollection.getIDs()
		for id in ids {
			let nft: &FLOAT.NFT = floatsCollection.borrowFLOAT(id: id)!
			if nft.eventId==floatEventId {
				return true
			}
		}
		return false
	}

	// initializer
	//
	init() {
		self.CollectionStoragePath = /storage/LampionsPackCollection
		self.CollectionPublicPath = /public/LampionsPackCollection

		self.OpenedCollectionStoragePath = /storage/LampionsPackOpenedCollection
		self.OpenedCollectionPublicPath = /public/LampionsPackOpenedCollection

		self.DLQCollectionStoragePath = /storage/LampionsPackDLQCollection
		self.DLQCollectionPublicPath = /public/LampionsPackDLQCollection

		self.PackMetadataStoragePath= /storage/LampionsPackMetadata

		//this will not be used, we use UUID as id
		self.totalSupply = 0

		self.packMetadata={}

		// this contract will hold a Collection that LampionsPack can be deposited to and Admins can Consume them to transfer nfts to the depositing account
		let openedCollection <- create Collection()
		self.account.save(<- openedCollection, to: self.OpenedCollectionStoragePath) 
		self.account.link<&LampionsPack.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, LampionsPack.CollectionPublic, MetadataViews.ResolverCollection}>(LampionsPack.OpenedCollectionPublicPath, target: LampionsPack.OpenedCollectionStoragePath)


		//a DLQ storage slot so that the opener can put items that cannot be opened/transferred here.
		let dlqCollection <- create Collection()
		self.account.save(<- dlqCollection, to: self.DLQCollectionStoragePath) 
		self.account.link<&LampionsPack.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, LampionsPack.CollectionPublic, MetadataViews.ResolverCollection}>(LampionsPack.DLQCollectionPublicPath, target: LampionsPack.DLQCollectionStoragePath)

		self.account.save<@NonFungibleToken.Collection>( <- self.createEmptyCollection(), to: self.CollectionStoragePath)

		self.account.link<&LampionsPack.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, LampionsPack.CollectionPublic, MetadataViews.ResolverCollection}>(
			LampionsPack.CollectionPublicPath,
			target: LampionsPack.CollectionStoragePath
		)

		emit ContractInitialized()

	}
}
