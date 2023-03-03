import IBulkSales from 0x0de49bea5b60015b
import DapperUtilityCoin from 0xead892083b3e2c6c
import FungibleToken from 0xf233dcee88fe0abe
import Market from 0xc1e4f4f4c4257510
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import NFTCatalog from 0x49a7cda3a1eecc29
import NFTStorefront from 0x4eb8a10cb9f87357
import NFTStorefrontV2 from 0x4eb8a10cb9f87357
import TopShot from 0x0b2a3299cc857e29
import TopShotMarketV3 from 0xc1e4f4f4c4257510

access(all) contract BulkPurchasing: IBulkSales {

    /// BulkPurchaseExecuted
    /// Event to notify when a user has executed a bulk purchase
    access(all) event BulkPurchaseExecuted(bulkOrder: ReadableBulkPurchaseOrder)

    /// AllowBulkPurchasing
    /// Toggle to control execution of new bulk purchases
    access(contract) var AllowBulkPurchasing: Bool

    /// AdminStoragePath
    /// Storage path for contract admin object
    access(all) let AdminStoragePath: StoragePath

    /// CommissionAdminPrivatePath
    /// Private path for commission admin capability
    access(all) let CommissionAdminPrivatePath: PrivatePath

    /// CommissionReaderPublicPath
    /// Public path for commission reader capability
    access(all) let CommissionReaderPublicPath: PublicPath

    /// CommissionReaderCapability
    /// Stored capability for commission reader
    access(all) let CommissionReaderCapability: Capability<&{IBulkSales.ICommissionReader}>

    /// DefaultExpirationDays
    /// Default number of days for a listing to expire
    access(all) var DefaultExpirationDays: UInt64

    /// PurchaseOrder
    /// All data necessary to purchase a single NFT listed for sale
    access(all) struct PurchaseOrder: IBulkSales.IReadable {
        access(contract) let ownerAddress: Address
        access(contract) let listingID: UInt64
        access(contract) var saleCuts: {String: String}
        access(contract) var executed: Bool
        access(contract) var storefrontVersion: UInt8?
        access(contract) var receiverAddress: Address?
        access(contract) var salePrice: UFix64?
        access(contract) var vaultType: Type?
        access(contract) var nftType: Type?
        access(contract) var nftID: UInt64?

        // Public function for external integration
        access(all) view fun getReadable(): {String: AnyStruct} {
            let storefrontType = self.getStorefrontType()

            return {
                "sellerAddress": self.ownerAddress.toString(),
                "listingID": self.listingID.toString(),
                "source": storefrontType?.identifier ?? "nil",
                "buyerAddress": self.receiverAddress?.toString() ?? "nil",
                "salePrice": self.salePrice?.toString() ?? "nil",
                "saleCuts": self.saleCuts,
                "vaultIdentifier": self.vaultType?.identifier ?? "nil",
                "nftType": self.nftType?.identifier ?? "nil",
                "nftID": self.nftID?.toString() ?? "nil"
            }
        }

        // Helper function to allow BulkPurchaseOrder to set storefront version (use 11 for TopShotMarketV1 and 13 for TopShotMarketV3)
        access(contract) fun setStorefrontVersion(_ version: UInt8) {
            pre {
                version == 1 || version == 2 || version == 11 || version == 13: "storefront version must be 1, 2, 11 (TopShotMarketV1), or 13 (TopShotMarketV3)"
            }
            self.storefrontVersion = version
        }

        // Helper function to get the storefront type, used for getReadable functionality
        access(all) fun getStorefrontType(): Type? {
            var storefrontType: Type? = nil
            if (self.storefrontVersion != nil) {
                if (self.storefrontVersion! == 1) {
                    storefrontType = Type<@NFTStorefront.Storefront>()
                } else if (self.storefrontVersion! == 2) {
                    storefrontType = Type<@NFTStorefrontV2.Storefront>()
                } else if (self.storefrontVersion! == 11) {
                    storefrontType = Type<@Market.SaleCollection>()
                } else if (self.storefrontVersion! == 13) {
                    storefrontType = Type<@TopShotMarketV3.SaleCollection>()
                }
            }
            return storefrontType
        }

        // Helper function to set the token receiver address, used for getReadable functionality
        access(contract) fun setReceiverAddress(_ receiver: Address) {
            self.receiverAddress = receiver
        }

        // Helper function to set the sale price, used for getReadable functionality
        access(contract) fun setSalePrice(_ price: UFix64) {
            pre {
                price > 0.0: "price must be greater than zero"
            }
            self.salePrice = price
        }

        // Helper function to add a sale cut, used for getReadable functionality
        access(contract) fun addSaleCut(recipient: Address?, amount: UFix64) {
            pre {
                self.salePrice != nil: "must set sale price before sale cuts"
                amount <= self.salePrice!: "sale cut must be less than or equal to sale price"
            }

            // if recipient is nil, it's from a TopShot purchase, so there will only maximum one "nil" sale cut per order
            self.saleCuts.insert(key: recipient?.toString() ?? "nil", amount.toString())
        }

        // Helper function to set the sale vault identifier, used for getReadable functionality
        access(contract) fun setVaultType(_ vaultType: Type) {
            pre {
                vaultType.identifier.slice(from: vaultType.identifier.length - 5, upTo: vaultType.identifier.length) == "Vault": "invalid vault type"
            }
            self.vaultType = vaultType
        }

        // Helper function to set the NFT type, used for getReadable functionality
        access(contract) fun setNftType(_ nftType: Type) {
            pre {
                nftType.identifier.slice(from: nftType.identifier.length - 3, upTo: nftType.identifier.length) == "NFT": "invalid NFT type"
            }
            self.nftType = nftType
        }

        // Helper function to set the NFT ID, used for getReadable functionality
        access(contract) fun setNftID(_ id: UInt64) {
            self.nftID = id
        }

        // Helper function to set the "executed" boolean, used for getReadable functionality
        access(contract) fun setExecuted(_ newState: Bool) {
            self.executed = newState
        }

        init(ownerAddress: Address, listingID: UInt64) {
            self.ownerAddress = ownerAddress
            self.listingID = listingID
            self.saleCuts = {}
            self.executed = false
            self.storefrontVersion = nil
            self.receiverAddress = nil
            self.salePrice = nil
            self.vaultType = nil
            self.nftType = nil
            self.nftID = nil
        }
    }

    /// ReadablePurchaseOrder
    /// A human-readable struct meant for use in the BulkPurchaseExecuted event
    access(all) struct ReadablePurchaseOrder {
        access(all) let sellerAddress: String
        access(all) let listingID: String
        access(all) let executed: String
        access(all) let source: String
        access(all) let buyerAddress: String
        access(all) let salePrice: String
        access(all) let saleCuts: {String: String}
        access(all) let vaultIdentifier: String
        access(all) let nftType: String
        access(all) let nftID: String

        init(order: PurchaseOrder) {
            let storefrontType = order.getStorefrontType()

            self.sellerAddress = order.ownerAddress.toString()
            self.listingID = order.listingID.toString()
            if (order.executed) {
                self.executed = "true"
            } else {
                self.executed = "false"
            }
            self.source = storefrontType?.identifier ?? "nil"
            self.buyerAddress = order.receiverAddress?.toString() ?? "nil"
            self.salePrice = order.salePrice?.toString() ?? "nil"
            self.saleCuts = order.saleCuts
            self.vaultIdentifier = order.vaultType?.identifier ?? "nil"
            self.nftType = order.nftType?.identifier ?? "nil"
            self.nftID = order.nftID?.toString() ?? "nil"
        }
    }

    /// ReadableBulkPurchaseOrder
    /// A human-readable struct meant for use in the BulkPurchaseExecuted event
    access(all) struct ReadableBulkPurchaseOrder {
        access(all) let orders: [ReadablePurchaseOrder]
        // actual price totals of all executed orders
        access(all) let priceTotals: {String: String}

        init(
            orders: [PurchaseOrder]
        ) {
            self.orders = []
            let executedPriceTotals: {String: UFix64} = {}
            for order in orders {
                if (order.executed) {
                    let oldTotal = executedPriceTotals[order.vaultType!.identifier] ?? 0.0
                    executedPriceTotals.insert(key: order.vaultType!.identifier, oldTotal + order.salePrice!)
                }
                self.orders.append(ReadablePurchaseOrder(order: order))
            }

            let stringPriceTotals: {String: String} = {}
            for vaultIdentifier in executedPriceTotals.keys {
                stringPriceTotals.insert(key: vaultIdentifier, executedPriceTotals[vaultIdentifier]!.toString())
            }
            self.priceTotals = stringPriceTotals
        }
    }

    /// BulkPurchaseOrder
    /// An object to manage an entire bulk purchase, with a helper method to calculate a price total by currency
    access(all) struct BulkPurchaseOrder: IBulkSales.IReadable {
        access(contract) let orders: [PurchaseOrder]
        access(contract) let topShotMarketV1Refs: {Address: &Market.SaleCollection{Market.SalePublic}}
        access(contract) let topShotMarketV3Refs: {Address: &TopShotMarketV3.SaleCollection{Market.SalePublic}}
        access(contract) let storefrontV1Refs: {Address: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}}
        access(contract) let storefrontV2Refs: {Address: &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}}
        access(contract) let priceTotals: {String: UFix64}

        // Public function for external integration
        access(all) view fun getReadable(): {String: AnyStruct} {

            let readableOrders: [{String: AnyStruct}] = []
            for order in self.orders {
                readableOrders.append(order.getReadable())
            }

            return {
                "orders": readableOrders,
                "priceTotals": self.priceTotals
            }
        }

        access(all) view fun getPriceTotals(): {String: UFix64} {
            return self.priceTotals
        }

        // Helper function to add a sum to a vault total
        access(self) fun addToPriceTotal(vaultIdentifier: String, _ additionalAmount: UFix64) {
            let previousTotal: UFix64 = self.priceTotals[vaultIdentifier] ?? 0.0
            let newTotal: UFix64 = previousTotal + additionalAmount
            self.priceTotals.insert(key: vaultIdentifier, newTotal)
        }

        // Helper function to verify NFTStorefront (v1) listing, tabulate price, and save storefront version
        access(self) fun tabulateV1Listing(_ listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}, order: PurchaseOrder): PurchaseOrder {
            let listingDetails = listing.getDetails()
            assert(!listingDetails.purchased, message: "listing has already been purchased for ".concat(listingDetails.nftType.identifier))
            self.addToPriceTotal(vaultIdentifier: listingDetails.salePaymentVaultType.identifier, listingDetails.salePrice)
            order.setStorefrontVersion(1)
            order.setSalePrice(listingDetails.salePrice)
            order.setVaultType(listingDetails.salePaymentVaultType)
            order.setNftType(listingDetails.nftType)
            order.setNftID(listingDetails.nftID)
            for saleCut in listingDetails.saleCuts {
                order.addSaleCut(recipient: saleCut.receiver.address, amount: saleCut.amount)
            }
            return order
        }

        // Helper function to verify NFTStorefrontV2 listing, tabulate price, and save storefront version
        access(self) fun tabulateV2Listing(_ listing: &NFTStorefrontV2.Listing{NFTStorefrontV2.ListingPublic}, order: PurchaseOrder): PurchaseOrder {
            let listingDetails = listing.getDetails()
            assert(!listingDetails.purchased, message: "listing has already been purchased for ".concat(listingDetails.nftType.identifier))
            self.addToPriceTotal(vaultIdentifier: listingDetails.salePaymentVaultType.identifier, listingDetails.salePrice)
            order.setStorefrontVersion(2)
            order.setSalePrice(listingDetails.salePrice)
            order.setVaultType(listingDetails.salePaymentVaultType)
            order.setNftType(listingDetails.nftType)
            order.setNftID(listingDetails.nftID)
            for saleCut in listingDetails.saleCuts {
                order.addSaleCut(recipient: saleCut.receiver.address, amount: saleCut.amount)
            }
            return order
        }

        access(self) fun tabulateTopShotListing(nftID: UInt64, salePublic: &{Market.SalePublic}, v3: Bool, order: PurchaseOrder): PurchaseOrder {
            pre {
                salePublic.cutPercentage >= 0.0 && salePublic.cutPercentage <= 1.0: "cutPercentage must be between 0 and 1"
            }
            let salePrice = salePublic.getPrice(tokenID: nftID)
            assert(salePrice != nil, message: "listing not found for ".concat(nftID.toString()))
            self.addToPriceTotal(vaultIdentifier: Type<@DapperUtilityCoin.Vault>().identifier, salePrice!)
            order.setSalePrice(salePrice!)
            order.setVaultType(Type<@DapperUtilityCoin.Vault>())
            order.addSaleCut(recipient: nil, amount: salePublic.cutPercentage * salePrice!)
            order.addSaleCut(recipient: order.ownerAddress, amount: (1.0 - salePublic.cutPercentage) * salePrice!)
            order.setNftType(Type<@TopShot.NFT>())
            order.setNftID(nftID)
            if (v3) {
                order.setStorefrontVersion(13)
            } else {
                order.setStorefrontVersion(11)
            }
            return order
        }

        init(orders: [PurchaseOrder], unsafeMode: Bool?) {
            self.orders = []
            self.topShotMarketV1Refs = {}
            self.topShotMarketV3Refs = {}
            self.storefrontV1Refs = {}
            self.storefrontV2Refs = {}
            self.priceTotals = {}

            // find listing, save storefront version, verify that listings are not expired or purchased, check NFT type, sum totals
            for order in orders {

                // search for listing in saved TopShotMarketV3 reference
                if (self.topShotMarketV3Refs.containsKey(order.ownerAddress) && self.topShotMarketV3Refs[order.ownerAddress]!.getIDs().contains(order.listingID)) {
                    let updatedOrder = self.tabulateTopShotListing(nftID: order.listingID, salePublic: self.topShotMarketV3Refs[order.ownerAddress]!, v3: true, order: order)
                    self.orders.append(updatedOrder)
                    continue
                }

                // search for listing in saved TopShot Market (v1) reference
                if (self.topShotMarketV1Refs.containsKey(order.ownerAddress) && self.topShotMarketV1Refs[order.ownerAddress]!.getIDs().contains(order.listingID)) {
                    let updatedOrder = self.tabulateTopShotListing(nftID: order.listingID, salePublic: self.topShotMarketV1Refs[order.ownerAddress]!, v3: false, order: order)
                    self.orders.append(updatedOrder)
                    continue
                }

                // search for listing in saved NFTStorefrontV2 reference
                if (self.storefrontV2Refs.containsKey(order.ownerAddress)) {
                    if let listing = self.storefrontV2Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                        let updatedOrder = self.tabulateV2Listing(listing, order: order)
                        self.orders.append(updatedOrder)
                        continue
                    }
                }

                // search for listing in saved NFTStorefront (v1) reference
                if (self.storefrontV1Refs.containsKey(order.ownerAddress)) {
                    if let listing = self.storefrontV1Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                        let updatedOrder = self.tabulateV1Listing(listing, order: order)
                        self.orders.append(updatedOrder)
                        continue
                    }
                }

                // get new TopShotMarketV3 reference and search for listing
                if (!self.topShotMarketV3Refs.containsKey(order.ownerAddress)) {

                    // try to get market v3 reference and save
                    if let marketV3 = getAccount(order.ownerAddress)
                        .getCapability(TopShotMarketV3.marketPublicPath)
                        .borrow<&TopShotMarketV3.SaleCollection{Market.SalePublic}>()
                    {
                        self.topShotMarketV3Refs.insert(key: order.ownerAddress, marketV3)

                        // try to find market v3 listing
                        if (marketV3.getIDs().contains(order.listingID)) {
                            let updatedOrder = self.tabulateTopShotListing(nftID: order.listingID, salePublic: marketV3, v3: true, order: order)
                            self.orders.append(updatedOrder)
                            continue
                        }
                    }
                }

                // get new TopShot Market (v1) reference and search for listing
                if (!self.topShotMarketV1Refs.containsKey(order.ownerAddress)) {

                    // try to get market v1 reference and save
                    if let marketV1 = getAccount(order.ownerAddress)
                        .getCapability(/public/topshotSaleCollection)
                        .borrow<&Market.SaleCollection{Market.SalePublic}>()
                    {
                        self.topShotMarketV1Refs.insert(key: order.ownerAddress, marketV1)

                        // try to find market v1 listing
                        if (marketV1.getIDs().contains(order.listingID)) {
                            let updatedOrder = self.tabulateTopShotListing(nftID: order.listingID, salePublic: marketV1, v3: false, order: order)
                            self.orders.append(updatedOrder)
                            continue
                        }
                    }
                }

                // get new NFTStorefrontV2 reference and search for listing
                if (!self.storefrontV2Refs.containsKey(order.ownerAddress)) {

                    // try to get storefrontV2 reference and save
                    let storefrontV2 = getAccount(order.ownerAddress)
                        .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)
                        .borrow()
                    if (storefrontV2 != nil) {
                        self.storefrontV2Refs.insert(key: order.ownerAddress, storefrontV2!)

                        // try to find NFTStorefrontV2 listing
                        if let listing = self.storefrontV2Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                            let updatedOrder = self.tabulateV2Listing(listing, order: order)
                            self.orders.append(updatedOrder)
                            continue
                        }
                    }
                }

                // get new NFTStorefront (v1) reference and search for listing
                if (!self.storefrontV1Refs.containsKey(order.ownerAddress)) {

                    // try to get storefrontV1 reference and save
                    let storefrontV1 = getAccount(order.ownerAddress)
                        .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
                        .borrow()
                    if (storefrontV1 != nil) {
                        self.storefrontV1Refs.insert(key: order.ownerAddress, storefrontV1!)

                        // try to find NFTStorefront (v1) listing
                        if let listing = self.storefrontV1Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                            let updatedOrder = self.tabulateV1Listing(listing, order: order)
                            self.orders.append(updatedOrder)
                            continue
                        }
                    }
                }

                // an order without a storefront ref could indicate a TopShot listing that was purchased, because TopShot deletes listings when completed
                if (unsafeMode != true) {
                    panic("could not find listing for ".concat(order.listingID.toString()))
                }
            }
        }
    }

    /// Royalty
    /// An object representing a single royalty cut for a given listing
    access(all) struct Royalty: IBulkSales.IRoyalty, IBulkSales.IReadable {
        access(all) let receiverAddress: Address
        access(all) let rate: UFix64

        // Public function for external integration
        access(all) view fun getReadable(): {String: String} {
            return {
                "receiverAddress": self.receiverAddress.toString(),
                "rate": self.rate.toString()
            }
        }

        init(receiverAddress: Address, rate: UFix64) {
            self.receiverAddress = receiverAddress
            self.rate = rate
        }
    }

    /// PurchasingAdmin
    /// Private capability to toggle sales
    access(all) resource interface PurchasingAdmin {
        access(all) fun toggleBulkPurchasing(_ value: Bool)
    }

    /// BulkPurchasingAdmin
    /// This object provides admin controls for commission receivers
    access(all) resource BulkPurchasingAdmin: PurchasingAdmin, IBulkSales.ICommissionAdmin, IBulkSales.ICommissionReader {

        // This contract's token receivers stored by vault type identifier
        access(self) let contractCommissionReceivers: {String: Capability<&AnyResource{FungibleToken.Receiver}>}

        // Allow or disallow new bulk purchases
        access(all) fun toggleBulkPurchasing(_ value: Bool) {
            BulkPurchasing.AllowBulkPurchasing = value
        }

        // Get a commission receiver by vault type identifier
        access(all) view fun getCommissionReceiver(_ identifier: String): Capability<&AnyResource{FungibleToken.Receiver}>? {
            return self.contractCommissionReceivers[identifier]
        }

        // Add a commission receiver for sales facilitated by this contract
        access(all) fun addCommissionReceiver(_ receiver: Capability<&AnyResource{FungibleToken.Receiver}>) {
            let receiverRef = receiver.borrow() ?? panic("could not borrow receiver")
            self.contractCommissionReceivers.insert(key: receiverRef.getType().identifier, receiver)
        }

        access(all) fun removeCommissionReceiver(receiverTypeIdentifier: String) {
            self.contractCommissionReceivers.remove(key: receiverTypeIdentifier)
        }


        init() {
            self.contractCommissionReceivers = {}
        }
    }

    /// getCatalogEntryForNFT
    /// Helper function that returns one NFTCatalogMetadata entry for a given NFT type.
    /// If an NFT type returns multiple catalog entries, the optional ownerAddress and nftID params are used to match
    /// the proper collection with an nft .
    /// If no entries are found or multiple entries are found with no ownerAddress provided, nil is returned.
    access(all) view fun getCatalogEntryForNFT(
        nftTypeIdentifier: String,
        ownerAddress: Address?,
        nftID: UInt64?
    ): NFTCatalog.NFTCatalogMetadata? {
        let nftCatalogCollections: {String: Bool}? = NFTCatalog.getCollectionsForType(nftTypeIdentifier: nftTypeIdentifier)

        if (nftCatalogCollections == nil || nftCatalogCollections!.keys.length < 1) {

            // found no entries
            return nil

        } else if (nftCatalogCollections!.keys.length == 1) {

            // found one entry
            return NFTCatalog.getCatalogEntry(collectionIdentifier: nftCatalogCollections!.keys[0])

        } else {

            // found multiple entries; attempt to determine which to return
            if (ownerAddress != nil && nftID != nil) {
                let ownerPublicAccount = getAccount(ownerAddress!)
                var catalogEntry: NFTCatalog.NFTCatalogMetadata? = nil

                // attempt to match NFTCatalog entry with NFT from ownerAddress
                nftCatalogCollections!.forEachKey(fun (key: String): Bool {
                    let tempCatalogEntry = NFTCatalog.getCatalogEntry(collectionIdentifier: key)
                    if (tempCatalogEntry != nil) {
                        let collectionCap = ownerPublicAccount.getCapability<&AnyResource{MetadataViews.ResolverCollection}>(tempCatalogEntry!.collectionData.publicPath)
                        if (collectionCap.check()) {
                            let collectionRef = collectionCap.borrow()!
                            if (collectionRef.getIDs().contains(nftID!)) {
                                let viewResolver = collectionRef.borrowViewResolver(id: nftID!)
                                let nftView = MetadataViews.getNFTView(id: nftID!, viewResolver: viewResolver)
                                if (nftView.display!.name == tempCatalogEntry!.collectionDisplay.name) {
                                    catalogEntry = tempCatalogEntry
                                    return false // match found; stop iteration
                                }
                            }
                        }
                    }
                    return true // no match; continue iteration
                })

                return catalogEntry
            }

            // could not determine which of the multiple entries found to return
            return nil

        }
    }

    /// purchaseNFTs
    /// Function to purchase a group of NFTs using the NFTStorefront (v1) and NFTStorefrontV2 contracts.
    access(all) fun purchaseNFTs(
        bulkOrder: BulkPurchaseOrder,
        paymentVaultRefs: {String: &FungibleToken.Vault},
        nftReceiverCapabilities: {String: Capability<&AnyResource{NonFungibleToken.Receiver}>},
        expectedTotals: {String: UFix64}?,
        preferredCommissionReceiverAddresses: [Address]?,
        unsafeMode: Bool?
    ) {
        pre {
            BulkPurchasing.AllowBulkPurchasing: "bulk purchasing is paused"
        }

        // ensure that payment vaults have sufficient balance and computed price totals match expected totals
        bulkOrder.priceTotals.forEachKey(fun (key: String): Bool {

            let paymentVaultRef = paymentVaultRefs[key]
                ?? panic("missing paymentVault for ".concat(key))

            // disable vault balance checks for unsafe mode
            if (unsafeMode != true) {
                assert(paymentVaultRef.balance >= bulkOrder.priceTotals[key]!,
                    message: "payment vault balance is less than computed price total for ".concat(key))
            }

            if (expectedTotals != nil) {
                assert(expectedTotals!.containsKey(key),
                    message: "missing expected total for ".concat(key))
                assert(expectedTotals![key]! == bulkOrder.priceTotals[key],
                    message: "expected total does not match computed price total for ".concat(key))
            }

            return true
        })

        // this stores all orders after the execution flow, whether they were executed or not
        let completedOrders: [PurchaseOrder] = []

        for order in bulkOrder.orders {

            // orders without storefront versions could indicate a TopShot listing that was purchased, because TopShot deletes listings when completed
            if (order.storefrontVersion == nil) {
                if (unsafeMode == true) {
                    completedOrders.append(order)
                    continue
                }
                panic("storefrontVersion not set for listing: ".concat(order.listingID.toString()))
            }

            // TopShot integration
            if (order.storefrontVersion! == 11 || order.storefrontVersion! == 13) {

                var topShotMarket: &{Market.SalePublic}? = nil

                if (bulkOrder.topShotMarketV3Refs[order.ownerAddress] != nil &&
                    bulkOrder.topShotMarketV3Refs[order.ownerAddress]!.getIDs().contains(order.listingID)
                ) {
                    topShotMarket = bulkOrder.topShotMarketV3Refs[order.ownerAddress]!
                } else if (bulkOrder.topShotMarketV1Refs[order.ownerAddress] != nil &&
                    bulkOrder.topShotMarketV1Refs[order.ownerAddress]!.getIDs().contains(order.listingID)
                ) {
                    topShotMarket = bulkOrder.topShotMarketV1Refs[order.ownerAddress]
                } else {
                    if (unsafeMode == true) {
                        completedOrders.append(order)
                        continue
                    }
                    panic("could not find TopShot listing for ".concat(order.listingID.toString()))
                }

                // final verification
                let paymentVaultRef = paymentVaultRefs[Type<@DapperUtilityCoin.Vault>().identifier]!
                assert(paymentVaultRef.getType() == Type<@DapperUtilityCoin.Vault>(),
                    message: "payment vault type mismatch for ".concat(order.listingID.toString()))
                if (order.salePrice! > paymentVaultRef.balance) {
                    if (unsafeMode == true) {
                        completedOrders.append(order)
                        continue
                    }
                    panic("insufficient balance of ".concat(Type<@DapperUtilityCoin.Vault>().identifier))
                }
                let receiverCapability = nftReceiverCapabilities[Type<@TopShot.NFT>().identifier]
                    ?? panic("could not find receiver capability for TopShot")
                let receiver = receiverCapability.borrow()
                    ?? panic("invalid or missing receiver for TopShot")

                // execute order
                let orderPayment <- paymentVaultRef.withdraw(amount: order.salePrice!) as! @DapperUtilityCoin.Vault
                let purchasedItem <- topShotMarket!.purchase(tokenID: order.listingID, buyTokens: <-orderPayment)
                receiver.deposit(token: <-purchasedItem)

                // update values for BulkPurchaseExecuted event
                order.setReceiverAddress(receiverCapability.address)
                order.setExecuted(true)
                completedOrders.append(order)

            } else if (order.storefrontVersion! == 2) {

                let storefrontV2 = bulkOrder.storefrontV2Refs[order.ownerAddress]
                    ?? panic("could not borrow NFTStorefrontV2 reference for ".concat(order.ownerAddress.toString()))
                let listing = storefrontV2.borrowListing(listingResourceID: order.listingID)
                if (listing == nil) {
                    if (unsafeMode == true) {
                        completedOrders.append(order)
                        continue
                    }
                    panic("could not find listing for ".concat(order.listingID.toString()))
                }

                // final verification
                let listingDetails = listing!.getDetails()
                if (listingDetails.purchased == true) {
                    if (unsafeMode == true) {
                        completedOrders.append(order)
                        continue
                    }
                    panic("listing already purchased: ".concat(order.listingID.toString()))
                }
                let paymentVaultRef = paymentVaultRefs[listingDetails.salePaymentVaultType.identifier]!
                assert(listingDetails.salePaymentVaultType == paymentVaultRef.getType(),
                    message: "payment vault type mismatch for ".concat(listingDetails.nftType.identifier))
                if (order.salePrice! > paymentVaultRef.balance) {
                    if (unsafeMode == true) {
                        completedOrders.append(order)
                        continue
                    }
                    panic("insufficient balance of ".concat(listingDetails.salePaymentVaultType.identifier))
                }
                let receiverCapability = nftReceiverCapabilities[listingDetails.nftType.identifier]
                    ?? panic("could not find receiver capability for ".concat(listingDetails.nftType.identifier))
                let receiver = receiverCapability.borrow()
                    ?? panic("invalid or missing receiver for ".concat(listingDetails.nftType.identifier))

                // get commissionRecipient if necessary
                var commissionReceiverCapability: Capability<&AnyResource{FungibleToken.Receiver}>? = nil
                if (listingDetails.commissionAmount > 0.0) {
                    if let allowedCommissionReceivers = listing!.getAllowedCommissionReceivers() {

                        // attempt to choose preferred commission receiver
                        for allowedReceiver in allowedCommissionReceivers {

                            // always prefer our own commission receiver if allowed
                            if (allowedReceiver.address == self.account.address) {
                                commissionReceiverCapability = allowedReceiver
                                break
                            }

                            // set a preferred commission receiver if possible and not already specified
                            if (commissionReceiverCapability == nil &&
                                preferredCommissionReceiverAddresses != nil &&
                                preferredCommissionReceiverAddresses!.contains(allowedReceiver.address)
                            ) {
                                commissionReceiverCapability = allowedReceiver
                            }
                        }

                        // default to first entry in allowed receiver list
                        if (commissionReceiverCapability == nil) {
                            commissionReceiverCapability = allowedCommissionReceivers[0]
                        }

                    } else {
                        // no commission receivers specified, so attempt to use contract receiver capability
                        let commissionReader = BulkPurchasing.CommissionReaderCapability.borrow()!
                        commissionReceiverCapability = commissionReader.getCommissionReceiver(listingDetails.salePaymentVaultType.identifier)
                    }
                }

                // execute order and cleanup storefront
                let orderPayment <- paymentVaultRef.withdraw(amount: listingDetails.salePrice)
                let purchasedItem <- listing!.purchase(
                    payment: <-orderPayment,
                    commissionRecipient: commissionReceiverCapability
                )
                receiver.deposit(token: <-purchasedItem)
                storefrontV2.cleanupPurchasedListings(listingResourceID: order.listingID)

                // update values for BulkPurchaseExecuted event
                order.setReceiverAddress(receiverCapability.address)
                order.setExecuted(true)
                completedOrders.append(order)

            } else if (order.storefrontVersion! == 1) {

                let storefrontV1 = bulkOrder.storefrontV1Refs[order.ownerAddress]
                    ?? panic("could not borrow NFTStorefront reference for ".concat(order.ownerAddress.toString()))
                let listing = storefrontV1.borrowListing(listingResourceID: order.listingID)
                if (listing == nil) {
                    if (unsafeMode == true) {
                        continue
                    }
                    panic("could not find listing for ".concat(order.listingID.toString()))
                }

                // final verification
                let listingDetails = listing!.getDetails()
                if (listingDetails.purchased == true) {
                    if (unsafeMode == true) {
                        continue
                    }
                    panic("listing already purchased: ".concat(order.listingID.toString()))
                }
                let paymentVaultRef = paymentVaultRefs[listingDetails.salePaymentVaultType.identifier]!
                assert(listingDetails.salePaymentVaultType == paymentVaultRef.getType(),
                    message: "payment vault type mismatch for ".concat(listingDetails.nftType.identifier))
                if (order.salePrice! > paymentVaultRef.balance) {
                    if (unsafeMode == true) {
                        completedOrders.append(order)
                        continue
                    }
                    panic("insufficient balance of ".concat(listingDetails.salePaymentVaultType.identifier))
                }
                let receiverCapability = nftReceiverCapabilities[listingDetails.nftType.identifier]
                    ?? panic("could not find receiver capability for ".concat(listingDetails.nftType.identifier))
                let receiver = receiverCapability.borrow()
                    ?? panic("invalid or missing receiver for ".concat(listingDetails.nftType.identifier))

                // execute order and cleanup storefront
                let orderPayment <- paymentVaultRef.withdraw(amount: listingDetails.salePrice)
                let purchasedItem <- listing!.purchase(payment: <-orderPayment)
                receiver.deposit(token: <-purchasedItem)
                storefrontV1.cleanup(listingResourceID: order.listingID)

                // update values for BulkPurchaseExecuted event
                order.setReceiverAddress(receiverCapability.address)
                order.setExecuted(true)
                completedOrders.append(order)
            }
        }

        emit BulkPurchaseExecuted(bulkOrder: ReadableBulkPurchaseOrder(orders: completedOrders))
    }

    init() {

        // initialize contract constants
        self.AllowBulkPurchasing = true
        self.AdminStoragePath = /storage/bulkPurchasingAdmin
        self.CommissionAdminPrivatePath = /private/bulkPurchasingCommissionAdmin
        self.CommissionReaderPublicPath = /public/bulkPurchasingCommissionReader
        self.DefaultExpirationDays = 30

        // save bulk purchase admin object and link capabilities
        self.account.save(<- create BulkPurchasingAdmin(), to: self.AdminStoragePath)
        self.account.link<&BulkPurchasingAdmin{IBulkSales.ICommissionAdmin}>(self.CommissionAdminPrivatePath, target: self.AdminStoragePath)
        self.CommissionReaderCapability = self.account.link<&BulkPurchasingAdmin{IBulkSales.ICommissionReader}>(self.CommissionReaderPublicPath, target: self.AdminStoragePath)!
    }
}
