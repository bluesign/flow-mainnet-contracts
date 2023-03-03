import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import CollecticoStandardNFT from 0x11cbef9729b236f3

/*
    Collectico Views for Basic NFTs
    (c) CollecticoLabs.com
 */
pub contract CollecticoStandardViews {

    pub resource interface NFTViewResolver {
        pub fun getViewType(): Type
        pub fun canResolveView(_ nft: &NonFungibleToken.NFT): Bool
        pub fun resolveView(_ nft: &NonFungibleToken.NFT): AnyStruct?
    }

    pub resource interface ItemViewResolver {
        pub fun getViewType(): Type
        pub fun canResolveView(_ item: &CollecticoStandardNFT.Item): Bool
        pub fun resolveView(_ item: &CollecticoStandardNFT.Item): AnyStruct?
    }

    pub struct ContractInfo {
        pub let name: String
        pub let address: Address
        init(
            name: String,
            address: Address
        ) {
            self.name = name
            self.address = address
        }
    }

    // A helper to get ContractInfo in a typesafe way
    pub fun getContractInfo(_ viewResolver: &{MetadataViews.Resolver}) : ContractInfo? {
        if let view = viewResolver.resolveView(Type<ContractInfo>()) {
            if let v = view as? ContractInfo {
                return v
            }
        }
        return nil
    }

    pub struct ItemView {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let thumbnail: AnyStruct{MetadataViews.File}
        pub let metadata: {String: AnyStruct}?
        pub let totalSupply: UInt64
        pub let maxSupply: UInt64?
        pub let isLocked: Bool
        pub let isTransferable: Bool
        pub let contractInfo: ContractInfo?
        pub let collectionDisplay: MetadataViews.NFTCollectionDisplay?
        pub let royalties: MetadataViews.Royalties?
        pub let display: MetadataViews.Display?
        pub let traits: MetadataViews.Traits?
        pub let medias: MetadataViews.Medias?
        pub let license: MetadataViews.License?
        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: AnyStruct{MetadataViews.File},
            metadata: {String: AnyStruct}?,
            totalSupply: UInt64,
            maxSupply: UInt64?,
            isLocked: Bool,
            isTransferable: Bool,
            contractInfo: ContractInfo?,
            collectionDisplay: MetadataViews.NFTCollectionDisplay?,
            royalties: MetadataViews.Royalties?,
            display: MetadataViews.Display?,
            traits: MetadataViews.Traits?,
            medias: MetadataViews.Medias?,
            license: MetadataViews.License?
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.metadata = metadata
            self.totalSupply = totalSupply
            self.maxSupply = maxSupply
            self.isLocked = isLocked
            self.isTransferable = isTransferable
            self.contractInfo = contractInfo
            self.collectionDisplay = collectionDisplay
            self.royalties = royalties
            self.display = display
            self.traits = traits
            self.medias = medias
            self.license = license
        }
    }

    // A helper to get ItemView in a typesafe way
    pub fun getItemView(_ viewResolver: &{MetadataViews.Resolver}) : ItemView? {
        if let view = viewResolver.resolveView(Type<ItemView>()) {
            if let v = view as? ItemView {
                return v
            }
        }
        return nil
    }

    pub struct NFTView {
        pub let id: UInt64
        pub let itemId: UInt64
        pub let itemName: String
        pub let itemDescription: String
        pub let itemThumbnail: AnyStruct{MetadataViews.File}
        pub let itemMetadata: {String: AnyStruct}?
        pub let serialNumber: UInt64
        pub let metadata: {String: AnyStruct}?
        pub let itemTotalSupply: UInt64
        pub let itemMaxSupply: UInt64?
        pub let isTransferable: Bool
        pub let contractInfo: ContractInfo?
        pub let collectionDisplay: MetadataViews.NFTCollectionDisplay?
        pub let royalties: MetadataViews.Royalties?
        pub let display: MetadataViews.Display?
        pub let traits: MetadataViews.Traits?
        pub let editions: MetadataViews.Editions?
        pub let medias: MetadataViews.Medias?
        pub let license: MetadataViews.License?
        init(
            id: UInt64,
            itemId: UInt64,
            itemName: String,
            itemDescription: String,
            itemThumbnail: AnyStruct{MetadataViews.File},
            itemMetadata: {String: AnyStruct}?,
            serialNumber: UInt64,
            metadata: {String: AnyStruct}?,
            itemTotalSupply: UInt64,
            itemMaxSupply: UInt64?,
            isTransferable: Bool,
            contractInfo: ContractInfo?,
            collectionDisplay: MetadataViews.NFTCollectionDisplay?,
            royalties: MetadataViews.Royalties?,
            display: MetadataViews.Display?,
            traits: MetadataViews.Traits?,
            editions: MetadataViews.Editions?,
            medias: MetadataViews.Medias?,
            license: MetadataViews.License?
        ) {
            self.id = id
            self.itemId = itemId
            self.itemName = itemName
            self.itemDescription = itemDescription
            self.itemThumbnail = itemThumbnail
            self.itemMetadata = itemMetadata
            self.serialNumber = serialNumber
            self.metadata = metadata
            self.itemTotalSupply = itemTotalSupply
            self.itemMaxSupply = itemMaxSupply
            self.isTransferable = isTransferable
            self.contractInfo = contractInfo
            self.collectionDisplay = collectionDisplay
            self.royalties = royalties
            self.display = display
            self.traits = traits
            self.editions = editions
            self.medias = medias
            self.license = license
        }
    }

    // A helper to get NFTView in a typesafe way
    pub fun getNFTView(_ viewResolver: &{MetadataViews.Resolver}) : NFTView? {
        if let view = viewResolver.resolveView(Type<NFTView>()) {
            if let v = view as? NFTView {
                return v
            }
        }
        return nil
    }
}