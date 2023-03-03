import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Meme from 0x4ba5947a0f1852c0
import MemeToken from 0x4ba5947a0f1852c0
import MarketplaceFees from 0x4ba5947a0f1852c0

/// Derived from NFTStorefrontV2
///
/// A general purpose sale support contract for NFTs that implement the Flow NonFungibleToken standard.
/// 
/// Each account that wants to list NFTs for sale installs a Storefront,
/// and lists individual sales within that Storefront as Listings.
/// There is one Storefront per account, it handles sales of all NFT types
/// for that account.
///
/// Each Listing can have one or more "cuts" of the sale price that
/// goes to one or more addresses. Cuts can be used to pay listing fees
/// or other considerations. 
/// Each Listing can include a commission amount that is paid to whoever facilitates
/// the purchase. The seller can also choose to provide an optional list of marketplace 
/// receiver capabilities. In this case, the commission amount must be transferred to
/// one of the capabilities in the list.
///
/// Each NFT may be listed in one or more Listings, the validity of each
/// Listing can easily be checked.
/// 
/// Purchasers can watch for Listing events and check the NFT type and
/// ID to see if they wish to buy the listed item.
/// Marketplaces and other aggregators can watch for Listing events
/// and list items of interest.
/// 
pub contract NFTStorefront {

    /// StorefrontInitialized
    /// A Storefront resource has been created.
    /// Event consumers can now expect events from this Storefront.
    /// Note that we do not specify an address: we cannot and should not.
    /// Created resources do not have an owner address, and may be moved
    /// after creation in ways we cannot check.
    /// ListingAvailable events can be used to determine the address
    /// of the owner of the Storefront (...its location) at the time of
    /// the listing but only at that precise moment in that precise transaction.
    /// If the seller moves the Storefront while the listing is valid, 
    /// that is on them.
    ///
    pub event StorefrontInitialized(address: Address)

    /// StorefrontDestroyed
    /// A Storefront has been destroyed.
    /// Event consumers can now stop processing events from this Storefront.
    /// Note that we do not specify an address.
    ///
    pub event StorefrontDestroyed()

    /// ListingAvailable
    /// A listing has been created and added to a Storefront resource.
    /// The Address values here are valid when the event is emitted, but
    /// the state of the accounts they refer to may change outside of the
    /// NFTStorefrontV2 workflow, so be careful to check when using them.
    ///
    pub event ListingAvailable(
        id: UInt64,
        address: Address,
        nftID: UInt64,
        nftType: Type,
        paymentVaultType: Type,
        price: UFix64,
        expiry: UInt64
    )

    /// ListingCompleted
    /// The listing has been resolved. It has either been purchased, removed or destroyed.
    ///
    pub event ListingCompleted(
        id: UInt64, 
        nftID: UInt64,
        nftType: Type,
        paymentVaultType: Type,
        price: UFix64,
        expiry: UInt64,
        purchased: Bool
    )

    /// UnpaidReceiver
    /// A entitled receiver has not been paid during the sale of the NFT.
    ///
    pub event UnpaidReceiver(receiver: Address, entitledSaleCut: UFix64)

    /// StorefrontAdminStoragePath
    /// The storage path for the admin resource
    pub let StorefrontAdminStoragePath: StoragePath

    /// StorefrontStoragePath
    /// The location in storage that a Storefront resource should be located.
    pub let StorefrontStoragePath: StoragePath

    /// StorefrontPublicPath
    /// The public location for a Storefront link.
    pub let StorefrontPublicPath: PublicPath

    /// FlowTokenVaultPublicPath
    /// The public path to receive a payment
    pub let FlowTokenVaultPublicPath: PublicPath

    /// Index 
    /// Used to identify listings.
    pub var currentIndex: UInt64

    /// SaleCut
    /// A struct representing a recipient that must be sent a certain amount
    /// of the payment when a token is sold.
    ///
    pub struct SaleCut {
        /// The receiver for the payment.
        /// Note that we do not store an address to find the Vault that this represents,
        /// as the link or resource that we fetch in this way may be manipulated,
        /// so to find the address that a cut goes to you must get this struct and then
        /// call receiver.borrow()!.owner.address on it.
        /// This can be done efficiently in a script.
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        /// The amount of the payment FungibleToken that will be paid to the receiver.
        pub let amount: UFix64

        /// An optional description 
        pub let description: String?

        /// initializer
        ///
        init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64, description: String? ) {
            self.receiver = receiver
            self.amount = amount
            self.description = description
        }
    }

    /// ListingDetails
    /// A struct containing a Listing's data.
    ///
    pub struct ListingDetails {
        /// The Storefront that the Listing is stored in.
        /// Note that this resource cannot be moved to a different Storefront,
        /// so this is OK. If we ever make it so that it *can* be moved,
        /// this should be revisited.
        pub var id: UInt64
        /// The unique identifier of the NFT that will get sell.
        pub let nftID: UInt64
        /// The Type of the NonFungibleToken.NFT that is being listed.
        pub let nftType: Type
        /// The Type of the FungibleToken that payments must be made in.
        pub let paymentVaultType: Type
        /// The amount that must be paid in the specified FungibleToken.
        pub let price: UFix64
        /// This specifies the division of payment between recipients.
        pub let saleCuts: [SaleCut]
        /// Expiry of listing
        pub let expiry: UInt64
        /// Whether this listing has been purchased or not.
        pub var purchased: Bool

        /// Irreversibly set this listing as purchased.
        ///
        access(contract) fun setPurchased() {
            self.purchased = true
        }

        /// Initializer
        ///
        // @note: move sale cut inside of init 
        init (
            id: UInt64,
            nftID: UInt64,
            nftType: Type,
            paymentVaultType: Type,
            saleCuts: [SaleCut],  
            expiry: UInt64
        ) {

            pre {
                // Validate the expiry
                expiry > UInt64(getCurrentBlock().timestamp) : "Expiry should be in the future"
                // Validate the length of the sale cut
                // saleCuts.length > 0: "Listing must have at least one payment cut recipient"
            }
            self.id = id
            self.nftID = nftID
            self.nftType = nftType
            self.paymentVaultType = paymentVaultType
            self.expiry = expiry
            self.saleCuts = saleCuts
            self.purchased = false

            var price = UFix64(0.0)

            // Perform initial check on capabilities, and calculate sale price from cut amounts.
            for cut in self.saleCuts {
                // Make sure we can borrow the receiver.
                // We will check this again when the token is sold.
                cut.receiver.borrow() ?? panic("Cannot borrow receiver")
                // Add the cut amount to the total price
                price = price + cut.amount
            }

            assert(price > 0.0, message: "Listing must have non-zero price")

            // Store the calculated sale price
            self.price = price
        }
    }

    /// ListingPublic
    /// An interface providing a useful public interface to a Listing.
    ///
    pub resource interface ListingPublic {
        /// borrowNFT
        /// This will assert in the same way as the NFT standard borrowNFT()
        /// if the NFT is absent, for example if it has been sold via another listing.
        ///
        pub fun borrowNFT(): &NonFungibleToken.NFT?

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        pub fun purchase(payment: @FungibleToken.Vault): @NonFungibleToken.NFT

        /// getDetails
        /// Fetches the details of the listing.
        pub fun getDetails(): ListingDetails
    }

    /// Listing
    /// A resource that allows an NFT to be sold for an amount of a given FungibleToken,
    /// and for the proceeds of that sale to be split between several recipients.
    /// 
    pub resource Listing: ListingPublic {
        /// The simple (non-Capability, non-complex) details of the sale
        access(self) let details: ListingDetails

        /// A capability allowing this resource to withdraw the NFT with the given ID from its collection.
        /// This capability allows the resource to withdraw *any* NFT, so you should be careful when giving
        /// such a capability to a resource and always check its code to make sure it will use it in the
        /// way that it claims.
        access(contract) let nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        /// borrowNFT
        /// Return the reference of the NFT that is listed for sale.
        /// if the NFT is absent, for example if it has been sold via another listing.
        /// it will return nil.
        ///
        pub fun borrowNFT(): &NonFungibleToken.NFT? {
            let ref = self.nftProviderCapability.borrow()!.borrowNFT(id: self.details.nftID)
            if ref.isInstance(self.details.nftType) && ref.id == self.details.nftID {
                return ref as! &NonFungibleToken.NFT  
            } 
            return nil
        }

        /// getDetails
        /// Get the details of listing.
        ///
        pub fun getDetails(): ListingDetails {
            return self.details
        }

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and commission to the facilitator and returns extra token to the buyer.
        /// This also cleans up duplicate listings for the item being purchased.
        pub fun purchase(payment: @FungibleToken.Vault): @NonFungibleToken.NFT {

            pre {
                self.details.purchased == false: "listing has already been purchased"
                payment.isInstance(self.details.paymentVaultType): "payment vault is not requested fungible token"
                payment.balance == self.details.price: "payment vault does not contain requested price"
                self.details.expiry > UInt64(getCurrentBlock().timestamp): "Listing is expired"
                self.owner != nil : "Resource doesn't have the assigned owner"
            }
            // Make sure the listing cannot be purchased again.
            self.details.setPurchased() 

            // Handle payments 
            for cut in self.details.saleCuts {
                if !cut.receiver.check() { panic("Given recipient has not authorised to receive the payment") }
                let recipient = cut.receiver.borrow() ?? panic("Unable to borrow the recipent capability")
                let p <- payment.withdraw(amount: cut.amount)
                recipient.deposit(from: <- p)
            }

            // Fetch the token to return to the purchaser.
            let nft <- self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
            // Neither receivers nor providers are trustworthy, they must implement the correct
            // interface but beyond complying with its pre/post conditions they are not gauranteed
            // to implement the functionality behind the interface in any given way.
            // Therefore we cannot trust the Collection resource behind the interface,
            // and we must check the NFT resource it gives us to make sure that it is the correct one.
            assert(nft.isInstance(self.details.nftType), message: "withdrawn NFT is not of specified type")
            assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")

            // Get rid of the payment - hope its empty :-D 
            assert(payment.balance == UFix64(0.0), message: "Payment was not completly withdrawn")
            destroy payment

            emit ListingCompleted(
                id: self.details.id,
                nftID: self.details.nftID,
                nftType: self.details.nftType,
                paymentVaultType: self.details.paymentVaultType,
                price: self.details.price,
                expiry: self.details.expiry,
                purchased: self.details.purchased
            )
            // Tranfer token
            return <- nft
        }

        /// destructor
        ///
        destroy () {
            // If the listing has not been purchased, we regard it as completed here.
            // Otherwise we regard it as completed in purchase().
            // This is because we destroy the listing in Storefront.removeListing()
            // or Storefront.cleanup() .
            // If we change this destructor, revisit those functions.

            if !self.details.purchased {
                emit ListingCompleted(
                    id: self.details.id,
                    nftID: self.details.nftID,
                    nftType: self.details.nftType,
                    paymentVaultType: self.details.paymentVaultType,
                    price: self.details.price,
                    expiry: self.details.expiry,
                    purchased: self.details.purchased
                )
            }
        }

        /// initializer
        ///
        init (
            id: UInt64,
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftID: UInt64,
            nftType: Type,
            paymentVaultType: Type,
            saleCuts: [SaleCut],
            expiry: UInt64
        ) {
            // Store the NFT provider
            self.nftProviderCapability = nftProviderCapability

            // Check that the provider contains the NFT.
            // We will check it again when the token is sold.
            // We cannot move this into a function because initializers cannot call member functions.
            let provider = self.nftProviderCapability.borrow()
            assert(provider != nil, message: "cannot borrow nftProviderCapability")

            // This will precondition assert if the token is not available.
            let nft: &NonFungibleToken.NFT = provider!.borrowNFT(id: nftID) 
            assert(nft.isInstance(nftType), message: "token is not of specified type")
            assert(nft.id == nftID, message: "token does not have specified ID")

            // This is the netto price for the item provided by the seller.
            var currentPrice = UFix64(0)
            for cut in saleCuts {
                currentPrice = currentPrice + cut.amount 
            }

            var totalPrice: [SaleCut] = []

            // Add initial minter fee 
            if let capability = self.nftProviderCapability as? Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}> {

                let capabilityb = capability.borrow() ?? panic("Unable to borrow provider capability")
                let resolver = capabilityb.borrowViewResolver(id: nftID)
                let traitsView = resolver.resolveView(Type<MetadataViews.Traits>()) as! MetadataViews.Traits? ?? panic("Unable to access metadata")

                for trait in traitsView.traits {
                    if (trait.name == "minter") {
                        totalPrice.append(SaleCut(
                            receiver: getAccount(trait.value as! Address).getCapability<&{FungibleToken.Receiver}>(MemeToken.ReceiverPublicPath)!,
                            amount: currentPrice * MarketplaceFees.getFeeParameters().rate,
                            description: "minter"
                        ))
                    }
                }
            } else {
                panic("Unable to obtain metadata resolver")
            }

            // Add marketplace fee
            totalPrice.append(SaleCut(
                receiver: MarketplaceFees.getFeeParameters().receiverCapability,
                amount: currentPrice * MarketplaceFees.getFeeParameters().rate,
                description: "marketplace"
            ))

            // Add seller asking price.
            for cut in saleCuts {
                totalPrice.append(NFTStorefront.SaleCut(
                    receiver: cut.receiver,
                    amount: cut.amount * (UFix64(1.0) - MarketplaceFees.getFeeParameters().rate - MarketplaceFees.getFeeParameters().rate),
                    description: cut.description
                ))
            }

            // Try to get the total price first 
            var price = UFix64(0)
            for cut in totalPrice {
                price = price + cut.amount 
            }

            // Store the sale information
            self.details = ListingDetails(
                id: id,
                nftID: nftID,
                nftType: nftType,
                paymentVaultType: paymentVaultType,
                saleCuts: totalPrice,
                expiry: expiry
            )
        }
    }

    /// StorefrontManager
    /// An interface for adding and removing Listings within a Storefront,
    /// intended for use by the Storefront's owner
    ///
    pub resource interface StorefrontManager {
        /// createListing
        /// Allows the Storefront owner to create and insert Listings.
        ///
        pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftID: UInt64,
            nftType: Type,
            paymentVaultType: Type,
            saleCuts: [SaleCut],
            expiry: UInt64
        ): UInt64

        /// removeListing
        /// Allows the Storefront owner to remove any sale listing, acepted or not.
        ///
        pub fun removeListing(id: UInt64)
    }

    /// StorefrontPublic
    /// An interface to allow listing and borrowing Listings, and purchasing items via Listings
    /// in a Storefront.
    ///
    pub resource interface StorefrontPublic {
        pub fun getListingIDs(): [UInt64]
        pub fun borrowListing(id: UInt64): &Listing{ListingPublic}?
        pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64)
        access(contract) fun cleanup(id: UInt64)
        pub fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64]
        pub fun cleanupPurchasedListings(id: UInt64)
    }

    /// Storefront
    /// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
    /// in order to query their details and purchase the NFTs that they represent.
    ///
    pub resource Storefront : StorefrontManager, StorefrontPublic {

        /// The dictionary of storefront listing ids to listing resources.
        access(contract) var listings: @{UInt64: Listing}

        /// insert
        /// Create and publish a Listing for an NFT.
        ///
        pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftID: UInt64,
            nftType: Type,
            paymentVaultType: Type,
            saleCuts: [SaleCut],
            expiry: UInt64
        ): UInt64 {
            
            // let's ensure that the seller does indeed hold the NFT being listed
            let collectionRef = nftProviderCapability.borrow()
                ?? panic("Could not borrow reference to collection")
            let nftRef = collectionRef.borrowNFT(id: nftID)

            // Try to find duplicates in case of duplicate we panic
            for key in self.listings.keys {
                if self.listings[key]?.getDetails()?.nftID == nftID {
                    panic("Listing nft is already available")
                }
            }

            let currentIndex = NFTStorefront.currentIndex

            var listing <- create Listing(
                id: currentIndex,
                nftProviderCapability: nftProviderCapability,
                nftID: nftID,
                nftType: nftType,
                paymentVaultType: paymentVaultType,
                saleCuts: saleCuts,
                expiry: expiry
            )

            emit ListingAvailable(
                id: currentIndex,
                address: self.owner?.address!,
                nftID: nftID,
                nftType: nftType,
                paymentVaultType: paymentVaultType,
                price: listing.getDetails().price,
                expiry: expiry
            )

            // Swap old listing with new listing recently created
            let oldListing <- self.listings[NFTStorefront.currentIndex] <- listing
            destroy oldListing

            // Increase current index by one 
            NFTStorefront.currentIndex = NFTStorefront.currentIndex + UInt64(1)

            return currentIndex
        }
        
        /// removeListing
        /// Remove a Listing that has not yet been purchased from the collection and destroy it.
        /// It can only be executed by the StorefrontManager resource owner.
        ///
        pub fun removeListing(id: UInt64) {
            let listing <- self.listings.remove(key: id)
                ?? panic("missing Listing")
            let listingDetails = listing.getDetails()
            // This will emit a ListingCompleted event.
            destroy listing
        }

        /// getListingIDs
        /// Returns an array of the Listing resource IDs that are in the collection
        ///
        pub fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        /// getExistingListingIDs
        /// Returns an array of listing IDs of the given `nftType` and `nftID`.
        ///
        pub fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64] {

            var list: [UInt64] = []

            // try to find the listing id associated with the nftID
            for key in self.listings.keys {
                if self.listings[key]?.getDetails()?.nftID == nftID {
                    list.append(key)
                }
            }

            return list
        }

        /// cleanupExpiredListings
        /// Cleanup the expired listing by iterating over the provided range of indexes.
        ///
        pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64) {
            panic("Not implemented right now")
        } 

        /// borrowSaleItem
        /// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        ///
        pub fun borrowListing(id: UInt64): &Listing{ListingPublic}? {
             if self.listings[id] != nil {
                return &self.listings[id] as &Listing{ListingPublic}?
            } else {
                return nil
            }
        }

        /// cleanupPurchasedListings
        /// Allows anyone to remove already purchased listings.
        ///
        pub fun cleanupPurchasedListings(id: UInt64) {
            pre {
                self.listings[id] != nil: "could not find listing with given id"
                self.borrowListing(id: id)!.getDetails().purchased == true: "listing not purchased yet"
            }
            let listing <- self.listings.remove(key: id)!
            let listingDetails = listing.getDetails()

            destroy listing
        }

        /// cleanup
        /// Remove an listing, When given listing is duplicate or expired
        /// Only contract is allowed to execute it.
        ///
        access(contract) fun cleanup(id: UInt64) {
            panic("Not implemented right now")
        }

        /// destructor
        ///
        destroy () {
            destroy self.listings

            // Let event consumers know that this storefront will no longer exist
            emit StorefrontDestroyed()
        }

        /// constructor
        ///
        init (address: Address) {
            self.listings <- {}

            // Let event consumers know that this storefront exists
            emit StorefrontInitialized(address: address)
        }
    }

    /// NFTStorefront admin resource
    /// This resource is used to create a new storefront.
    pub resource Administrator {

        /// Create a new storefront
        pub fun createStorefront(for address: Address): @Storefront {
            return <-create Storefront(address: address)
        }
    }

    init () {
        self.FlowTokenVaultPublicPath = /public/flowTokenVault
        self.StorefrontPublicPath = /public/NFTStorefront
        self.StorefrontStoragePath = /storage/NFTStorefront
        self.StorefrontAdminStoragePath = /storage/NFTStorefrontAdministrator

        // Create a administrator resource and save it to the admin account storage
        let admin <- create Administrator()
        self.account.save(<-admin, to: self.StorefrontAdminStoragePath)

        self.currentIndex = UInt64(0)
    }
}
 