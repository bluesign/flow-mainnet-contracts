import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import NonFungibleToken from 0x1d7e57aa55817448
import Debug from 0x7620acf6d7f2468a
import Clock from 0x7620acf6d7f2468a
import Bl0x from 0x7620acf6d7f2468a
import Bl0xPack from 0x7620acf6d7f2468a
import MetadataViews from 0x1d7e57aa55817448

pub contract Admin {

	//store the proxy for the admin
	pub let AdminProxyPublicPath: PublicPath
	pub let AdminProxyStoragePath: StoragePath
	pub let AdminServerStoragePath: StoragePath
	pub let AdminServerPrivatePath: PrivatePath


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


		pub fun registerTrait(_ trait: Bl0x.Trait) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Bl0x.addTrait(trait)
		}

		pub fun mintBl0x( 
			recipient: &{NonFungibleToken.Receiver}, 
			serial:UInt64,
			rootHash:String,
			season:UInt64,
			traits: {String: UInt64}
		){

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			Bl0x.mintNFT(recipient:recipient, 
			serial:serial,
			rootHash:rootHash,
			season:season,
			traits: traits)
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

		pub fun registerPackMetadata(typeId:UInt64, metadata:Bl0xPack.Metadata) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Bl0xPack.registerMetadata(typeId: typeId, metadata: metadata)
		}


		pub fun batchMintPacks(typeId: UInt64, hashes:[String]) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let recipient=Admin.account.getCapability<&{NonFungibleToken.Receiver}>(Bl0xPack.CollectionPublicPath).borrow()!
			for hash in  hashes {
				Bl0xPack.mintNFT(recipient:recipient, typeId: typeId, hash: hash)
			}
		}

		pub fun requeue(packId:UInt64) {
				pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let cap= Admin.account.borrow<&Bl0xPack.Collection>(from: Bl0xPack.DLQCollectionStoragePath)!
			cap.requeue(packId: packId)
		}

		pub fun fulfill(packId: UInt64, rewardIds:[UInt64], salt:String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Bl0xPack.fulfill(packId: packId, rewardIds: rewardIds, salt: salt)
		}

		//THis cap here could be the server really in this case
		pub fun getProviderCap(): Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}> {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			return Admin.account.getCapability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(Bl0x.CollectionPrivatePath)	
		}

		pub fun addRoyaltycut(_ cutInfo: MetadataViews.Royalty) {
			Bl0x.addRoyaltycut(cutInfo)
		}

		init() {
			self.capability = nil
		}

	}

	init() {

		self.AdminProxyPublicPath= /public/bl0xAdminProxy
		self.AdminProxyStoragePath=/storage/bl0xAdminProxy

		//create a dummy server for now, if we have a resource later we want to use instead of server we can change to that
		self.AdminServerPrivatePath=/private/bl0xAdminServer
		self.AdminServerStoragePath=/storage/bl0xAdminServer
		self.account.save(<- create Server(), to: self.AdminServerStoragePath)
		self.account.link<&Server>( self.AdminServerPrivatePath, target: self.AdminServerStoragePath)
	}

}
