import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Profile from 0x097bafa4e0b48eef
import FIND from 0x097bafa4e0b48eef
import FindForge from 0x097bafa4e0b48eef
import Debug from 0x097bafa4e0b48eef
import Clock from 0x097bafa4e0b48eef
import CharityNFT from 0x097bafa4e0b48eef
import FTRegistry from 0x097bafa4e0b48eef
import FindMarket from 0x097bafa4e0b48eef

pub contract Admin {

	//store the proxy for the admin
	pub let AdminProxyPublicPath: PublicPath
	pub let AdminProxyStoragePath: StoragePath

	/// ===================================================================================
	// Admin things
	/// ===================================================================================

	//Admin client to use for capability receiver pattern
	pub fun createAdminProxyClient() : @AdminProxy {
		return <- create AdminProxy()
	}

	//interface to use for capability receiver pattern
	pub resource interface AdminProxyClient {
		pub fun addCapability(_ cap: Capability<&FIND.Network>)
	}

	//admin proxy with capability receiver 
	pub resource AdminProxy: AdminProxyClient {

		access(self) var capability: Capability<&FIND.Network>?

		pub fun addCapability(_ cap: Capability<&FIND.Network>) {
			pre {
				cap.check() : "Invalid server capablity"
				self.capability == nil : "Server already set"
			}
			self.capability = cap
		}

		/*
		pub fun addTenantItem(_ item: FindMarket.TenantSaleItem) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			self.capability!.borrow()!.addTenantItem(item)

		}
		*/

		pub fun createFindMarket(name: String, address:Address, defaultCutRules: [FindMarket.TenantRule]) : Capability<&FindMarket.Tenant> {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			return  FindMarket.createFindMarket(name:name, address:address, defaultCutRules: defaultCutRules)
		}

		/// Set the wallet used for the network
		/// @param _ The FT receiver to send the money to
		pub fun setWallet(_ wallet: Capability<&{FungibleToken.Receiver}>) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			let walletRef = self.capability!.borrow() ?? panic("Cannot borrow reference to receiver. receiver address: ".concat(self.capability!.address.toString()))
			walletRef.setWallet(wallet)
		}

		pub fun getFindMarketClient():  &FindMarket.TenantClient{
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

      		let path = FindMarket.TenantClientStoragePath
      		return Admin.account.borrow<&FindMarket.TenantClient>(from: path) ?? panic("Cannot borrow Find market tenant client Reference.")
		}

		/// Enable or disable public registration 
		pub fun setPublicEnabled(_ enabled: Bool) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			let walletRef = self.capability!.borrow() ?? panic("Cannot borrow reference to receiver. receiver address: ".concat(self.capability!.address.toString()))
			walletRef.setPublicEnabled(enabled)
		}

		pub fun setAddonPrice(name: String, price: UFix64) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			let walletRef = self.capability!.borrow() ?? panic("Cannot borrow reference to receiver. receiver address: ".concat(self.capability!.address.toString()))
			walletRef.setAddonPrice(name: name, price: price)
		}

		pub fun setPrice(default: UFix64, additional : {Int: UFix64}) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			let walletRef = self.capability!.borrow() ?? panic("Cannot borrow reference to receiver. receiver address: ".concat(self.capability!.address.toString()))
			walletRef.setPrice(default: default, additionalPrices: additional)
		}

		pub fun register(name: String, profile: Capability<&{Profile.Public}>, leases: Capability<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>){
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
				FIND.validateFindName(name) : "A FIND name has to be lower-cased alphanumeric or dashes and between 3 and 16 characters"
			}

			let walletRef = self.capability!.borrow() ?? panic("Cannot borrow reference to receiver. receiver address: ".concat(self.capability!.address.toString()))
			walletRef.internal_register(name:name, profile: profile, leases: leases)
		}

		pub fun mintCharity(metadata : {String: String}, recipient: Capability<&{NonFungibleToken.CollectionPublic}>){
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			CharityNFT.mintCharity(metadata: metadata, recipient: recipient)
		}

		pub fun advanceClock(_ time: UFix64) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			Debug.enable(true)
			Clock.enable()
			Clock.tick(time)
		}


		pub fun debug(_ value: Bool) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			Debug.enable(value)
		}

		/*
		pub fun setViewConverters(from: Type, converters: [{Dandy.ViewConverter}]) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			Dandy.setViewConverters(from: from, converters: converters)
		}
		*/

		/// ===================================================================================
		// Fungible Token Registry 
		/// ===================================================================================

		// Registry FungibleToken Information
		pub fun setFTInfo(alias: String, type: Type, tag: [String], icon: String?, receiverPath: PublicPath, balancePath: PublicPath, vaultPath: StoragePath) {
			FTRegistry.setFTInfo(alias: alias, type: type, tag: tag, icon: icon, receiverPath: receiverPath, balancePath: balancePath, vaultPath:vaultPath)

		}

		// Remove FungibleToken Information by type identifier
		pub fun removeFTInfoByTypeIdentifier(_ typeIdentifier: String) {
			FTRegistry.removeFTInfoByTypeIdentifier(typeIdentifier)
		}


		// Remove FungibleToken Information by alias
		pub fun removeFTInfoByAlias(_ alias: String) {
			FTRegistry.removeFTInfoByAlias(alias)
		}

		/// ===================================================================================
		// Find Market Options 
		/// ===================================================================================
		pub fun addSaleItemType(_ type: Type) {
			FindMarket.addSaleItemType(type) 
		}

		pub fun addMarketBidType(_ type: Type) {
			FindMarket.addMarketBidType(type) 
		}

		pub fun addSaleItemCollectionType(_ type: Type) {
			FindMarket.addSaleItemCollectionType(type) 
		}

		pub fun addMarketBidCollectionType(_ type: Type) {
			FindMarket.addMarketBidCollectionType(type) 
		}

		pub fun removeSaleItemType(_ type: Type) {
			FindMarket.removeSaleItemType(type) 
		}

		pub fun removeMarketBidType(_ type: Type) {
			FindMarket.removeMarketBidType(type) 
		}

		pub fun removeSaleItemCollectionType(_ type: Type) {
			FindMarket.removeSaleItemCollectionType(type) 
		}

		pub fun removeMarketBidCollectionType(_ type: Type) {
			FindMarket.removeMarketBidCollectionType(type) 
		}

		/// ===================================================================================
		// Tenant Rules Management
		/// ===================================================================================
		pub fun getTenantRef(_ tenant: Address) : &FindMarket.Tenant {
			let string = FindMarket.getTenantPathForAddress(tenant)
			let pp = PrivatePath(identifier: string) ?? panic("Cannot generate storage path from string : ".concat(string))
			let cap = Admin.account.getCapability<&FindMarket.Tenant>(pp)
			return cap.borrow() ?? panic("Cannot borrow tenant reference from path. Path : ".concat(pp.toString()) )
		}

		pub fun addFindBlockItem(tenant: Address, item: FindMarket.TenantSaleItem) {
			let tenant = self.getTenantRef(tenant)
			tenant.addSaleItem(item, type: "find")
		}

		pub fun removeFindBlockItem(tenant: Address, name: String) {
			let tenant = self.getTenantRef(tenant)
			tenant.removeSaleItem(name, type: "find")
		}

		pub fun setFindCut(tenant: Address, saleItemName: String, cut: UFix64?, rules: [FindMarket.TenantRule]?, status: String) {
			let tenant = self.getTenantRef(tenant)
			let oldCut = tenant.removeSaleItem(saleItemName, type: "cut")

			var newCut = oldCut.cut! 
			if cut != nil {
				newCut = MetadataViews.Royalty(receiver: oldCut.cut!.receiver, cut: cut!, description: oldCut.cut!.description)
			}

			var newRules = oldCut.rules 
			if rules != nil {
				newRules = rules!
			}

			let newSaleItem = FindMarket.TenantSaleItem(
				name: oldCut.name, 
				cut: newCut ,
				rules: newRules, 
				status: status
			)
			tenant.addSaleItem(newSaleItem, type: "cut")
		}

		pub fun addFindCut(tenant: Address, FindCutName: String, rayalty: MetadataViews.Royalty, rules: [FindMarket.TenantRule], status: String) {
			if !(rules.length > 0) {
				panic("Rules cannot be empty array")
			}
			let tenant = self.getTenantRef(tenant)

			if tenant.checkFindCuts(FindCutName) {
				panic("This find cut already exist")
			}

			let newSaleItem = FindMarket.TenantSaleItem(
				name: FindCutName, 
				cut: rayalty ,
				rules: rules, 
				status: status
			)
			tenant.addSaleItem(newSaleItem, type: "cut")
		}

		/* 
		tenant.addSaleItem(TenantSaleItem(
			name:"findRoyalty", 
			cut:findRoyalty, 
			rules: defaultCutRules, 
			status:"active"
		), type: "cut")
		 */
		pub fun setMarketOption(tenant: Address, saleItem: FindMarket.TenantSaleItem) {
			let tenant = self.getTenantRef(tenant) 
			tenant.addSaleItem(saleItem, type: "tenant")
			//Emit Event here
		}

		pub fun removeMarketOption(tenant: Address, name: String) {
			let tenant = self.getTenantRef(tenant) 
			tenant.removeSaleItem(name, type: "tenant")
		}

		pub fun enableMarketOption(tenant: Address, name: String) {
			let tenant = self.getTenantRef(tenant) 
			tenant.alterMarketOption(name: name, status: "active")
		}

		pub fun deprecateMarketOption(tenant: Address, name: String) {
			let tenant = self.getTenantRef(tenant) 
			tenant.alterMarketOption(name: name, status: "deprecated")
		}

		pub fun stopMarketOption(tenant: Address, name: String) {
			let tenant = self.getTenantRef(tenant) 
			tenant.alterMarketOption(name: name, status: "stopped")
		}

		pub fun setTenantRule(tenant: Address, optionName: String, tenantRule: FindMarket.TenantRule) {
			let tenantRef = self.getTenantRef(tenant)
			tenantRef.setTenantRule(optionName: optionName, tenantRule: tenantRule)
		}

		pub fun removeTenantRule(tenant: Address, optionName: String, tenantRuleName: String) {
			let tenantRef = self.getTenantRef(tenant)
			tenantRef.removeTenantRule(optionName: optionName, tenantRuleName: tenantRuleName)
		}

		/// ===================================================================================
		// Royalty Residual
		/// ===================================================================================

		pub fun setResidualAddress(_ address: Address) {
			FindMarket.setResidualAddress(address)
		}

		init() {
			self.capability = nil
		}

	}


	init() {

		self.AdminProxyPublicPath= /public/findAdminProxy
		self.AdminProxyStoragePath=/storage/findAdminProxy

	}

}
