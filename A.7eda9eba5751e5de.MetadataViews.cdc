/**
This contract implements the metadata standard proposed
in FLIP-0636.
Ref: https://github.com/onflow/flow/blob/master/flips/20210916-nft-metadata.md
Structs and resources can implement one or more
metadata types, called views. Each view type represents
a different kind of metadata, such as a creator biography
or a JPEG image file.
*/

pub contract MetadataViews {
    pub resource interface Resolver {
        pub fun getViews(): [Type]
        pub fun resolveView(_ view: Type): AnyStruct?
    }

    pub resource interface ResolverCollection {
        pub fun borrowViewResolver(id: UInt64): &{Resolver}
        pub fun getIDs(): [UInt64]
    }

    pub struct Display {
        pub let id: UInt64
        pub let ipfsHash: String
        pub let name: String
        pub let description: String
        pub let nftType: String
        pub let nftTypeDescription: String
        pub let contentType: String
        pub let power: UFix64
        pub let rarity: UFix64

        init(
            id: UInt64,
            ipfsHash: String,
            name: String,
            description: String,
            nftType: String,
            nftTypeDescription: String,
            contentType: String,
            power: UFix64,
            rarity: UFix64
        ) {
            self.id=id
            self.ipfsHash=ipfsHash
            self.name=name
            self.description=description
            self.nftType=nftType
            self.nftTypeDescription=nftTypeDescription
            self.contentType=contentType
            self.power = power
            self.rarity = rarity
        }
    }
}