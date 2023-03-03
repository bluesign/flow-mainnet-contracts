import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import TopShot from 0x0b2a3299cc857e29
import Resolver from 0xb8ea91944fd51c43

pub contract ResolverSubedition {
    pub enum ResolverType: UInt8 {
        pub case TopShotSubedition
    }
    pub resource OfferResolver: Resolver.ResolverPublic {
        pub fun checkOfferResolver(
         item: &AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver},
         offerParamsString: {String:String},
         offerParamsUInt64: {String:UInt64},
         offerParamsUFix64: {String:UFix64}): Bool {
            if offerParamsString["resolver"] == ResolverType.TopShotSubedition.rawValue.toString() {
                let view = item.resolveView(Type<TopShot.TopShotMomentMetadataView>())!
                let metadata = view as! TopShot.TopShotMomentMetadataView

                let offersSubeditionId = offerParamsString["subeditionId"]
                let nftsSubeditionId = TopShot.getMomentsSubedition(nftID: item.id)
                assert(offersSubeditionId!=nil, message: "subeditionId does not exist on Offer")
                assert(nftsSubeditionId!=nil, message: "subeditionId does not exist on NFT")

                if offerParamsString["playId"] == metadata.playID.toString() &&
                   offerParamsString["setId"] == metadata.setID.toString()  &&
                   offersSubeditionId! == nftsSubeditionId!.toString(){
                    return true
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