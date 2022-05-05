import FungibleToken from 0xf233dcee88fe0abe
import NFTStorefront from 0x4eb8a10cb9f87357

pub contract ZeedzMarketplace {

    pub event AddedListing(
        storefrontAddress: Address,
        listingResourceID: UInt64,
        nftType: Type,
        nftID: UInt64,
        ftVaultType: Type,
        price: UFix64
    )

    pub event RemovedListing(
        listingResourceID: UInt64,
        nftType: Type,
        nftID: UInt64,
        ftVaultType: Type,
        price: UFix64
    )

    //
    // A NFT listed on the Zeedz Marketplace, contains the NFTStorefront listingID, capability, listingDetails and timestamp.
    //
    pub struct Item {
        pub let storefrontPublicCapability: Capability<&{NFTStorefront.StorefrontPublic}>

        // NFTStorefront.Listing resource uuid
        pub let listingID: UInt64

        // Store listingDetails to prevent vanishing from storefrontPublicCapability
        pub let listingDetails: NFTStorefront.ListingDetails

        // Time when the listing was added to the Zeedz Marketplace
        pub let timestamp: UFix64

        init(storefrontPublicCapability: Capability<&{NFTStorefront.StorefrontPublic}>, listingID: UInt64) {
            self.storefrontPublicCapability = storefrontPublicCapability
            self.listingID = listingID
            let storefrontPublic = storefrontPublicCapability.borrow() ?? panic("Could not borrow public storefront from capability")
            let listingPublic = storefrontPublic.borrowListing(listingResourceID: listingID) ?? panic("no listing id")
            // check if owner is correct
            assert(listingPublic.borrowNFT() != nil, message: "could not borrow NFT")

            self.listingDetails = listingPublic.getDetails()
            self.timestamp = getCurrentBlock().timestamp
        }
    }

    //
    // A Sale cut requirement for each listing to be listed on the Zeedz Marketplace, updatable by the administrator.
    // Contains a FungibleToken reciever capability for the sale cut recieving address and a ratio which defines the percentage of the sale cut.
    //
    pub struct SaleCutRequirement {
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        pub let ratio: UFix64

        init(receiver: Capability<&{FungibleToken.Receiver}>, ratio: UFix64) {
            pre {
                ratio <= 1.0: "ratio must be less than or equal to 1.0"
            }
            self.receiver = receiver
            self.ratio = ratio
        }
    }

    pub let ZeedzMarketplaceAdminStoragePath: StoragePath

    // listingID order by time, listingID asc
    access(contract) let listingIDs: [UInt64]

    // listingID => item
    access(contract) let listingIDItems: {UInt64: Item}

    // collection identifier => (NFT id => listingID)
    access(contract) let collectionNFTListingIDs: {String: {UInt64: UInt64}}

    // {Type of the FungibleToken => array of SaleCutRequirements}
    access(contract) var saleCutRequirements: {String : [SaleCutRequirement]}

    //
    // Administrator resource, owner account can update the Zeedz Marketplace sale cut requirements and remove listings.
    //
    pub resource Administrator {

        pub fun updateSaleCutRequirement(requirements: [SaleCutRequirement], vaultType: Type) {
            var totalRatio: UFix64 = 0.0
            for requirement in requirements {
                totalRatio = totalRatio + requirement.ratio
            }
            assert(totalRatio <= 1.0, message: "total ratio must be less than or equal to 1.0")
            ZeedzMarketplace.saleCutRequirements[vaultType.identifier] = requirements
        }

        pub fun forceRemoveListing(id: UInt64) {
            if let item = ZeedzMarketplace.listingIDItems[id] {
                ZeedzMarketplace.removeItem(item)
            }
        }
    }

    //
    // Adds a listing with the specified id and storefrontPublicCapability to the marketplace.
    //
    pub fun addListing(id: UInt64, storefrontPublicCapability: Capability<&{NFTStorefront.StorefrontPublic}>) {
        let item = Item(storefrontPublicCapability: storefrontPublicCapability, listingID: id)

        let indexToInsertListingID = self.getIndexToAddListingID(item: item, items: self.listingIDs)

        self.addItem(
            item,
            storefrontPublicCapability: storefrontPublicCapability,
            indexToInsertListingID: indexToInsertListingID)
    }

    //
    // Can be used by anyone to remove a listing if the listed item has been removed or purchased.
    //
    pub fun removeListing(id: UInt64) {
        if let item = self.listingIDItems[id] {
            // Skip if the listing item hasn't been purchased
            if let storefrontPublic = item.storefrontPublicCapability.borrow() {
                if let listingItem = storefrontPublic.borrowListing(listingResourceID: id) {
                    let listingDetails = listingItem.getDetails()
                    if listingDetails.purchased == false {
                        return
                    }
                }
            }

            self.removeItem(item)
        }
    }

    //
    // Returns an array of all listingsIDs currently listend on the marketplace.
    //
    pub fun getListingIDs(): [UInt64] {
        return self.listingIDs
    }

    //
    // Returns the item listed with the specified listingID.
    //
    pub fun getListingIDItem(listingID: UInt64): Item? {
        return self.listingIDItems[listingID]
    }

    //
    // Returns the listingID of the item from the specified nftType and nftID.
    //
    pub fun getListingID(nftType: Type, nftID: UInt64): UInt64? {
        let nftListingIDs = self.collectionNFTListingIDs[nftType.identifier] ?? {}
        return nftListingIDs[nftID]
    }

    //
    // Returns an array of the current marketplace SaleCutRequirements 
    //
    pub fun getAllSaleCutRequirements(): {String: [SaleCutRequirement]} {
        return self.saleCutRequirements
    }

    //
    // Returns an array of the current marketplace SaleCutRequirements for the specified VaultType
    //
    pub fun getVaultTypeSaleCutRequirements(vaultType: Type): [SaleCutRequirement]? {
        return self.saleCutRequirements[vaultType.identifier]
    }

    // 
    // Helper function to add an item to the marketplace
    //
    access(contract) fun addItem(
        _ item: Item,
        storefrontPublicCapability: Capability<&{NFTStorefront.StorefrontPublic}>,
        indexToInsertListingID: Int
    ) {
        pre {
            self.listingIDItems[item.listingID] == nil: "could not add duplicate listing"
        }

        assert(item.listingDetails.purchased == false, message: "the item has been purchased")

        // find previous duplicate NFT
        let nftListingIDs = self.collectionNFTListingIDs[item.listingDetails.nftType.identifier]
        var previousItem: Item? = nil
        if let nftListingIDs = nftListingIDs {
            if let listingID = nftListingIDs[item.listingDetails.nftID] {
                previousItem = self.listingIDItems[listingID]!

                // panic only if they're same address
                if previousItem!.storefrontPublicCapability.address == item.storefrontPublicCapability.address {
                    panic("could not add duplicate NFT")
                }
            }
        }
        
        // check sale cut
        if let requirements = self.saleCutRequirements[item.listingDetails.salePaymentVaultType.identifier] {
            for requirement in requirements {
                let saleCutAmount = item.listingDetails.salePrice * requirement.ratio

                var match = false
                for saleCut in item.listingDetails.saleCuts {
                    if saleCut.receiver.address == requirement.receiver.address &&
                    saleCut.receiver.borrow()! == requirement.receiver.borrow()! {
                        if saleCut.amount >= saleCutAmount {
                            match = true
                        }
                        break
                    }
                }

                assert(match == true, message: "saleCut must follow SaleCutRequirements")
            }
        }

        // all by time
        self.listingIDs.insert(at: indexToInsertListingID, item.listingID)

        // update index data
        self.listingIDItems[item.listingID] = item
        if let nftListingIDs = nftListingIDs {
            nftListingIDs[item.listingDetails.nftID] = item.listingID
            self.collectionNFTListingIDs[item.listingDetails.nftType.identifier] = nftListingIDs
        } else {
            self.collectionNFTListingIDs[item.listingDetails.nftType.identifier] = {item.listingDetails.nftID: item.listingID}
        }

        // remove previous item
        if let previousItem = previousItem {
            self.removeItem(previousItem)
        }

        emit AddedListing(
            storefrontAddress: storefrontPublicCapability.address,
            listingResourceID: item.listingID,
            nftType: item.listingDetails.nftType,
            nftID: item.listingDetails.nftID,
            ftVaultType: item.listingDetails.salePaymentVaultType,
            price: item.listingDetails.salePrice
        )
    }

    //
    // Helper function to remove item. The indexes will be found automatically.
    //
    access(contract) fun removeItem(_ item: Item) {
        let indexToRemoveListingID = self.getIndexToRemoveListingID(
            item: item,
            items: self.listingIDs)

        self.removeItemWithIndexes(
            item,
            indexToRemoveListingID: indexToRemoveListingID)
    }

    //
    // Helper function to remove item with index. The index should be checked before calling this function.
    //
    access(contract) fun removeItemWithIndexes(_ item: Item, indexToRemoveListingID: Int?) {
        // remove from listingIDs
        if let indexToRemoveListingID = indexToRemoveListingID {
            self.listingIDs.remove(at: indexToRemoveListingID)
        }

        // update index data
        self.listingIDItems.remove(key: item.listingID)
        let nftListingIDs = self.collectionNFTListingIDs[item.listingDetails.nftType.identifier] ?? {}
        nftListingIDs.remove(key: item.listingDetails.nftID)
        self.collectionNFTListingIDs[item.listingDetails.nftType.identifier] = nftListingIDs

        emit RemovedListing(
            listingResourceID: item.listingID,
            nftType: item.listingDetails.nftType,
            nftID: item.listingDetails.nftID,
            ftVaultType: item.listingDetails.salePaymentVaultType,
            price: item.listingDetails.salePrice,
        )
    }

    //
    // Run reverse for loop to find out the index to insert.
    //
    access(contract) fun getIndexToAddListingID(item: Item, items: [UInt64]): Int {
        var index = items.length - 1
        while index >= 0 {
            let currentListingID = items[index]
            let currentItem = self.listingIDItems[currentListingID]!

            if item.timestamp == currentItem.timestamp {
                if item.listingID > currentListingID {
                    break
                }
                index = index - 1
            } else {
                break
            }
        }
        return index + 1
    }

    //
    // Run binary search to find the listing ID.
    //
    access(contract) fun getIndexToRemoveListingID(item: Item, items: [UInt64]): Int? {
        var startIndex = 0
        var endIndex = items.length

        while startIndex < endIndex {
            var midIndex = startIndex + (endIndex - startIndex) / 2
            var midListingID = items[midIndex]!
            var midItem = self.listingIDItems[midListingID]!

            if item.timestamp > midItem.timestamp {
                startIndex = midIndex + 1
            } else if item.timestamp < midItem.timestamp {
                endIndex = midIndex
            } else {
                if item.listingID > midListingID {
                    startIndex = midIndex + 1
                }  else if item.listingID < midListingID {
                    endIndex = midIndex
                } else {
                    return midIndex
                }
            }
        }
        return nil
    }

    init () {
        self.ZeedzMarketplaceAdminStoragePath = /storage/ZeedzMarketplaceAdmin

        self.listingIDs = []
        self.listingIDItems = {}
        self.collectionNFTListingIDs = {}
        self.saleCutRequirements = {}

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.ZeedzMarketplaceAdminStoragePath)
    }
}