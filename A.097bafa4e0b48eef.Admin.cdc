import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Profile from 0x097bafa4e0b48eef
import FIND from 0x097bafa4e0b48eef
import Debug from 0x097bafa4e0b48eef
import Clock from 0x097bafa4e0b48eef
import FTRegistry from 0x097bafa4e0b48eef
import FindMarket from 0x097bafa4e0b48eef
import FindForge from 0x097bafa4e0b48eef
import FindForgeOrder from 0x097bafa4e0b48eef
import FindPack from 0x097bafa4e0b48eef
import NFTCatalog from 0x49a7cda3a1eecc29
import FINDNFTCatalogAdmin from 0x097bafa4e0b48eef
import FindViews from 0x097bafa4e0b48eef

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

		pub fun addPublicForgeType(name: String, forgeType : Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForge.addPublicForgeType(forgeType: forgeType)
		}

		pub fun addPrivateForgeType(name: String, forgeType : Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForge.addPrivateForgeType(name: name, forgeType: forgeType)
		}

		pub fun removeForgeType(_ type : Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForge.removeForgeType(type: type)
		}

		pub fun addForgeContractData(lease: String, forgeType: Type , data: AnyStruct) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForge.adminAddContractData(lease: lease, forgeType: forgeType , data: data)
		}

		pub fun addForgeMintType(_ mintType: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForgeOrder.addMintType(mintType)
		}

		pub fun orderForge(leaseName: String, mintType: String, minterCut: UFix64?, collectionDisplay: MetadataViews.NFTCollectionDisplay) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForge.adminOrderForge(leaseName: leaseName, mintType: mintType, minterCut: minterCut, collectionDisplay: collectionDisplay)
		}

		pub fun cancelForgeOrder(leaseName: String, mintType: String){
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindForge.cancelForgeOrder(leaseName: leaseName, mintType: mintType)
		}

		pub fun fulfillForgeOrder(contractName: String, forgeType: Type) : MetadataViews.NFTCollectionDisplay {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			return FindForge.fulfillForgeOrder(contractName, forgeType: forgeType)
		}

		pub fun createFindMarket(name: String, address:Address, defaultCutRules: [FindMarket.TenantRule], findCut: UFix64?) : Capability<&FindMarket.Tenant> {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			var findRoyalty:MetadataViews.Royalty?=nil
			if let cut = findCut{
				let receiver=Admin.account.getCapability<&{FungibleToken.Receiver}>(Profile.publicReceiverPath)
				findRoyalty=MetadataViews.Royalty(receiver: receiver, cut: cut,  description: "find")
			}

			return  FindMarket.createFindMarket(name:name, address:address, defaultCutRules: defaultCutRules, findRoyalty:findRoyalty)
		}

		pub fun removeFindMarketTenant(tenant: Address) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindMarket.removeFindMarketTenant(tenant: tenant)
		}

		pub fun createFindMarketDapper(name: String, address:Address, defaultCutRules: [FindMarket.TenantRule], findRoyalty: MetadataViews.Royalty) : Capability<&FindMarket.Tenant> {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			return  FindMarket.createFindMarket(name:name, address:address, defaultCutRules: defaultCutRules, findRoyalty:findRoyalty)
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

		pub fun addAddon(name:String, addon:String){
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
				FIND.validateFindName(name) : "A FIND name has to be lower-cased alphanumeric or dashes and between 3 and 16 characters"
			}

			let user = FIND.lookupAddress(name) ?? panic("Cannot find lease owner. Lease : ".concat(name))
			let ref = getAccount(user).getCapability<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>(FIND.LeasePublicPath).borrow() ?? panic("Cannot borrow reference to lease collection of user : ".concat(name))
			ref.adminAddAddon(name:name, addon:addon)
		}

		pub fun adminSetMinterPlatform(name: String, forgeType: Type, minterCut: UFix64?, description: String, externalURL: String, squareImage: String, bannerImage: String, socials: {String : String}) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
				FIND.validateFindName(name) : "A FIND name has to be lower-cased alphanumeric or dashes and between 3 and 16 characters"
			}

			FindForge.adminSetMinterPlatform(leaseName: name, forgeType: forgeType, minterCut: minterCut, description: description, externalURL: externalURL, squareImage: squareImage, bannerImage: bannerImage, socials: socials)
		}

		pub fun mintForge(name: String, forgeType: Type , data: AnyStruct, receiver: &{NonFungibleToken.Receiver, MetadataViews.ResolverCollection}) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}

			FindForge.mintAdmin(leaseName: name, forgeType: forgeType, data: data, receiver: receiver)
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
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FTRegistry.setFTInfo(alias: alias, type: type, tag: tag, icon: icon, receiverPath: receiverPath, balancePath: balancePath, vaultPath:vaultPath)

		}

		// Remove FungibleToken Information by type identifier
		pub fun removeFTInfoByTypeIdentifier(_ typeIdentifier: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FTRegistry.removeFTInfoByTypeIdentifier(typeIdentifier)
		}


		// Remove FungibleToken Information by alias
		pub fun removeFTInfoByAlias(_ alias: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FTRegistry.removeFTInfoByAlias(alias)
		}

		/// ===================================================================================
		// Find Market Options
		/// ===================================================================================
		pub fun addSaleItemType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.addSaleItemType(type)
		}

		pub fun addMarketBidType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.addMarketBidType(type)
		}

		pub fun addSaleItemCollectionType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.addSaleItemCollectionType(type)
		}

		pub fun addMarketBidCollectionType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.addMarketBidCollectionType(type)
		}

		pub fun removeSaleItemType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.removeSaleItemType(type)
		}

		pub fun removeMarketBidType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.removeMarketBidType(type)
		}

		pub fun removeSaleItemCollectionType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.removeSaleItemCollectionType(type)
		}

		pub fun removeMarketBidCollectionType(_ type: Type) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.removeMarketBidCollectionType(type)
		}

		/// ===================================================================================
		// Tenant Rules Management
		/// ===================================================================================
		pub fun getTenantRef(_ tenant: Address) : &FindMarket.Tenant {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let string = FindMarket.getTenantPathForAddress(tenant)
			let pp = PrivatePath(identifier: string) ?? panic("Cannot generate storage path from string : ".concat(string))
			let cap = Admin.account.getCapability<&FindMarket.Tenant>(pp)
			return cap.borrow() ?? panic("Cannot borrow tenant reference from path. Path : ".concat(pp.toString()) )
		}

		pub fun addFindBlockItem(tenant: Address, item: FindMarket.TenantSaleItem) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.addSaleItem(item, type: "find")
		}

		pub fun removeFindBlockItem(tenant: Address, name: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.removeSaleItem(name, type: "find")
		}

		pub fun setFindCut(tenant: Address, saleItemName: String, cut: UFix64?, rules: [FindMarket.TenantRule]?, status: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
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
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			if !(rules.length > 0) {
				panic("Rules cannot be empty array")
			}
			let tenant = self.getTenantRef(tenant)

			if tenant.checkFindCuts(FindCutName) {
				panic("This find cut already exist. FindCut rule Name : ".concat(FindCutName))
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
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.addSaleItem(saleItem, type: "tenant")
			//Emit Event here
		}

		pub fun removeMarketOption(tenant: Address, name: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.removeSaleItem(name, type: "tenant")
		}

		pub fun enableMarketOption(tenant: Address, name: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.alterMarketOption(name: name, status: "active")
		}

		pub fun deprecateMarketOption(tenant: Address, name: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.alterMarketOption(name: name, status: "deprecated")
		}

		pub fun stopMarketOption(tenant: Address, name: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenant = self.getTenantRef(tenant)
			tenant.alterMarketOption(name: name, status: "stopped")
		}

		pub fun setTenantRule(tenant: Address, optionName: String, tenantRule: FindMarket.TenantRule) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenantRef = self.getTenantRef(tenant)
			tenantRef.setTenantRule(optionName: optionName, tenantRule: tenantRule)
		}

		pub fun removeTenantRule(tenant: Address, optionName: String, tenantRuleName: String) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			let tenantRef = self.getTenantRef(tenant)
			tenantRef.removeTenantRule(optionName: optionName, tenantRuleName: tenantRuleName)
		}

		/// ===================================================================================
		// Royalty Residual
		/// ===================================================================================

		pub fun setResidualAddress(_ address: Address) {
			pre {
				self.capability != nil: "Cannot create FIND, capability is not set"
			}
			FindMarket.setResidualAddress(address)
		}

		/// ===================================================================================
		// Find Pack
		/// ===================================================================================

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

		pub fun getProviderCap(_ path: PrivatePath): Capability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}> {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			return Admin.account.getCapability<&{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(path)
		}

		pub fun mintFindPack(packTypeName: String, typeId:UInt64,hash: String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			let pathIdentifier = FindPack.getPacksCollectionPath(packTypeName: packTypeName, packTypeId: typeId)
			let path = PublicPath(identifier: pathIdentifier)!
			let receiver = Admin.account.getCapability<&{NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(path).borrow() ?? panic("Cannot borrow reference to admin find pack collection public from Path : ".concat(pathIdentifier))
			let mintPackData = FindPack.MintPackData(packTypeName: packTypeName, typeId: typeId, hash: hash, verifierRef: FindForge.borrowVerifier())
			FindForge.adminMint(lease: packTypeName, forgeType: Type<@FindPack.Forge>() , data: mintPackData, receiver: receiver)
		}

		pub fun fulfillFindPack(packId:UInt64, types:[Type], rewardIds: [UInt64], salt:String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}
			FindPack.fulfill(packId:packId, types:types, rewardIds:rewardIds, salt:salt)
		}

		pub fun requeueFindPack(packId:UInt64) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let cap= Admin.account.borrow<&FindPack.Collection>(from: FindPack.DLQCollectionStoragePath)!
			cap.requeue(packId: packId)
		}

		pub fun getFindRoyaltyCap() : Capability<&{FungibleToken.Receiver}> {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			return Admin.account.getCapability<&{FungibleToken.Receiver}>(Profile.publicReceiverPath)
		}

		/// ===================================================================================
		// FINDNFTCatalog
		/// ===================================================================================

		pub fun addCatalogEntry(collectionIdentifier : String, metadata : NFTCatalog.NFTCatalogMetadata) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let FINDCatalogAdmin = Admin.account.borrow<&FINDNFTCatalogAdmin.Admin>(from: FINDNFTCatalogAdmin.AdminStoragePath) ?? panic("Cannot borrow reference to Find NFT Catalog admin resource")
        	FINDCatalogAdmin.addCatalogEntry(collectionIdentifier : collectionIdentifier, metadata : metadata)
		}

		pub fun removeCatalogEntry(collectionIdentifier : String) {
			pre {
				self.capability != nil: "Cannot create Admin, capability is not set"
			}

			let FINDCatalogAdmin = Admin.account.borrow<&FINDNFTCatalogAdmin.Admin>(from: FINDNFTCatalogAdmin.AdminStoragePath) ?? panic("Cannot borrow reference to Find NFT Catalog admin resource")
        	FINDCatalogAdmin.removeCatalogEntry(collectionIdentifier : collectionIdentifier)
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

