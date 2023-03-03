// Description

import MetadataViews from 0x1d7e57aa55817448
import TheFabricantMetadataViews from 0x7752ea736384322f
import CoCreatable from 0x7752ea736384322f

pub contract interface Revealable {

    // When an NFT is minted, its metadata is stored here
    access(contract) var nftMetadata: {UInt64: AnyStruct{RevealableMetadata}}

    pub fun getNftMetadatas(): {UInt64: AnyStruct{RevealableMetadata}}

    // Mutable-Template based NFT Metadata.
    // Each time a revealable NFT is minted, a RevealableMetadata is created
    // and saved into the nftMetadata dictionary. This represents the
    // bare minimum a RevealableMetadata should implement
    pub struct interface RevealableMetadata {

        //NOTE: totalSupply value of attached NFT, therefore edition number. 
        // nfts are currently stored under their id in the collection, so
        // this should be used as the key for the nftMetadata dictionary as well
        // for consistency.
        pub let id: UInt64 

        // NOTE: nftUuid is the uuid of the associated nft.
        pub let nftUuid: UInt64 // uuid of NFT
        
        // NOTE: Name of NFT. Will most likely be the last node in the collection value.
        // eg XXories Original.
        // Will be combined with the edition number on the application
        // Doesn't include the edition number.
        pub var name: String

        pub var description: String //Display
        // NOTE: Thumbnail, which is needed for the Display view, should be set using one of the
        // media properties
        //pub let thumbnail: String //Display

        pub let collection: String // Name of collection eg The Fabricant > Season 3 > Wholeland > XXories Originals

        // Stores the metadata associated with this particular creation
        // but is not part of a characteristic eg mainImage, video etc
        pub var metadata: {String: AnyStruct}

        //These are the characteristics that the 
        pub var characteristics: {String: {CoCreatable.Characteristic}}

        // The numerical score of the rarity
        pub var rarity: UFix64?
        // Legendary, Epic, Rare, Uncommon, Common or any other string value
        pub var rarityDescription: String?

        // NOTE: Media is not implemented in the struct because MetadataViews.Medias
        // is not mutable, so can't be updated. In addition, each 
        // NFT collection might have a different number of image/video properties.
        // Instead, the NFT should implement a function that rolls up the props
        // into a MetadataViews.Medias struct
        //pub let media: MetadataViews.Medias //Media

        //URL to the collection page on the website
        pub let externalURL: MetadataViews.ExternalURL //ExternalURL
        
        pub let coCreatable: Bool
        pub let coCreator: Address

        // Nil if can't be revealed, otherwise set to true when revealed
        pub var isRevealed: Bool?

        // id and editionNumber might not be the same in the nft...
        pub let editionNumber: UInt64 //Edition
        pub let maxEditionNumber: UInt64?

        pub let royalties: MetadataViews.Royalties //Royalty
        pub let royaltiesTFMarketplace: TheFabricantMetadataViews.Royalties

        access(contract) var revealableTraits: {String: Bool}

        pub fun getRevealableTraits(): {String: Bool}

        // Called by the Admin to reveal the traits for this NFT.
        // Should contain a switch function that knows how to modify
        // the properties of this struct. Should check that the trait
        // being revealed is allowed to be modified.
        access(contract) fun revealTraits(traits: [{RevealableTrait}])

        access(contract) fun updateMetadata(key: String, value: AnyStruct)

        // Called by the nft owner to modify if a trait can be 
        // revealed or not - used to revoke admin access
        pub fun updateIsTraitRevealable(key: String, value: Bool)

        pub fun checkRevealableTrait(traitName: String): Bool?

    }

    pub struct interface RevealableTrait {
        pub let name: String
        pub let value: AnyStruct
    }
}
 