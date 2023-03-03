import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import NFTCatalog from 0x49a7cda3a1eecc29
import NFTStorefront from 0x4eb8a10cb9f87357
import NFTStorefrontV2 from 0x4eb8a10cb9f87357

access(all) contract BulkSales {

    /// AllowBulkPurchasing
    /// Toggle to control execution of new bulk purchases
    access(contract) var AllowBulkPurchasing: Bool

    /// AllowBulkListing
    /// Toggle to control creation of new bulk listings
    access(contract) var AllowBulkListing: Bool

    /// BulkSalesAdminStoragePath
    /// Storage path for contract admin object
    access(account) let BulkSalesAdminStoragePath: StoragePath

    /// CommissionAdminPrivatePath
    /// Private path for commission admin capability
    access(account) let CommissionAdminPrivatePath: PrivatePath

    /// CommissionReaderPublicPath
    /// Public path for commission reader capability
    access(all) let CommissionReaderPublicPath: PublicPath

    /// CommissionReaderCapability
    /// Stored capability for commission reader
    access(all) let CommissionReaderCapability: Capability<&BulkSalesAdmin{CommissionReader}>

    /// ContractCommissionRate
    /// Facilitator commission rate applied to new listings
    access(all) var ContractCommissionRate: UFix64

    /// SecondaryCommissionRate
    /// Commission rate applied to listings created on other platforms (only applies to NFTStorefront v1 listings)
    access(all) var SecondaryCommissionRate: UFix64

    /// DefaultExpirationDays
    /// Default number of days for a listing to expire
    access(all) var DefaultExpirationDays: UInt64

    /// PurchaseOrder
    /// All data necessary to purchase a single NFT listed for sale
    access(all) struct PurchaseOrder {
        access(contract) let ownerAddress: Address
        access(contract) let listingID: UInt64
        access(contract) var storefrontVersion: UInt8?

        // Helper function to allow BulkPurchaseOrder to set storefront version
        access(contract) fun setStorefrontVersion(_ version: UInt8) {
            pre {
                version == 1 || version == 2: "storefront version must be 1 or 2"
            }
            self.storefrontVersion = version
        }

        init(ownerAddress: Address, listingID: UInt64) {
            self.ownerAddress = ownerAddress
            self.listingID = listingID
            self.storefrontVersion = nil
        }
    }

    /// BulkPurchaseOrder
    /// An object to manage an entire bulk purchase, with a helper method to calculate a price total by currency
    access(all) struct BulkPurchaseOrder {
        access(contract) let orders: [PurchaseOrder]
        access(contract) let storefrontV1Refs: {Address: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}}
        access(contract) let storefrontV2Refs: {Address: &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}}
        access(contract) let priceTotals: {String: UFix64}

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
        access(self) fun tabulateV1Listing(_ listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}, order: PurchaseOrder) {
            let listingDetails = listing.getDetails()
            assert(!listingDetails.purchased, message: "listing has already been purchased for ".concat(listingDetails.nftType.identifier))
            self.addToPriceTotal(vaultIdentifier: listingDetails.salePaymentVaultType.identifier, listingDetails.salePrice)
            order.setStorefrontVersion(1)
        }

        // Helper function to verify NFTStorefrontV2 listing, tabulate price, and save storefront version
        access(self) fun tabulateV2Listing(_ listing: &NFTStorefrontV2.Listing{NFTStorefrontV2.ListingPublic}, order: PurchaseOrder) {
            let listingDetails = listing.getDetails()
            assert(!listingDetails.purchased, message: "listing has already been purchased for ".concat(listingDetails.nftType.identifier))
            self.addToPriceTotal(vaultIdentifier: listingDetails.salePaymentVaultType.identifier, listingDetails.salePrice)
            order.setStorefrontVersion(2)
        }

        init(orders: [PurchaseOrder]) {
            self.orders = orders
            self.storefrontV1Refs = {}
            self.storefrontV2Refs = {}
            self.priceTotals = {}

            // find listing, save storefront version, verify that listings are not expired or purchased, check NFT type, sum totals
            for order in orders {

                // search for listing in saved NFTStorefront (v1) reference
                if (self.storefrontV1Refs.containsKey(order.ownerAddress)) {
                    if let listing = self.storefrontV1Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                        self.tabulateV1Listing(listing, order: order)
                        continue
                    }
                }

                // search for listing in saved NFTStorefrontV2 reference
                if (self.storefrontV2Refs.containsKey(order.ownerAddress)) {
                    if let listing = self.storefrontV2Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                        self.tabulateV2Listing(listing, order: order)
                        continue
                    }
                }

                // create new NFTStorefront (v1) reference and search for listing
                if (!self.storefrontV1Refs.containsKey(order.ownerAddress)) {

                    // try to get storefrontV1 reference and save
                    let storefrontV1 = getAccount(order.ownerAddress)
                        .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
                        .borrow()
                    if (storefrontV1 != nil) {
                        self.storefrontV1Refs.insert(key: order.ownerAddress, storefrontV1!)

                        // try to find NFTStorefront (v1) listing
                        if let listing = self.storefrontV1Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                            self.tabulateV1Listing(listing, order: order)
                            continue
                        }
                    }
                }

                // create new NFTStorefrontV2 reference and search for listing
                if (!self.storefrontV2Refs.containsKey(order.ownerAddress)) {

                    // try to get storefrontV2 reference and save
                    let storefrontV2 = getAccount(order.ownerAddress)
                        .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)
                        .borrow()
                    if (storefrontV2 != nil) {
                        self.storefrontV2Refs.insert(key: order.ownerAddress, storefrontV2!)

                        // try to find NFTStorefrontV2 listing
                        if let listing = self.storefrontV2Refs[order.ownerAddress]!.borrowListing(listingResourceID: order.listingID) {
                            self.tabulateV2Listing(listing, order: order)
                            continue
                        }
                    }
                }

                panic("could not find listing for ".concat(order.listingID.toString()))
            }
        }
    }

    /// Royalty
    /// An object representing a single royalty cut for a given listing
    access(all) struct Royalty {
        access(all) let receiverAddress: Address
        access(all) let rate: UFix64

        init(receiverAddress: Address, rate: UFix64) {
            pre {
                rate > 0.0 && rate < 1.0: "rate must be between 0 and 1"
            }
            self.receiverAddress = receiverAddress
            self.rate = rate
        }
    }

    /// ListingOrder
    /// All data necessary to list a single NFT for sale
    /// Param expirationDays defines the number of days the listing should be valid for, and only applies to V2 listings
    access(all) struct ListingOrder {
        access(contract) let nftType: Type
        access(contract) let nftID: UInt64
        access(contract) let salePrice: UFix64
        access(contract) let royalties: [Royalty]
        access(contract) let expirationDays: UInt64

        init(
            nftTypeIdentifier: String,
            nftID: UInt64,
            salePrice: UFix64,
            royalties: [Royalty],
            expirationDays: UInt64?
        ) {
            pre {
                salePrice > 0.0: "salePrice must be greater than 0"
            }

            self.nftType = CompositeType(nftTypeIdentifier)
                ?? panic("unable to cast type; must be a valid NFT type reference")
            self.nftID = nftID
            self.salePrice = salePrice
            self.royalties = royalties
            self.expirationDays = expirationDays ?? BulkSales.DefaultExpirationDays
        }
    }

    /// SalesAdmin
    /// Private capability to toggle sales
    access(all) resource interface SalesAdmin {
        access(all) fun toggleBulkPurchasing(_ value: Bool)
        access(all) fun toggleBulkListing(_ value: Bool)
    }

    /// CommissionAdmin
    /// Private capability to adjust commission settings
    access(all) resource interface CommissionAdmin {
        access(all) fun addContractCommissionReceiver(_ receiver: Capability<&AnyResource{FungibleToken.Receiver}>)
        access(all) fun setCommissionRate(_ rate: UFix64, secondary: Bool)
        access(all) fun addMarketplaceCommissionReceiver(address: Address)
        access(all) fun removeMarketplaceCommissionReceiver(address: Address)
    }

    /// CommissionReader
    /// Public capability to get the contract and marketplace commission receivers
    access(all) resource interface CommissionReader {
        access(all) view fun getContractCommissionReceiver(_ identifier: String): Capability<&AnyResource{FungibleToken.Receiver}>?
        access(all) view fun getMarketplaceCommissionReceivers(vaultPath: PublicPath): [Capability<&{FungibleToken.Receiver}>]
    }

    /// BulkSalesAdmin
    /// This object provides admin controls for commission receivers
    access(all) resource BulkSalesAdmin: SalesAdmin, CommissionAdmin, CommissionReader {

        // This contract's token receivers stored by vault type identifier
        access(self) let contractCommissionReceivers: {String: Capability<&AnyResource{FungibleToken.Receiver}>}

        // Commission receiver addresses for other marketplaces (for NFTStorefrontV2 listings)
        access(self) var marketplaceCommissionAddresses: [Address]

        // Allow or disallow new bulk purchases
        access(all) fun toggleBulkPurchasing(_ value: Bool) {
            BulkSales.AllowBulkPurchasing = value
        }

        // Allow or disallow new bulk listings
        access(all) fun toggleBulkListing(_ value: Bool) {
            BulkSales.AllowBulkListing = value
        }

        // Get a commission receiver by vault type identifier
        access(all) view fun getContractCommissionReceiver(_ identifier: String): Capability<&AnyResource{FungibleToken.Receiver}>? {
            return self.contractCommissionReceivers[identifier]
        }

        // Get all marketplace commission receivers for new listings (for NFTStorefrontV2 listings)
        access(all) view fun getMarketplaceCommissionReceivers(vaultPath: PublicPath): [Capability<&{FungibleToken.Receiver}>] {
            let marketplaceCommissionReceivers: [Capability<&{FungibleToken.Receiver}>] = []
            for address in self.marketplaceCommissionAddresses {
                let receiver = getAccount(address).getCapability<&{FungibleToken.Receiver}>(vaultPath)
                if (receiver.check()) {
                    marketplaceCommissionReceivers.append(receiver)
                }
            }
            return marketplaceCommissionReceivers
        }

        // Add a commission receiver for sales facilitated by this contract
        access(all) fun addContractCommissionReceiver(_ receiver: Capability<&AnyResource{FungibleToken.Receiver}>) {
            let receiverRef = receiver.borrow() ?? panic("could not borrow receiver")
            self.contractCommissionReceivers.insert(key: receiverRef.getType().identifier, receiver)
        }

        // Function to set the commission rate or secondary commission rate to apply to all sales created through this
        // contract, if a receiver for the listing-specific currency exists
        access(all) fun setCommissionRate(_ rate: UFix64, secondary: Bool) {
            assert(rate < 1.0, message: "commission rate must be less than 1")
            if (secondary) {
                BulkSales.SecondaryCommissionRate = rate
            } else {
                BulkSales.ContractCommissionRate = rate
            }
        }

        access(all) fun addMarketplaceCommissionReceiver(address: Address) {
            if (self.marketplaceCommissionAddresses.firstIndex(of: address) == nil) {
                self.marketplaceCommissionAddresses.append(address)
            }
        }

        access(all) fun removeMarketplaceCommissionReceiver(address: Address) {
            if let indexToRemove = self.marketplaceCommissionAddresses.firstIndex(of: address) {
                self.marketplaceCommissionAddresses.remove(at: indexToRemove)
            }
        }

        init() {
            self.contractCommissionReceivers = {}
            self.marketplaceCommissionAddresses = []
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
        preferredComissionReceiverAddresses: [Address]?
    ) {
        pre {
            BulkSales.AllowBulkPurchasing: "bulk purchasing is paused"
        }

        // ensure that payment vaults have sufficient balance and computed price totals match expected totals
        bulkOrder.priceTotals.forEachKey(fun (key: String): Bool {

            let paymentVaultRef = paymentVaultRefs[key]
                ?? panic("missing paymentVault for ".concat(key))
            assert(paymentVaultRef.balance >= bulkOrder.priceTotals[key]!,
                message: "payment vault balance is less than computed price total for ".concat(key))

            if (expectedTotals != nil) {
                assert(expectedTotals!.containsKey(key),
                    message: "missing expected total for ".concat(key))
                assert(expectedTotals![key]! == bulkOrder.priceTotals[key],
                    message: "expected total does not match computed price total for ".concat(key))
            }

            return true
        })

        for order in bulkOrder.orders {

            if (order.storefrontVersion! == 1) {

                let storefrontV1Ref = bulkOrder.storefrontV1Refs[order.ownerAddress]
                    ?? panic("could not borrow NFTStorefront reference for ".concat(order.ownerAddress.toString()))
                let listing = storefrontV1Ref.borrowListing(listingResourceID: order.listingID)
                    ?? panic("could not find listing for ".concat(order.listingID.toString()))

                // final verification
                let listingDetails = listing.getDetails()
                let paymentVaultRef = paymentVaultRefs[listingDetails.salePaymentVaultType.identifier]!
                assert(listingDetails.salePaymentVaultType == paymentVaultRef.getType(),
                    message: "payment vault type mismatch for ".concat(listingDetails.nftType.identifier))
                let receiverCapability = nftReceiverCapabilities[listingDetails.nftType.identifier]
                    ?? panic("could not find receiver capability for ".concat(listingDetails.nftType.identifier))
                let receiver = receiverCapability.borrow()
                    ?? panic("invalid or missing receiver for ".concat(listingDetails.nftType.identifier))

                // execute order and cleanup storefront
                let orderPayment <- paymentVaultRef.withdraw(amount: listingDetails.salePrice)
                let purchasedItem <- listing.purchase(payment: <-orderPayment)
                receiver.deposit(token: <-purchasedItem)
                storefrontV1Ref.cleanup(listingResourceID: order.listingID)

            } else if (order.storefrontVersion! == 2) {

                let storefrontV2Ref = bulkOrder.storefrontV2Refs[order.ownerAddress]
                    ?? panic("could not borrow NFTStorefrontV2 reference for ".concat(order.ownerAddress.toString()))
                let listing = storefrontV2Ref.borrowListing(listingResourceID: order.listingID)
                    ?? panic("could not find listing for ".concat(order.listingID.toString()))

                // final verification
                let listingDetails = listing.getDetails()
                let paymentVaultRef = paymentVaultRefs[listingDetails.salePaymentVaultType.identifier]!
                assert(listingDetails.salePaymentVaultType == paymentVaultRef.getType(),
                    message: "payment vault type mismatch for ".concat(listingDetails.nftType.identifier))
                let receiverCapability = nftReceiverCapabilities[listingDetails.nftType.identifier]
                    ?? panic("could not find receiver capability for ".concat(listingDetails.nftType.identifier))
                let receiver = receiverCapability.borrow()
                    ?? panic("invalid or missing receiver for ".concat(listingDetails.nftType.identifier))

                // get commissionRecipient if necessary
                var commissionReceiverCapability: Capability<&AnyResource{FungibleToken.Receiver}>? = nil
                if (listingDetails.commissionAmount > 0.0) {
                    if let allowedCommissionReceivers = listing.getAllowedCommissionReceivers() {

                        // attempt to choose preferred commission receiver
                        for allowedReceiver in allowedCommissionReceivers {

                            // always prefer our own commission receiver if allowed
                            if (allowedReceiver.address == self.account.address) {
                                commissionReceiverCapability = allowedReceiver
                                break
                            }

                            // set a preferred commission receiver if possible and not already specified
                            if (commissionReceiverCapability == nil &&
                                preferredComissionReceiverAddresses != nil &&
                                preferredComissionReceiverAddresses!.contains(allowedReceiver.address)
                            ) {
                                commissionReceiverCapability = allowedReceiver
                                continue
                            }
                        }

                        // default to first entry in allowed receiver list
                        if (commissionReceiverCapability == nil) {
                            commissionReceiverCapability = allowedCommissionReceivers[0]
                        }

                    } else {
                        // no commission receivers specified, so attempt to use contract receiver capability
                        let commissionReader = BulkSales.CommissionReaderCapability.borrow()!
                        commissionReceiverCapability = commissionReader.getContractCommissionReceiver(listingDetails.salePaymentVaultType.identifier)
                            ?? panic("unable to find contract commission receiver capability for ".concat(listingDetails.salePaymentVaultType.identifier))
                    }
                }

                // execute order and cleanup storefront
                let orderPayment <- paymentVaultRef.withdraw(amount: listingDetails.salePrice)
                let purchasedItem <- listing.purchase(
                    payment: <-orderPayment,
                    commissionRecipient: commissionReceiverCapability
                )
                receiver.deposit(token: <-purchasedItem)
                storefrontV2Ref.cleanupPurchasedListings(listingResourceID: order.listingID)
            }
        }
    }

    /// listNFTs
    /// Function to list a group of NFTs for sale using the NFTStorefrontV2 contract.
    /// Param nftProviderCapabilities should contain one capability per NFT collection being listed.
    /// Returns a nested dictionary of listing IDs by NFT type.
    access(all) fun listNFTs(
        listingOrders: [ListingOrder],
        nftProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>},
        saleVaultPath: PublicPath,
        storefront: &NFTStorefrontV2.Storefront
    ): {String: AnyStruct} {
        pre {
            BulkSales.AllowBulkListing: "bulk listing is paused"
            storefront.owner != nil: "storefront must be owned by an account"
        }

        // check seller vault and get type
        let saleVaultCapability = storefront.owner!.getCapability<&AnyResource{FungibleToken.Receiver}>(saleVaultPath)
        let saleVaultRef = saleVaultCapability.borrow()
            ?? panic("seller receiver vault invalid or missing for ".concat(saleVaultPath.toString()))

        let listingIDs: {String: AnyStruct} = {}

        for order in listingOrders {

            let nftProviderCapability = nftProviderCapabilities[order.nftType.identifier]
                ?? panic("could not find provider for ".concat(order.nftType.identifier))

            let orderIDs = BulkSales.listNFT(
                storefront: storefront,
                saleVaultPath: saleVaultPath,
                saleVaultCapability: saleVaultCapability,
                saleVaultType: saleVaultRef.getType(),
                listingOrder: order,
                nftProviderCapability: nftProviderCapability
            )
            listingIDs.insert(key: order.nftType.identifier, orderIDs)
        }

        return listingIDs
    }

    /// listNFT
    /// Function to list an NFT for sale using the NFTStorefrontV2 contract.
    /// Returns a dictionary of order IDs.
    access(contract) fun listNFT(
        storefront: &NFTStorefrontV2.Storefront,
        saleVaultPath: PublicPath,
        saleVaultCapability: Capability<&AnyResource{FungibleToken.Receiver}>,
        saleVaultType: Type,
        listingOrder: ListingOrder,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    ): {String: UInt64} {

        // check NFT provider capability and verify ownership
        let collectionPublic = nftProviderCapability.borrow()
            ?? panic("could not borrow NFT provider capability for ".concat(listingOrder.nftID.toString()))
        assert(collectionPublic.getIDs().contains(listingOrder.nftID),
            message: "could not verify ownership for ".concat(listingOrder.nftID.toString()))

        // variables for Evaluate listing
        let saleCutsV2: [NFTStorefrontV2.SaleCut] = []
        let marketplaceCapabilities: [Capability<&{FungibleToken.Receiver}>] = []
        var totalCutAmount: UFix64 = 0.0

        // add contract commission sale cut, if applicable
        if (BulkSales.ContractCommissionRate > 0.0) {

            let commissionReader = BulkSales.CommissionReaderCapability.borrow()!
            let commissionReceiver = commissionReader.getContractCommissionReceiver(saleVaultType.identifier)
                ?? panic("no contract commission receiver found for ".concat(saleVaultType.identifier))

            let commissionAmount = listingOrder.salePrice * BulkSales.ContractCommissionRate
            totalCutAmount = totalCutAmount + commissionAmount

            // add contract commission receiver
            marketplaceCapabilities.append(commissionReceiver)

            // add other marketplace commission receivers (to show listings on their pages)
            let otherMarketplaceCapabilities = commissionReader.getMarketplaceCommissionReceivers(vaultPath: saleVaultPath)
            for capability in otherMarketplaceCapabilities {
                marketplaceCapabilities.append(capability)
            }
        }

        for royalty in listingOrder.royalties {

            // check royalty receiver type
            let royaltyReceiver = getAccount(royalty.receiverAddress).getCapability<&{FungibleToken.Receiver}>(saleVaultPath)
            let receiverRef = royaltyReceiver.borrow()
                ?? panic("could not borrow royalty receiver for ".concat(saleVaultPath.toString()))
            assert(receiverRef.getType() == saleVaultType,
                message: "royalty vault type does not match seller vault type for ".concat(royalty.receiverAddress.toString()))

            // add sale cut for royalty
            let royaltyAmount = listingOrder.salePrice * royalty.rate
            totalCutAmount = totalCutAmount + royaltyAmount
            saleCutsV2.append(NFTStorefrontV2.SaleCut(receiver: royaltyReceiver, amount: royaltyAmount))
        }

        // add seller cut
        assert(totalCutAmount < listingOrder.salePrice, message: "no remaining cut for seller")
        saleCutsV2.append(NFTStorefrontV2.SaleCut(receiver: saleVaultCapability, amount: listingOrder.salePrice - totalCutAmount))

        let orderIDs: {String: UInt64} = {}

        // create NFTStorefrontV2 listings

        // get expiration
        let expirationOffset: UInt64 = listingOrder.expirationDays * 24 * 60 * 60 * 1000
        let expirationEpochMilliseconds: UInt64 = expirationOffset + UInt64(getCurrentBlock().timestamp)

        // check marketplace commission capabilities
        var commissionCapabilities: [Capability<&{FungibleToken.Receiver}>]? = nil
        if (BulkSales.ContractCommissionRate > 0.0) {
            assert(marketplaceCapabilities.length > 0, message: "marketplaceCapabilities cannot be empty if commission is greater than 0")
            commissionCapabilities = marketplaceCapabilities
        }

        let v2OrderID = storefront.createListing(
            nftProviderCapability: nftProviderCapability,
            nftType: listingOrder.nftType,
            nftID: listingOrder.nftID,
            salePaymentVaultType: saleVaultType,
            saleCuts: saleCutsV2,
            marketplacesCapability: commissionCapabilities,
            customID: nil,
            commissionAmount: BulkSales.ContractCommissionRate,
            expiry: expirationEpochMilliseconds
        )
        orderIDs.insert(key: "v2OrderID", v2OrderID)

        return orderIDs
    }

    init() {

        // initialize contract constants
        self.AllowBulkPurchasing = true
        self.AllowBulkListing = true
        self.BulkSalesAdminStoragePath = /storage/bulkSalesAdmin
        self.CommissionAdminPrivatePath = /private/bulkSalesCommissionAdmin
        self.CommissionReaderPublicPath = /public/bulkSalesCommissionReader
        self.ContractCommissionRate = 0.01
        self.SecondaryCommissionRate = 0.0
        self.DefaultExpirationDays = 30

        // save bulk purchase admin object and link capabilities
        self.account.save(<- create BulkSalesAdmin(), to: self.BulkSalesAdminStoragePath)
        self.account.link<&BulkSalesAdmin{CommissionAdmin}>(self.CommissionAdminPrivatePath, target: self.BulkSalesAdminStoragePath)
        self.CommissionReaderCapability = self.account.link<&BulkSalesAdmin{CommissionReader}>(self.CommissionReaderPublicPath, target: self.BulkSalesAdminStoragePath)!
    }
}
