//--------MAINNET---------
import NonFungibleToken from 0x1d7e57aa55817448

/// OfferStoreFront
///
pub contract OfferStorefront {
   
    pub event OfferStorefrontInitialized()

    pub event StorefrontInitialized(storefrontResourceID: UInt64)

    pub event StorefrontDestroyed(storefrontResourceID: UInt64)

    pub event ListingAvailable(
        storefrontAddress: Address,
        listingResourceID: UInt64,
        nftType: Type,
        nftID: UInt64,
        walletClient: Address
    )

    pub event ListingCompleted(
        listingResourceID: UInt64, 
        storefrontResourceID: UInt64, 
        purchased: Bool,
        nftType: Type,
        nftID: UInt64
    )

    /// StorefrontStoragePath
    pub let StorefrontStoragePath: StoragePath

    /// StorefrontPublicPath
    pub let StorefrontPublicPath: PublicPath



    /// ListingDetails
    /// A struct containing a Listing's data.
    ///
    pub struct ListingDetails {

        pub var storefrontID: UInt64
        /// Whether this listing has been purchased or not.
        pub var purchased: Bool
        /// The Type of the NonFungibleToken.NFT that is being listed.
        pub let nftType: Type
        /// The ID of the NFT within that type.
        pub let nftID: UInt64
        // The wallet client address.
        pub let walletClient: Address

        /// setToPurchased
        /// Irreversibly set this listing as purchased.
        ///
        access(contract) fun setToPurchased() {
            self.purchased = true
        }

        /// initializer
        ///
        init (
            nftType: Type,
            nftID: UInt64,
            walletClient : Address,
            //salePaymentVaultType: Type,
            //saleCuts: [SaleCut],
            storefrontID: UInt64
        ) {
            self.storefrontID = storefrontID
            self.purchased = false
            self.nftType = nftType
            self.nftID = nftID
            self.walletClient = walletClient
   
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
        pub fun borrowNFT(): &NonFungibleToken.NFT

        /// purchase
        /// Purchase the listing, buying the token.
        ///
        pub fun purchase(wallet: Capability<&{NonFungibleToken.Receiver}>): @NonFungibleToken.NFT

        /// getDetails
        ///
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
        /// This will assert in the same way as the NFT standard borrowNFT()
        /// if the NFT is absent, for example if it has been sold via another listing.
        ///
        pub fun borrowNFT(): &NonFungibleToken.NFT {
            let ref = self.nftProviderCapability.borrow()!.borrowNFT(id: self.getDetails().nftID)
            //- CANNOT DO THIS IN PRECONDITION: "member of restricted type is not accessible: isInstance"
            //  result.isInstance(self.getDetails().nftType): "token has wrong type"
            assert(ref.isInstance(self.getDetails().nftType), message: "token has wrong type")
            assert(ref.id == self.getDetails().nftID, message: "token has wrong ID")
            return (ref as &NonFungibleToken.NFT?)!
        }

        /// getDetails
        /// Get the details of the current state of the Listing as a struct.
        /// This avoids having more public variables and getter methods for them, and plays
        /// nicely with scripts (which cannot return resources). 
        ///
        pub fun getDetails(): ListingDetails {
            return self.details
        }
        
        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        pub fun purchase(wallet: Capability<&{NonFungibleToken.Receiver}>): @NonFungibleToken.NFT {
            pre {
                self.details.purchased == false: "listing has already been purchased"
                self.details.walletClient == wallet.address: "wallet address is wrong"
                //payment.isInstance(self.details.salePaymentVaultType): "payment vault is not requested fungible token"
                //payment.balance == self.details.salePrice: "payment vault does not contain requested price"
            }

            // Make sure the listing cannot be purchased again.
            self.details.setToPurchased()


            // Fetch the token to return to the purchaser.
            let nft <-self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
            // Neither receivers nor providers are trustworthy, they must implement the correct
            // interface but beyond complying with its pre/post conditions they are not gauranteed
            // to implement the functionality behind the interface in any given way.
            // Therefore we cannot trust the Collection resource behind the interface,
            // and we must check the NFT resource it gives us to make sure that it is the correct one.
            assert(nft.isInstance(self.details.nftType), message: "withdrawn NFT is not of specified type")
            assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")       

            emit ListingCompleted(
                listingResourceID: self.uuid,
                storefrontResourceID: self.details.storefrontID,
                purchased: self.details.purchased,
                nftType: self.details.nftType,
                nftID: self.details.nftID
            )

            return <-nft
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
                    listingResourceID: self.uuid,
                    storefrontResourceID: self.details.storefrontID,
                    purchased: self.details.purchased,
                    nftType: self.details.nftType,
                    nftID: self.details.nftID
                )
            }
        }

        /// initializer
        ///
        init (
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            walletClient: Address,
            storefrontID: UInt64
        ) {
            // Store the sale information
            self.details = ListingDetails(
                nftType: nftType,
                nftID: nftID,
                walletClient: walletClient,
                storefrontID: storefrontID
            )

            // Store the NFT provider
            self.nftProviderCapability = nftProviderCapability

            // Check that the provider contains the NFT.
            // We will check it again when the token is sold.
            // We cannot move this into a function because initializers cannot call member functions.
            let provider = self.nftProviderCapability.borrow()
            assert(provider != nil, message: "cannot borrow nftProviderCapability")

            // This will precondition assert if the token is not available.
            let nft = provider!.borrowNFT(id: self.details.nftID)
            assert(nft.isInstance(self.details.nftType), message: "token is not of specified type")
            assert(nft.id == self.details.nftID, message: "token does not have specified ID")
        }
    }

    /// StorefrontManager
    /// An interface for adding and removing Listings within a Storefront,
    /// intended for use by the Storefront's own
    ///
    pub resource interface StorefrontManager {
        /// createListing
        /// Allows the Storefront owner to create and insert Listings.
        ///
        pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            walletClient: Address
        ): UInt64
        /// removeListing
        /// Allows the Storefront owner to remove any sale listing, acepted or not.
        ///
        pub fun removeListing(listingResourceID: UInt64)
    }

    /// StorefrontPublic
    /// An interface to allow listing and borrowing Listings, and purchasing items via Listings
    /// in a Storefront.
    ///
    pub resource interface StorefrontPublic {
        pub fun getListingIDs(): [UInt64]
        pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
        pub fun cleanup(listingResourceID: UInt64)
   }

    /// Storefront
    /// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
    /// in order to query their details and purchase the NFTs that they represent.
    ///
    pub resource Storefront : StorefrontManager, StorefrontPublic {
        /// The dictionary of Listing uuids to Listing resources.
        access(self) var listings: @{UInt64: Listing}

        /// insert
        /// Create and publish a Listing for an NFT.
        ///
         pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            walletClient:Address
         ): UInt64 {
            let listing <- create Listing(
                nftProviderCapability: nftProviderCapability,
                nftType: nftType,
                nftID: nftID,
                walletClient: walletClient,
                storefrontID: self.uuid
            )

            let listingResourceID = listing.uuid
            let listingWalletAddress = listing.getDetails().walletClient

            // Add the new listing to the dictionary.
            let oldListing <- self.listings[listingResourceID] <- listing
            // Note that oldListing will always be nil, but we have to handle it.

            destroy oldListing

            emit ListingAvailable(
                storefrontAddress: self.owner?.address!,
                listingResourceID: listingResourceID,
                nftType: nftType,
                nftID: nftID,
                walletClient: listingWalletAddress
            )

            return listingResourceID
        }
        

        /// removeListing
        /// Remove a Listing that has not yet been purchased from the collection and destroy it.
        ///
        pub fun removeListing(listingResourceID: UInt64) {
            let listing <- self.listings.remove(key: listingResourceID)
                ?? panic("missing Listing")
    
            // This will emit a ListingCompleted event.
            destroy listing
        }

        /// getListingIDs
        /// Returns an array of the Listing resource IDs that are in the collection
        ///
        pub fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        /// borrowSaleItem
        /// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        ///
        pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}? {
            if self.listings[listingResourceID] != nil {
                return &self.listings[listingResourceID] as! &Listing{ListingPublic}?
            } else {
                return nil
            }
        }

        /// cleanup
        /// Remove an listing *if* it has been purchased.
        /// Anyone can call, but at present it only benefits the account owner to do so.
        /// Kind purchasers can however call it if they like.
        ///
        pub fun cleanup(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "could not find listing with given id"
            }

            let listing <- self.listings.remove(key: listingResourceID)!
            assert(listing.getDetails().purchased == true, message: "listing is not purchased, only admin can remove")
            destroy listing
        }

        /// destructor
        ///
        destroy () {
            destroy self.listings

            // Let event consumers know that this storefront will no longer exist
            emit StorefrontDestroyed(storefrontResourceID: self.uuid)
        }

        /// constructor
        ///
        init () {
            self.listings <- {}

            // Let event consumers know that this storefront exists
            emit StorefrontInitialized(storefrontResourceID: self.uuid)
        }
    }

    /// createStorefront
    /// Make creating a Storefront publicly accessible.
    ///
    pub fun createStorefront(): @Storefront {
        return <-create Storefront()
    }

    init () {
        self.StorefrontStoragePath = /storage/OfferStorefront
        self.StorefrontPublicPath = /public/OfferStorefront

        emit OfferStorefrontInitialized()
    }
}