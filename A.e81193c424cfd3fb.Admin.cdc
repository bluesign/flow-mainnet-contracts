// SPDX-License-Identifier: MIT

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import Debug from 0xe81193c424cfd3fb
import Clock from 0xe81193c424cfd3fb
import Templates from 0xe81193c424cfd3fb
import Wearables from 0xe81193c424cfd3fb
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

	/// ==================================================================================
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

		pub fun registerWearableSet(_ s: Wearables.Set) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Wearables.addSet(s)
		}

		pub fun retireWearableSet(_ id:UInt64) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Wearables.retireSet(id)
		}

		pub fun registerWearablePosition(_ p: Wearables.Position) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Wearables.addPosition(p)
		}

		pub fun retireWearablePosition(_ id:UInt64) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Wearables.retirePosition(id)
		}

		pub fun registerWearableTemplate(_ t: Wearables.Template) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Wearables.addTemplate(t)
		}

		pub fun retireWearableTemplate(_ id:UInt64) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Wearables.retireTemplate(id)
		}

		pub fun mintWearable(
			recipient: &{NonFungibleToken.Receiver},
			template: UInt64,
			context: {String : String}
		){

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			Wearables.mintNFT(
				recipient: recipient,
				template: template,
				context: context
			)
		}

		pub fun mintEditionWearable(
			recipient: &{NonFungibleToken.Receiver},
			data: Wearables.WearableMintData,
			context: {String : String}
		){

			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			Wearables.mintEditionNFT(
				recipient: recipient,
				template: data.template,
				setEdition: data.setEdition,
				positionEdition: data.positionEdition,
				templateEdition: data.templateEdition,
				taggedTemplateEdition: data.taggedTemplateEdition,
				tagEditions: data.tagEditions,
				context: context
			)
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

		pub fun setFeature(action: String, enabled: Bool) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Templates.setFeature(action: action, enabled: enabled)
		}

		pub fun resetCounter() {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			Templates.resetCounters()
		}

		init() {
			self.capability = nil
		}

	}

	init() {

		self.AdminProxyPublicPath= /public/characterAdminProxy
		self.AdminProxyStoragePath=/storage/characterAdminProxy

		//create a dummy server for now, if we have a resource later we want to use instead of server we can change to that
		self.AdminServerPrivatePath=/private/characterAdminServer
		self.AdminServerStoragePath=/storage/characterAdminServer
		self.account.save(<- create Server(), to: self.AdminServerStoragePath)
		self.account.link<&Server>( self.AdminServerPrivatePath, target: self.AdminServerStoragePath)
	}

}
