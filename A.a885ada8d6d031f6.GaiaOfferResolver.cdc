import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Resolver from 0xb8ea91944fd51c43
import Wearables from 0xe81193c424cfd3fb

pub contract GaiaOfferResolver {
    pub enum ResolverType: UInt8 {
        pub case NFT
        pub case DoodlesWearableTemplate
    }

    pub resource OfferResolver: Resolver.ResolverPublic {
        pub fun checkOfferResolver(
            item: &AnyResource{NonFungibleToken.INFT, MetadataViews.Resolver},
            offerParamsString: {String:String},
            offerParamsUInt64: {String:UInt64},
            offerParamsUFix64: {String:UFix64}
        ): Bool {
            if offerParamsString["resolver"] == ResolverType.NFT.rawValue.toString() {
                assert(item.id.toString() == offerParamsString["nftId"], message: "item NFT does not have specified ID")
                return true
            } else if offerParamsString["resolver"] == ResolverType.DoodlesWearableTemplate.rawValue.toString() {
                // get the Doodles Wearable template for this NFT
                let view = item.resolveView(Type<Wearables.Metadata>())! as! Wearables.Metadata
                assert(view.templateId.toString() == offerParamsString["templateId"], message: "item NFT does not have specified templateId")
                return true
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
