import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import TopShot from 0x0b2a3299cc857e29

pub contract Resolver {
    // Current list of supported resolution rules.
    pub enum ResolverType: UInt8 {
        pub case NFT
        pub case TopShotEdition
        pub case MetadataViewsEditions
    }

    // Public resource interface that defines a method signature for checkOfferResolver
    // which is used within the Resolver resource for offer acceptance validation
    pub resource interface ResolverPublic {
        pub fun checkOfferResolver(
         item: &AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver},
         offerParamsString: {String:String},
         offerParamsUInt64: {String:UInt64},
         offerParamsUFix64: {String:UFix64}): Bool
    }


    // Resolver resource holds the Offer exchange resolution rules.
    pub resource OfferResolver: ResolverPublic {
        // checkOfferResolver
        // Holds the validation rules for resolver each type of supported ResolverType
        // Function returns TRUE if the provided nft item passes the criteria for exchange
        pub fun checkOfferResolver(
         item: &AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver},
         offerParamsString: {String:String},
         offerParamsUInt64: {String:UInt64},
         offerParamsUFix64: {String:UFix64}): Bool {
            if offerParamsString["resolver"] == ResolverType.NFT.rawValue.toString() {
                assert(item.id.toString() == offerParamsString["nftId"], message: "item NFT does not have specified ID")
                return true
            } else if offerParamsString["resolver"] == ResolverType.TopShotEdition.rawValue.toString() {
                // // Get the Top Shot specific metadata for this NFT
                let view = item.resolveView(Type<TopShot.TopShotMomentMetadataView>())!
                let metadata = view as! TopShot.TopShotMomentMetadataView
                if offerParamsString["playId"] == metadata.playID.toString() && offerParamsString["setId"] == metadata.setID.toString() {
                    return true
                }
            } else if offerParamsString["resolver"] == ResolverType.MetadataViewsEditions.rawValue.toString() {
                if let views = item.resolveView(Type<MetadataViews.Editions>()) {
                    let editions = views as! [MetadataViews.Edition]
                    var hasCorrectMetadataView = false
                    for edition in editions {
                        if edition.name == offerParamsString["editionName"] {
                            hasCorrectMetadataView = true
                        }
                    }
                    assert(hasCorrectMetadataView == true, message: "editionId does not exist on NFT")
                    return true
                } else {
                    panic("NFT does not use MetadataViews.Editions")
                }
            } else {
                panic("Invalid Resolver on Offer")
            }

            return false
        }

    }

    pub fun createResolver(): @OfferResolver {
        return <-create OfferResolver()
    }
}