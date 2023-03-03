import OffersV2 from 0xb8ea91944fd51c43
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import Resolver from 0xb8ea91944fd51c43

// DapperOffersV2
//
// Each account that wants to create offers for NFTs installs an DapperOffer
// resource and creates individual Offers for NFTs within it.
//
// The DapperOffer resource contains the methods to add, remove, borrow and
// get details on Offers contained within it.
//
pub contract DapperOffersV2 {
    // DapperOffersV2
    // This contract has been deployed.
    // Event consumers can now expect events from this contract.
    //
    pub event DapperOffersInitialized()

    /// DapperOfferInitialized
    // A DapperOffer resource has been created.
    //
    pub event DapperOfferInitialized(DapperOfferResourceId: UInt64)

    // DapperOfferDestroyed
    // A DapperOffer resource has been destroyed.
    // Event consumers can now stop processing events from this resource.
    //
    pub event DapperOfferDestroyed(DapperOfferResourceId: UInt64)


    // DapperOfferPublic
    // An interface providing a useful public interface to a Offer.
    //
    pub resource interface DapperOfferPublic {
        // getOfferIds
        // Get a list of Offer ids created by the resource.
        //
        pub fun getOfferIds(): [UInt64]
        // borrowOffer
        // Borrow an Offer to either accept the Offer or get details on the Offer.
        //
        pub fun borrowOffer(offerId: UInt64): &OffersV2.Offer{OffersV2.OfferPublic}?
        // cleanup
        // Remove an Offer
        //
        pub fun cleanup(offerId: UInt64)
        // addProxyCapability
        // Assign proxy capabilities (DapperOfferProxyManager) to an DapperOffer resource.
        //
        pub fun addProxyCapability(
            account: Address,
            cap: Capability<&DapperOffer{DapperOffersV2.DapperOfferProxyManager}>
        )
    }

    // DapperOfferManager
    // An interface providing a management interface for an DapperOffer resource.
    //
    pub resource interface DapperOfferManager {
        // createOffer
        // Allows the DapperOffer owner to create Offers.
        //
        pub fun createOffer(
            vaultRefCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
            nftReceiverCapability: Capability<&{NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            amount: UFix64,
            royalties: [OffersV2.Royalty],
            offerParamsString: {String:String},
            offerParamsUFix64: {String:UFix64},
            offerParamsUInt64: {String:UInt64},
            resolverCapability: Capability<&{Resolver.ResolverPublic}>,
        ): UInt64
        // removeOffer
        // Allows the DapperOffer owner to remove offers
        //
        pub fun removeOffer(offerId: UInt64)
    }

    // DapperOfferProxyManager
    // An interface providing removeOffer on behalf of an DapperOffer owner.
    //
    pub resource interface DapperOfferProxyManager {
        // removeOffer
        // Allows the DapperOffer owner to remove offers
        //
        pub fun removeOffer(offerId: UInt64)
        // removeOfferFromProxy
        // Allows the DapperOffer proxy owner to remove offers
        //
        pub fun removeOfferFromProxy(account: Address, offerId: UInt64)
    }


    // DapperOffer
    // A resource that allows its owner to manage a list of Offers, and anyone to interact with them
    // in order to query their details and accept the Offers for NFTs that they represent.
    //
    pub resource DapperOffer : DapperOfferManager, DapperOfferPublic, DapperOfferProxyManager {
        // The dictionary of Address to DapperOfferProxyManager capabilities.
        access(self) var removeOfferCapability: {Address:Capability<&DapperOffer{DapperOffersV2.DapperOfferProxyManager}>}
        // The dictionary of Offer uuids to Offer resources.
        access(self) var offers: @{UInt64:OffersV2.Offer}

        // addProxyCapability
        // Assign proxy capabilities (DapperOfferProxyManager) to an DapperOffer resource.
        //
        pub fun addProxyCapability(account: Address, cap: Capability<&DapperOffer{DapperOffersV2.DapperOfferProxyManager}>) {
            pre {
                cap.borrow() != nil: "Invalid admin capability"
            }
            self.removeOfferCapability[account] = cap
        }

        // removeOfferFromProxy
        // Allows the DapperOffer proxy owner to remove offers
        //
        pub fun removeOfferFromProxy(account: Address, offerId: UInt64) {
            pre {
                self.removeOfferCapability[account] != nil:
                    "Cannot remove offers until the token admin has deposited the account registration capability"
            }

            let adminRef = self.removeOfferCapability[account]!.borrow()!

            adminRef.removeOffer(offerId: offerId)
        }


        // createOffer
        // Allows the DapperOffer owner to create Offers.
        //
        pub fun createOffer(
            vaultRefCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
            nftReceiverCapability: Capability<&{NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            amount: UFix64,
            royalties: [OffersV2.Royalty],
            offerParamsString: {String:String},
            offerParamsUFix64: {String:UFix64},
            offerParamsUInt64: {String:UInt64},
            resolverCapability: Capability<&{Resolver.ResolverPublic}>,
        ): UInt64 {
            let offer <- OffersV2.makeOffer(
                vaultRefCapability: vaultRefCapability,
                nftReceiverCapability: nftReceiverCapability,
                nftType: nftType,
                amount: amount,
                royalties: royalties,
                offerParamsString: offerParamsString,
                offerParamsUFix64: offerParamsUFix64,
                offerParamsUInt64: offerParamsUInt64,
                resolverCapability: resolverCapability,
            )

            let offerId = offer.uuid
            let dummy <- self.offers[offerId] <- offer
            destroy dummy

            return offerId
        }

        // removeOffer
        // Remove an Offer that has not yet been accepted from the collection and destroy it.
        //
        pub fun removeOffer(offerId: UInt64) {
            destroy self.offers.remove(key: offerId) ?? panic("missing offer")
        }

        // getOfferIds
        // Returns an array of the Offer resource IDs that are in the collection
        //
        pub fun getOfferIds(): [UInt64] {
            return self.offers.keys
        }

        // borrowOffer
        // Returns a read-only view of the Offer for the given OfferID if it is contained by this collection.
        //
        pub fun borrowOffer(offerId: UInt64): &OffersV2.Offer{OffersV2.OfferPublic}? {
            if self.offers[offerId] != nil {
                return (&self.offers[offerId] as &OffersV2.Offer{OffersV2.OfferPublic}?)!
            } else {
                return nil
            }
        }

        // cleanup
        // Remove an Offer *if* it has been accepted.
        // Anyone can call, but at present it only benefits the account owner to do so.
        // Kind purchasers can however call it if they like.
        //
        pub fun cleanup(offerId: UInt64) {
            pre {
                self.offers[offerId] != nil: "could not find Offer with given id"
            }
            let offer <- self.offers.remove(key: offerId)!
            assert(offer.getDetails().purchased == true, message: "Offer is not purchased, only admin can remove")
            destroy offer
        }

        // constructor
        //
        init() {
            self.removeOfferCapability = {}
            self.offers <- {}
            // Let event consumers know that this storefront will no longer exist.
            emit DapperOfferInitialized(DapperOfferResourceId: self.uuid)
        }

        // destructor
        //
        destroy() {
            destroy self.offers
            // Let event consumers know that this storefront exists.
            emit DapperOfferDestroyed(DapperOfferResourceId: self.uuid)
        }
    }

    // createDapperOffer
    // Make creating an DapperOffer publicly accessible.
    //
    pub fun createDapperOffer(): @DapperOffer {
        return <-create DapperOffer()
    }

    pub let DapperOffersStoragePath: StoragePath
    pub let DapperOffersPublicPath: PublicPath

    init () {
        self.DapperOffersStoragePath = /storage/DapperOffersV2
        self.DapperOffersPublicPath = /public/DapperOffersV2

        emit DapperOffersInitialized()
    }
}
