import MetadataViews from 0x1d7e57aa55817448
import TheFabricantMetadataViews from 0x7752ea736384322f
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract interface TheFabricantNFTStandard {

    access(contract) var nftIdsToOwner: {UInt64: Address}

    // -----------------------------------------------------------------------
    // NFT Interface
    // -----------------------------------------------------------------------
    // Season
    // Collection
    // metadata
    // standards
    // We should have a set of scripts and txs that work for all nfts
    // We want to be able to get the nftIdsToOwner
    // Must be user mintable and admin mintable

    // NOTE: The TFNFT interface describes the bare minimum that
    // a TF NFT should implement to be considered as such. It specifies
    // functions as opposed to properties to avoid being prescriptive.
    pub resource interface TFNFT {
        // NFT View
        // Display
        // Edition
        // Serial
        // Royalty
        // Media
        // License
        // ExternalURL
        // NFTCollectionData
        // NFTCollectionDisplay
        // Rarity
        // Trait

        // The id is likely to also be the edition number of the NFT in the collection
        pub let id: UInt64  

        // NOTE: name, description and collection are not included because they may be
        // derived from the RevealableMetadata.

        // NOTE: UUID is a property on all resources so a reserved keyword.
        //pub let uuid: UInt64 //Display, Serial, 
        
        access(contract) let collectionId: String

        // id and editionNumber might not be the same in the nft...
        access(contract) let editionNumber: UInt64 //Edition
        access(contract) let maxEditionNumber: UInt64?

        access(contract) let originalRecipient: Address

        access(contract) let license: MetadataViews.License? //License

        // NFTs have a name prop and an edition number prop.
        // the name prop is usually just the last node in the 
        // collection name eg XXories Original.
        // The edition number is the number the NFT is in the series.
        // getFullName() returns the name + editionNumber
        // eg XXories Original #4
        pub fun getFullName(): String

        pub fun getEditionName(): String
        
        pub fun getEditions(): MetadataViews.Editions

        // NOTE: Refer to Revealable interface. Each campaign might have a 
        // different number of images/videos for its nfts. Enforcing
        // MetadataViews.Medias in the nft would make it un-Revealable,
        // as .Medias is immutable. Thus, this function should be used
        // to collect the media assets into a .Medias struct.
        pub fun getMedias(): MetadataViews.Medias

        // Helper function for TF use to get images
        // {"mainImage": "imageURL", "imageTwo": "imageURL"}
        pub fun getImages(): {String: String} 
        pub fun getVideos(): {String: String}

        // NOTE: This returns the traits that will be shown in marketplaces,
        // on dApps etc. We don't have a traits property to afford
        // flexibility to the implementation. The implementor might
        // want to have a 'revealable' trait for example,
        // and MetadataViews.Traits is immutable so not compatible.
        pub fun getTraits(): MetadataViews.Traits? 

        // NOTE: Same as above, rarity might be revealed.
        pub fun getRarity(): MetadataViews.Rarity?

        pub fun getExternalRoyalties(): MetadataViews.Royalties

        pub fun getTFRoyalties(): TheFabricantMetadataViews.Royalties

        pub fun getDisplay(): MetadataViews.Display

        pub fun getCollectionData(): MetadataViews.NFTCollectionData

        pub fun getCollectionDisplay(): MetadataViews.NFTCollectionDisplay

        pub fun getNFTView(): MetadataViews.NFTView

        pub fun getViews(): [Type]

        pub fun resolveView(_ view: Type): AnyStruct?

    }

    pub resource interface TFRoyalties {
        pub let royalties: MetadataViews.Royalties //Royalty
        pub let royaltiesTFMarketplace: TheFabricantMetadataViews.Royalties
    }

    // Used to expose the public mint function so that users can mint
    pub resource interface TFNFTPublicMinter {

        pub fun getPublicMinterDetails(): {String: AnyStruct}
    }
}
 