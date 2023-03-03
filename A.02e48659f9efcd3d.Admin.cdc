import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import NonFungibleToken from 0x1d7e57aa55817448
import Debug from 0x02e48659f9efcd3d
import Clock from 0x02e48659f9efcd3d
import LampionsNFT from 0x02e48659f9efcd3d
import LampionsPack from 0x02e48659f9efcd3d
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

		pub fun registerGame(_ game: LampionsNFT.Game) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			LampionsNFT.addGame(game)
		}

		pub fun registerPlay(_ play: LampionsNFT.Play) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			LampionsNFT.addPlay(play)
		}

		pub fun registerLicense(_ license: LampionsNFT.License) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			LampionsNFT.addLicense(license)
		}
		pub fun registerPlayer(_ player: LampionsNFT.Player) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			LampionsNFT.addPlayer(player)
		}


		pub fun mintLampions( 
			recipient: &{NonFungibleToken.Receiver}, 
			play_id: UInt64,
			edition:UInt64
		){

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			LampionsNFT.mintNFT(recipient:recipient, play_id: play_id, edition:edition)
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

		pub fun registerPackMetadata(typeId:UInt64, metadata:LampionsPack.Metadata) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			LampionsPack.registerMetadata(typeId: typeId, metadata: metadata)
		}

		pub fun batchMintPacks(typeId: UInt64, hashes:[String]) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let recipient=Admin.account.getCapability<&{NonFungibleToken.Receiver}>(LampionsPack.CollectionPublicPath).borrow()!
			for hash in  hashes {
				LampionsPack.mintNFT(recipient:recipient, typeId: typeId, hash: hash)
			}
		}

		pub fun requeue(packId:UInt64) {
				pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let cap= Admin.account.borrow<&LampionsPack.Collection>(from: LampionsPack.DLQCollectionStoragePath)!
			cap.requeue(packId: packId)
		}

		pub fun fulfill(packId: UInt64, rewardIds:[UInt64], salt:String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			LampionsPack.fulfill(packId: packId, rewardIds: rewardIds, salt: salt)
		}

		//THis cap here could be the server really in this case
		pub fun getProviderCap(): Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}> {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			return Admin.account.getCapability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(LampionsNFT.CollectionPrivatePath)	
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
