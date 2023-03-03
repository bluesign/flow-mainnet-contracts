import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DriverzInsurance from 0xf887ece39166906e
import DriverzAirdrop from 0xf887ece39166906e

pub contract DriverzInsuranceStorefront {
    
    pub event DriverzInsuranceStorefrontInitialized()
    pub event StorefrontInitialized(storefrontResourceID: UInt64)
    pub event StorefrontDestroyed(storefrontResourceID: UInt64)
    
    pub event ListingAvailable(
        storefrontAddress: Address,
        listingResourceID: UInt64,
        nftType: Type,
        nftID: UInt64,
        ftVaultType: Type,
        price: UFix64
    )

    pub event ListingCompleted(
        listingResourceID: UInt64, 
        storefrontResourceID: UInt64, 
        purchased: Bool,
        nftType: Type,
        nftID: UInt64
    )

    pub let StorefrontStoragePath: StoragePath
    pub let StorefrontPublicPath: PublicPath

    pub struct ListingDetails {

        pub var storefrontID: UInt64
        // Whether this listing has been purchased or not.
        pub var purchased: Bool
        // The Type of the NonFungibleToken.NFT that is being listed.
        pub let nftType: Type
        // The ID of the NFT within that type.
        pub let nftID: UInt64
        // The Type of the FungibleToken that payments must be made in.
        pub let salePaymentVaultType: Type
        // The amount that must be paid in the specified FungibleToken.
        pub let salePrice: UFix64

        pub let receiver: Capability<&{FungibleToken.Receiver}>

        pub let discount: UFix64?

        // setToPurchased
        // Irreversibly set this listing as purchased.
        //
        access(contract) fun setToPurchased() {
            self.purchased = true
        }

        // initializer
        //
        init (
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            storefrontID: UInt64,
            salePrice: UFix64,
            receiver: Capability<&{FungibleToken.Receiver}>,
            discount: UFix64?
        ) {
            self.storefrontID = storefrontID
            self.purchased = false
            self.nftType = nftType
            self.nftID = nftID
            self.salePaymentVaultType = salePaymentVaultType
            self.salePrice = salePrice
            self.receiver = receiver
            //Store the discounts
            self.discount = discount
        }
    }


    // ListingPublic
    // An interface providing a useful public interface to a Listing.
    //
    pub resource interface ListingPublic {
        // borrowNFT
        // This will assert in the same way as the NFT standard borrowNFT()
        // if the NFT is absent, for example if it has been sold via another listing.
        //
        pub fun borrowNFT(): &NonFungibleToken.NFT

        // purchase
        // Purchase the listing, buying the token.
        // This pays the beneficiaries and returns the token to the buyer.
        //
        pub fun purchase(payment: @FungibleToken.Vault, collection: &NonFungibleToken.Collection{NonFungibleToken.Receiver})

        // getDetails
        //
        pub fun getDetails(): ListingDetails

    }


    // Listing
    // A resource that allows an NFT to be sold for an amount of a given FungibleToken,
    // and for the proceeds of that sale to be split between several recipients.
    pub resource Listing: ListingPublic {
        // The simple (non-Capability, non-complex) details of the sale
        access(self) let details: ListingDetails

        access(contract) let nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        // borrowNFT
        // This will assert in the same way as the NFT standard borrowNFT()
        // if the NFT is absent, for example if it has been sold via another listing.
        pub fun borrowNFT(): &NonFungibleToken.NFT {
            let ref = self.nftProviderCapability.borrow()!.borrowNFT(id: self.getDetails().nftID)
            //- CANNOT DO THIS IN PRECONDITION: "member of restricted type is not accessible: isInstance"
            //  result.isInstance(self.getDetails().nftType): "token has wrong type"
            assert(ref.isInstance(self.getDetails().nftType), message: "token has wrong type")
            assert(ref.id == self.getDetails().nftID, message: "token has wrong ID")
            return (ref as &NonFungibleToken.NFT?)!
        }

        // getDetails
        // Get the details of the current state of the Listing as a struct.
        pub fun getDetails(): ListingDetails {
            return self.details
        }
        
        // Purchase the listing, buying the token.
        //The purchase function receives payment and capability from the collection to which the NFT is to be sent. 
        //This checks the user's address and determines whether they are entitled to a discount
        pub fun purchase(payment: @FungibleToken.Vault, collection: &NonFungibleToken.Collection{NonFungibleToken.Receiver}) {
            pre {
                self.details.purchased == false: "listing has already been purchased"
                payment.isInstance(self.details.salePaymentVaultType): "payment vault is not requested fungible token"
            }
            
            let buyerAddress: Address = collection.owner!.address
            var finalSalePrice: UFix64 = 0.0

            //Check if the account has a DriverzAirdrop collection. 
            //If so, check if there are Driverz in it. 
            //If account do not have driverz, the discount will not be applied.
            if(getAccount(buyerAddress).getCapability<&{DriverzAirdrop.CollectionPublic}>(DriverzAirdrop.CollectionPublicPath).borrow() != nil){
                let driverzCollection:&{DriverzAirdrop.CollectionPublic} = getAccount(buyerAddress).getCapability<&{DriverzAirdrop.CollectionPublic}>(DriverzAirdrop.CollectionPublicPath).borrow()!
                
                if(driverzCollection.getIDs().length > 0){
                    let discountAmount: UFix64 = self.details.discount != nil ? self.details.discount! : 0.0
                    finalSalePrice = self.details.salePrice - discountAmount
                } else {
                    finalSalePrice = self.details.salePrice
                }
            } else {
                finalSalePrice = self.details.salePrice
            }

            //Check if the payment is the same amount as the listed NFT amount price for this address
            if(payment.balance != finalSalePrice){
                panic("Payment vault does not contain requested price, Driverz owners = $80 and non-owners = $100")
            }

            // Fetch the token to return to the purchaser.
            let nft <-self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
            // Therefore we cannot trust the Collection resource behind the interface,
            // and we must check the NFT resource it gives us to make sure that it is the correct one.
            assert(nft.isInstance(self.details.nftType), message: "withdrawn NFT is not of specified type")
            assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")

            self.details.receiver.borrow()!.deposit(from: <-payment)

            self.details.setToPurchased()
            // If the listing is purchased, we regard it as completed here.
            // Otherwise we regard it as completed in the destructor.        
            emit ListingCompleted(
                listingResourceID: self.uuid,
                storefrontResourceID: self.details.storefrontID,
                purchased: self.details.purchased,
                nftType: self.details.nftType,
                nftID: self.details.nftID
            )

            collection.deposit(token: <-nft)
        }

        // destructor
        destroy () {
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

        // initializer
        init (
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            salePrice: UFix64,
            storefrontID: UInt64,
            receiver: Capability<&{FungibleToken.Receiver}>,
            discount: UFix64?
        ) {
            // Store the sale information
            self.details = ListingDetails(
                nftType: nftType,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                storefrontID: storefrontID,
                salePrice: salePrice,
                receiver: receiver,
                discount: discount
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

    // StorefrontManager
    // An interface for adding and removing Listings within a Storefront,
    // intended for use by the Storefront's own
    //
    pub resource interface StorefrontManager {
        // createListing
        // Allows the Storefront owner to create and insert Listings.
        //
        pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            receiver: Capability<&{FungibleToken.Receiver}>,
            salePaymentVaultType: Type,
            salePrice: UFix64,
            discount: UFix64?
        ): UInt64
        // removeListing
        // Allows the Storefront owner to remove any sale listing, acepted or not.
        //
        pub fun removeListing(listingResourceID: UInt64)
    }

    // StorefrontPublic
    // An interface to allow listing and borrowing Listings, and purchasing items via Listings
    // in a Storefront.
    //
    pub resource interface StorefrontPublic {
        pub fun getListingIDs(): [UInt64]
        pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
        pub fun cleanup(listingResourceID: UInt64)
   }

    // Storefront
    // A resource that allows its owner to manage a list of Listings, and anyone to interact with them
    // in order to query their details and purchase the NFTs that they represent.
    //
    pub resource Storefront : StorefrontManager, StorefrontPublic {
        // The dictionary of Listing uuids to Listing resources.
        access(self) var listings: @{UInt64: Listing}

        // insert
        // Create and publish a Listing for an NFT.
        //
         pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            receiver: Capability<&{FungibleToken.Receiver}>,
            salePaymentVaultType: Type,
            salePrice: UFix64,
            discount: UFix64?
         ): UInt64 {
            let listing <- create Listing(
                nftProviderCapability: nftProviderCapability,
                nftType: nftType,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                salePrice: salePrice,
                storefrontID: self.uuid,
                receiver: receiver,
                discount: discount
            )

            let listingResourceID = listing.uuid
            let listingPrice = listing.getDetails().salePrice

            // Add the new listing to the dictionary.
            let oldListing <- self.listings[listingResourceID] <- listing
            // Note that oldListing will always be nil, but we have to handle it.

            destroy oldListing

            emit ListingAvailable(
                storefrontAddress: self.owner?.address!,
                listingResourceID: listingResourceID,
                nftType: nftType,
                nftID: nftID,
                ftVaultType: salePaymentVaultType,
                price: listingPrice
            )

            return listingResourceID
        }
        

        // removeListing
        // Remove a Listing that has not yet been purchased from the collection and destroy it.
        //
        pub fun removeListing(listingResourceID: UInt64) {
            let listing <- self.listings.remove(key: listingResourceID)
                ?? panic("missing Listing")
    
            // This will emit a ListingCompleted event.
            destroy listing
        }

        // getListingIDs
        // Returns an array of the Listing resource IDs that are in the collection
        //
        pub fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        // borrowSaleItem
        // Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        //
        pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}? {
            if self.listings[listingResourceID] != nil {
                return (&self.listings[listingResourceID] as &Listing{ListingPublic}?)
            } else {
                return nil
            }
        }

        // cleanup
        // Remove an listing *if* it has been purchased.
        // Anyone can call, but at present it only benefits the account owner to do so.
        // Kind purchasers can however call it if they like.
        //
        pub fun cleanup(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "could not find listing with given id"
            }

            let listing <- self.listings.remove(key: listingResourceID)!
            assert(listing.getDetails().purchased == true, message: "listing is not purchased, only admin can remove")
            destroy listing
        }

        // destructor
        //
        destroy () {
            destroy self.listings

            // Let event consumers know that this storefront will no longer exist
            emit StorefrontDestroyed(storefrontResourceID: self.uuid)
        }

        // constructor
        //
        init () {
            self.listings <- {}

            // Let event consumers know that this storefront exists
            emit StorefrontInitialized(storefrontResourceID: self.uuid)
        }
    }

    // createStorefront
    // Make creating a Storefront publicly accessible.
    //
    pub fun createStorefront(): @Storefront {
        return <-create Storefront()
    }

    init () {
        self.StorefrontStoragePath = /storage/DriverzInsuranceStorefront
        self.StorefrontPublicPath = /public/DriverzInsuranceStorefront

        emit DriverzInsuranceStorefrontInitialized()
    }
}
 