import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Clock from 0xc73076dd06d3b5b6
import AdminToken from 0xc73076dd06d3b5b6

pub contract KissoNFT: NonFungibleToken {

    pub var totalSupply: UInt64
    access(contract) let seriesTotalSupply: {UInt64: UInt64}

    // represents line items, key of hash to line item record
    access(contract) let lineItemRecords: {String: LineItemRecord} 

    access(account) let artLibrary: {UInt64: Variants}

    pub struct Variants {
        pub let variants: {UInt64: Variant}

        pub fun addUpdateVariant(variantID: UInt64, variant: Variant) {
            self.variants.insert(key: variantID, variant)
        }

        pub fun removeVariant(variantID: UInt64) {
            self.variants.remove(key: variantID)
        }

        init() {
            self.variants = {}
        }
    }

    pub struct Variant {
        pub let thumbnailImg: String
        pub let thumbnailImgMimetype: String
        pub let ipfsCID: String // this is the IPFS CID
        pub let ipfsPath: String? // directory for IPFS 

        init(
            thumbnailImg: String,
            thumbnailImgMimetype: String,
            ipfsCID: String,
            ipfsPath: String?
        ) {
            self.thumbnailImg = thumbnailImg
            self.thumbnailImgMimetype = thumbnailImgMimetype
            self.ipfsCID = ipfsCID
            self.ipfsPath = ipfsPath
        }
    }

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    
    pub struct OrderInfo {
        pub let id: UInt64
        pub let created_at: UFix64
        pub let order_number: UInt64

        init(
            id: UInt64,
            created_at: UFix64,
            order_number: UInt64
        ) {
            self.id = id
            self.created_at = created_at
            self.order_number = order_number
        }
    }

    pub struct LineItemRecord {
        pub let timestamp: UFix64
        pub let nftID: UInt64
        pub let seriesID: UInt64
        pub let productID: UInt64
        pub let variantID: UInt64
        pub let name: String

        init(
            nftID: UInt64,
            seriesID: UInt64,
            productID: UInt64,
            variantID: UInt64,
            name: String
        ) {
            self.timestamp = Clock.getTime()
            self.nftID = nftID
            self.seriesID = seriesID
            self.productID = productID
            self.variantID = variantID
            self.name = name
        }
    }

    pub struct LineItemInfo {
        pub let id: UInt64
        pub let product_id: UInt64
        pub let name: String
        pub let title: String
        pub let variant_id: UInt64
        pub let variant_title: String
        pub let price: UInt64
        pub let currency: String
        pub let item_hash: String

        init(
            id: UInt64,
            product_id: UInt64,
            name: String,
            title: String,
            variant_id: UInt64,
            variant_title: String,
            price: UInt64,
            currency: String,
            item_hash: String
        ) {
            self.id = id
            self.product_id = product_id
            self.name = name
            self.title = title
            self.variant_id = variant_id
            self.variant_title = variant_title
            self.price = price
            self.currency = currency
            self.item_hash = item_hash
        }
    }



    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let seriesID: UInt64
        pub let weight: UInt64
        pub let miniThumbnail: String // a base64 encoded string
        pub let miniThumbnailMimetype: String // mimetype of the b64 encoded string


        pub let name: String
        pub let description: String
        pub let thumbnail: String // this is the IPFS CID for the main image
        pub let path: String? // path for the IPFS directory

        pub let orderInfo: OrderInfo
        pub let lineItemInfo: LineItemInfo

        access(self) let royalties: [MetadataViews.Royalty]

        init(
            id: UInt64,
            seriesID: UInt64,
            miniThumbnail: String,
            miniThumbnailMimetype: String,
            name: String,
            description: String,
            thumbnail: String, 
            path: String?,
            orderInfo: OrderInfo,
            lineItemInfo: LineItemInfo,
            lineItemVotingWeight: UInt64,
            royalties: [MetadataViews.Royalty]
        ) {
            self.id = id
            self.seriesID = seriesID
            self.weight = lineItemVotingWeight
            self.miniThumbnail = miniThumbnail
            self.miniThumbnailMimetype = miniThumbnailMimetype
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.path = path
            self.orderInfo = orderInfo
            self.lineItemInfo = lineItemInfo
            self.royalties = royalties
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.thumbnail,
                            path: self.path
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.seriesID
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://kissodao.com/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: KissoNFT.CollectionStoragePath,
                        publicPath: KissoNFT.CollectionPublicPath,
                        providerPath: /private/kissoNFTCollection,
                        publicCollection: Type<&KissoNFT.Collection{KissoNFT.KissoNFTCollectionPublic}>(),
                        publicLinkedType: Type<&KissoNFT.Collection{KissoNFT.KissoNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&KissoNFT.Collection{KissoNFT.KissoNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-KissoNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://www.kissodao.com/_next/image?url=%2F_next%2Fstatic%2Fmedia%2Fkisso.ca9af3bf.png&w=256&q=100"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Kisso DAO Collection",
                        description: "This is the official collection of Kisso DAO.",
                        externalURL: MetadataViews.ExternalURL("https://kissodao.com"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/kissodao")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    let metadata: {String: AnyStruct} = {}

                    let traitsView = MetadataViews.dictToTraits(dict: metadata, excludedNames: nil)

                    let supplyIDTrait = MetadataViews.Trait(name: "supplyID", value: self.id, displayType: "Number", rarity: nil)
                    traitsView.addTrait(supplyIDTrait)

                    let seriesIDTrait = MetadataViews.Trait(name: "seriesID", value: self.seriesID, displayType: "Number", rarity: nil)
                    traitsView.addTrait(seriesIDTrait)

                    let votingWeightTrait = MetadataViews.Trait(name: "votingWeight", value: self.weight, displayType: "Number", rarity: nil)
                    traitsView.addTrait(votingWeightTrait)
                    
                    return traitsView
            }
            return nil
        }
    }

    pub resource interface KissoNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowKissoNFT(id: UInt64): &KissoNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow KissoNFT reference: the ID of the returned reference is incorrect"
            }
        }
        pub fun getVotingWeights(): {UInt64: UInt64}
    }

    // TODO: this is redundant with the same method on the public interface
    pub resource interface KissoNFTCollectionPrivate {
        pub fun getVotingWeights(): {UInt64: UInt64}
    }

    pub resource Collection: KissoNFTCollectionPublic, KissoNFTCollectionPrivate, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // maps uuid to token voting weight for this collection
        pub var votingWeights: {UInt64: UInt64}

        init () {
            self.ownedNFTs <- {}
            self.votingWeights = {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            let uuid: UInt64 = token.uuid

            emit Withdraw(id: token.id, from: self.owner?.address)

            self.votingWeights.remove(key: uuid)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @KissoNFT.NFT

            let id: UInt64 = token.id
            let uuid: UInt64 = token.uuid

            self.votingWeights.insert(key: uuid, token.weight)

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun getVotingWeightsUUIDs(): [UInt64] {
            return self.votingWeights.keys
        }

        pub fun getVotingWeight(uuid: UInt64): UInt64? {
            return self.votingWeights[uuid]
        }

        // gets a collection's voting weights dict
        pub fun getVotingWeights(): {UInt64: UInt64} {
            return self.votingWeights
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowKissoNFT(id: UInt64): &KissoNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &KissoNFT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let kissoNFT = nft as! &KissoNFT.NFT
            return kissoNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun getTotalSupply(): UInt64 {
        return KissoNFT.totalSupply
    }

    pub fun getLineItemRecord(hash: String): KissoNFT.LineItemRecord? {
        return KissoNFT.lineItemRecords[hash]
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        // is a passive minter, only minting if the item hasn't been used for minting yet
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            lineItemHash: String,
            orderInfo: OrderInfo,
            lineItemInfo: LineItemInfo,
            lineItemVotingWeight: UInt64,
            royalties: [MetadataViews.Royalty]
        ) {
            pre {
                KissoNFT.artLibrary[lineItemInfo.product_id] != nil : "the product doesn't exist in the art library"
                KissoNFT.artLibrary[lineItemInfo.product_id]!.variants[lineItemInfo.variant_id] != nil : "the variant doesn't exist in for the product in the art library"
            }

            if (KissoNFT.lineItemRecords[lineItemHash] == nil) {

                let productID = lineItemInfo.product_id
                let variantID = lineItemInfo.variant_id
                if (KissoNFT.seriesTotalSupply[productID] == nil) {
                    KissoNFT.seriesTotalSupply.insert(key: productID, UInt64(0))
                } 

                // create a new NFT
                var newNFT <- create NFT(
                    id: KissoNFT.totalSupply,
                    seriesID: KissoNFT.seriesTotalSupply[productID]!,
                    miniThumbnail: KissoNFT.artLibrary[productID]!.variants[variantID]!.thumbnailImg,
                    miniThumbnailMimetype: KissoNFT.artLibrary[productID]!.variants[variantID]!.thumbnailImgMimetype,
                    name: name,
                    description: description,
                    thumbnail: KissoNFT.artLibrary[productID]!.variants[variantID]!.ipfsCID,
                    path: KissoNFT.artLibrary[productID]!.variants[variantID]!.ipfsPath,
                    orderInfo: orderInfo,
                    lineItemInfo: lineItemInfo,
                    lineItemVotingWeight: lineItemVotingWeight,
                    royalties: royalties
                )

                // deposit it in the recipient's account using their reference
                recipient.deposit(token: <-newNFT)

                // make a record of the mint for this hash
                KissoNFT.lineItemRecords.insert(key: lineItemHash, KissoNFT.LineItemRecord(
                    nftID: KissoNFT.totalSupply,
                    seriesID: KissoNFT.seriesTotalSupply[productID]!,
                    productID: productID,
                    variantID: variantID,
                    name: name
                    ))

                // increment the series id supply
                KissoNFT.seriesTotalSupply[productID] = KissoNFT.seriesTotalSupply[productID]! + UInt64(1)

                // increment the total supply
                KissoNFT.totalSupply = KissoNFT.totalSupply + UInt64(1)

            }

        }
    }

    pub fun addUpdateArtLibraryVariant(
        productID: UInt64, 
        variantID: UInt64, 
        thumbnailImg: String,
        thumbnailImgMimetype: String,
        ipfsCID: String, 
        ipfsPath: String?,
        ref: &AdminToken.Token?
    ) {
        AdminToken.checkAuthorizedAdmin(ref) // check for authorized admin

        if (KissoNFT.artLibrary[productID] == nil) {
            KissoNFT.artLibrary.insert(key: productID, KissoNFT.Variants())
        }
        KissoNFT.artLibrary[productID]!.addUpdateVariant(
            variantID: variantID,
            variant: KissoNFT.Variant(
                thumbnailImg: thumbnailImg,
                thumbnailImgMimetype: thumbnailImgMimetype,
                ipfsCID: ipfsCID,
                ipfsPath: ipfsPath
            )
        )
    }

    pub fun removeArtLibraryVariant(
        productID: UInt64, 
        variantID: UInt64, 
        ref: &AdminToken.Token?
    ) {
        pre {
            KissoNFT.artLibrary[productID] != nil : "product does not exist"
            KissoNFT.artLibrary[productID]!.variants[variantID] != nil : "variant does not exist"
        }

        AdminToken.checkAuthorizedAdmin(ref) // check for authorized admin

        KissoNFT.artLibrary[productID]!.removeVariant(variantID: variantID)
    }


    pub fun removeArtLibraryProduct(
        productID: UInt64, 
        ref: &AdminToken.Token?
    ) {
        pre {
            KissoNFT.artLibrary[productID] != nil : "product does not exist"
        }

        AdminToken.checkAuthorizedAdmin(ref) // check for authorized admin

        KissoNFT.artLibrary.remove(key: productID)
    }

    pub fun artLibraryItemExists(productID: UInt64, variantID: UInt64): Bool {
        if (KissoNFT.artLibrary[productID] == nil) {
            return false
        }

        if (KissoNFT.artLibrary[productID]!.variants[variantID] == nil) {
            return false
        } else {
            return true
        }
    }

    pub fun getArtLibraryItem(productID: UInt64, variantID: UInt64): KissoNFT.Variant? {

        if (KissoNFT.artLibrary[productID] == nil) {
            return nil
        }

        if (KissoNFT.artLibrary[productID]!.variants[variantID] == nil) {
            return nil
        }

        return KissoNFT.artLibrary[productID]!.variants[variantID]
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0
        self.seriesTotalSupply = {}
        self.lineItemRecords = {}
        self.artLibrary = {}

        // Set the named paths
        self.CollectionStoragePath = /storage/kissoNFTCollection
        self.CollectionPublicPath = /public/kissoNFTCollection
        self.MinterStoragePath = /storage/kissoNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        // create a public capability for the collection
        self.account.link<&KissoNFT.Collection{NonFungibleToken.CollectionPublic, KissoNFT.KissoNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
