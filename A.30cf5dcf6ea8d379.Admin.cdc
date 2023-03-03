import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import NonFungibleToken from 0x1d7e57aa55817448
import Debug from 0x30cf5dcf6ea8d379
import Clock from 0x30cf5dcf6ea8d379
import AeraNFT from 0x30cf5dcf6ea8d379
import AeraPack from 0x30cf5dcf6ea8d379
import AeraPackExtraData from 0x30cf5dcf6ea8d379
import AeraPanels from 0x30cf5dcf6ea8d379
import AeraRewards from 0x30cf5dcf6ea8d379
import MetadataViews from 0x1d7e57aa55817448
import FindViews from 0x097bafa4e0b48eef

pub contract Admin {

	//store the proxy for the admin
	pub let AdminProxyPublicPath: PublicPath
	pub let AdminProxyStoragePath: StoragePath
	pub let AdminServerStoragePath: StoragePath
	pub let AdminServerPrivatePath: PrivatePath
	pub event BurnedPack(packId:UInt64, packTypeId:UInt64)


	// This is just an empty resource to signal that you can control the admin, more logic can be added here or changed later if you want to
	pub resource Server {

	}

	/// ===================================================================================
	// Admin things
	/// ===================================================================================

	//Admin client to use for capability receiver pattern
	pub fun createAdminProxyClient() : @AdminProxy {
		return <- create AdminProxy()
	}

	//interface to use for capability receiver pattern
	pub resource interface AdminProxyClient {
		pub fun addCapability(_ cap: Capability<&Server>)
	}


	//admin proxy with capability receiver 
	pub resource AdminProxy: AdminProxyClient {

		access(self) var capability: Capability<&Server>?

		pub fun addCapability(_ cap: Capability<&Server>) {
			pre {
				cap.check() : "Invalid server capablity"
				self.capability == nil : "Server already set"
			}
			self.capability = cap
		}

		pub fun registerGame(_ game: AeraNFT.Game) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraNFT.addGame(game)
		}

		pub fun registerPlayMetadata(_ play: AeraNFT.PlayMetadata) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraNFT.addPlayMetadata(play)
		}

		pub fun registerLicense(_ license: AeraNFT.License) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraNFT.addLicense(license)
		}
		pub fun registerPlayer(_ player: AeraNFT.Player) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraNFT.addPlayer(player)
		}


		pub fun mintAeraWithBadges( 
			recipient: &{NonFungibleToken.Receiver}, 
			edition:UInt64,
			play: AeraNFT.Play,
			badges: [AeraNFT.Badge]
		){

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			AeraNFT.mintNFT(recipient:recipient, edition: edition, play: play, badges: badges)
		}


		pub fun mintAera( 
			recipient: &{NonFungibleToken.Receiver}, 
			edition:UInt64,
			play: AeraNFT.Play,
		){

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			AeraNFT.mintNFT(recipient:recipient, edition: edition, play: play, badges:[])
		}

		pub fun advanceClock(_ time: UFix64) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Debug.enable(true)
			Clock.enable()
			Clock.tick(time)
		}


		pub fun debug(_ value: Bool) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Debug.enable(value)
		}


		pub fun setPacksLeftForType(_ type:UInt64, amount:UInt64) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let packs = Admin.account.borrow<&AeraPack.Collection>(from: AeraPack.CollectionStoragePath)!
			packs.setPacksLeftForType(type, amount: amount)

		}

		pub fun registerPackMetadata(typeId:UInt64, metadata:AeraPack.Metadata, items: Int, tier: String,receiverPath: String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraPack.registerMetadata(typeId: typeId, metadata: metadata)
			AeraPackExtraData.registerItemsForPackType(typeId:typeId, items:items)
			AeraPackExtraData.registerTierForPackType(typeId:typeId, tier:tier)
			AeraPackExtraData.registerReceiverPathForPackType(typeId:typeId, receiverPath:receiverPath)
		}

		pub fun batchMintPacks(typeId: UInt64, hashes:[String]) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let recipient=Admin.account.getCapability<&{NonFungibleToken.Receiver}>(AeraPack.CollectionPublicPath).borrow()!
			for hash in  hashes {
				AeraPack.mintNFT(recipient:recipient, typeId: typeId, hash: hash)
			}
		}

		pub fun requeue(packId:UInt64) {
				pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let cap= Admin.account.borrow<&AeraPack.Collection>(from: AeraPack.DLQCollectionStoragePath)!
			cap.requeue(packId: packId)
		}

		pub fun fulfill(packId: UInt64, rewardIds:[UInt64], salt:String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraPack.fulfill(packId: packId, rewardIds: rewardIds, salt: salt)
		}

		pub fun transfer(fromPath:String, toPath:String, ids:[UInt64]) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			let sp = StoragePath(identifier: fromPath) ?? panic("Invalid path ".concat(fromPath))

			let treasuryPath = PublicPath(identifier: toPath) ?? panic("Invalid toPath ".concat(toPath))
			let collection = Admin.account.getCapability<&{NonFungibleToken.Receiver}>(treasuryPath).borrow() ?? panic("Could not borrow nft.cp at toPath ".concat(toPath).concat(" address ").concat(Admin.account.address.toString()))

			self.sendNFT(storagePath: fromPath, recipient: collection, ids: ids)
		}

		pub fun sendNFT( storagePath: String, recipient: &{NonFungibleToken.Receiver}, ids:[UInt64]) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let sp = StoragePath(identifier: storagePath) ?? panic("Invalid path ".concat(storagePath))
			let collection = Admin.account.borrow<&NonFungibleToken.Collection>(from: sp) ?? panic("Could not borrow collection at path ".concat(storagePath))
			for id in ids { 
				recipient.deposit(token: <- collection.withdraw(withdrawID: id))
			}
		}

		pub fun getAuthPointer(pathIdentifier: String, id: UInt64) : FindViews.AuthNFTPointer {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			
			let privatePath = PrivatePath(identifier: pathIdentifier)! 
			var cap = Admin.account.getCapability<&{MetadataViews.ResolverCollection, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(privatePath)
			if !cap.check() {
				let storagePath = StoragePath(identifier: pathIdentifier)! 
				Admin.account.link<&{MetadataViews.ResolverCollection, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(privatePath , target: storagePath)
				cap = Admin.account.getCapability<&{MetadataViews.ResolverCollection, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(privatePath)
			}
			return FindViews.AuthNFTPointer(cap: cap, id: id)
		}

		pub fun getProviderCapForPath(path:PrivatePath): Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}> {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			return Admin.account.getCapability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(path)
		}

		pub fun getProviderCap(): Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}> {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			return Admin.account.getCapability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(AeraNFT.CollectionPrivatePath)	
		}

		pub fun burn( storagePath: String,ids:[UInt64]) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let sp = StoragePath(identifier: storagePath) ?? panic("Invalid path ".concat(storagePath))
			let collection = Admin.account.borrow<&NonFungibleToken.Collection>(from: sp) ?? panic("Could not borrow collection at path ".concat(storagePath))
			for id in ids { 
				let item <- collection.withdraw(withdrawID: id) as! @AeraPack.NFT
				emit BurnedPack(packId:id, packTypeId:item.getTypeID())
				destroy <- item
			}
		}

		pub fun burnNFT(storagePath: String,ids:[UInt64]) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let sp = StoragePath(identifier: storagePath) ?? panic("Invalid path ".concat(storagePath))
			let collection = Admin.account.borrow<&AeraNFT.Collection>(from: sp) ?? panic("Could not borrow collection at path ".concat(storagePath))
			for id in ids { 
				collection.burn(id)
			}
		}

		pub fun registerPanelTemplate(panel: AeraPanels.PanelTemplate, mint_count: UInt64?) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraPanels.addPanelTemplate(panel: panel, mint_count: mint_count)

		}

		pub fun registerChapterTemplate(_ chapter: AeraPanels.ChapterTemplate) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraPanels.addChapterTemplate(chapter)

		}

		pub fun mintAeraPanel(		
			recipient: &{NonFungibleToken.Receiver}, 
			edition: UInt64,
			panelTemplateId: UInt64
		) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraPanels.mintNFT(recipient: recipient, edition: edition, panelTemplateId: panelTemplateId)
			
		}

		pub fun registerRewardTemplate(reward: AeraRewards.RewardTemplate, maxQuantity: UInt64?) {

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			AeraRewards.addRewardTemplate(reward: reward, maxQuantity: maxQuantity)

		}

		pub fun mintAeraReward( 
			recipient: &{NonFungibleToken.Receiver}, 
			rewardTemplateId: UInt64, 
			rewardFields: {UInt64 : {String : String}}
		) : UInt64 {
			
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			return AeraRewards.mintNFT( 
				recipient: recipient, 
				rewardTemplateId: rewardTemplateId, 
				rewardFields: rewardFields
			)
		}

		init() {
			self.capability = nil 
		}

	}

	init() {

		self.AdminProxyPublicPath= /public/onefootballAdminProxy
		self.AdminProxyStoragePath=/storage/onefootballAdminProxy

		//create a dummy server for now, if we have a resource later we want to use instead of server we can change to that
		self.AdminServerPrivatePath=/private/onefootballAdminServer
		self.AdminServerStoragePath=/storage/onefootballAdminServer
		self.account.save(<- create Server(), to: self.AdminServerStoragePath)
		self.account.link<&Server>( self.AdminServerPrivatePath, target: self.AdminServerStoragePath)
	}

}
 