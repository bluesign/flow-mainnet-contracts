import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract SkyharborNFT: NonFungibleToken {

    pub var totalSupply: UInt64

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let name: String
        pub let thumbnail: String
        pub let description: String

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<String>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(), 
                Type<MetadataViews.ExternalURL>()
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
                                    path: ""
                                    ) 
                    )
                case Type<String>():
                    return self.name
                case Type<MetadataViews.Royalties>():
                    var royalties: [MetadataViews.Royalty] = []
                    return MetadataViews.Royalties(royalties)
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://www.skyharbor.app/")                    
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: SkyharborNFT.CollectionStoragePath,
                        publicPath: SkyharborNFT.CollectionPublicPath,
                        providerPath: /private/exampleNFTCollection,
                        publicCollection: Type<&SkyharborNFT.Collection{NonFungibleToken.CollectionPublic}>(),
                        publicLinkedType: Type<&SkyharborNFT.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&SkyharborNFT.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-SkyharborNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://www.skyharbor.app/images/logo-dark.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Skyharbor Collection",
                        description: "This collection is used to hold the NFT's that you create on Skyharbor.app",
                        externalURL: MetadataViews.ExternalURL("https://www.skyharbor.app"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
            }

            return nil
        }

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
        ) {
            self.id = id
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @SkyharborNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }        
                

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {            
            let ref = &self.ownedNFTs[id] as &NonFungibleToken.NFT?
            return ref!
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {           
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!       
            let exampleNFT = nft as! &SkyharborNFT.NFT            
            return exampleNFT as &AnyResource{MetadataViews.Resolver}
        }        

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }    

    pub fun mintNFTA(name: String, descriptions: String, thumbnails: String): @NFT {

        // create a new NFT
        var newNFT <- create NFT(
                id: SkyharborNFT.totalSupply,
                name: name,
                description: descriptions,
                thumbnail: thumbnails,
            )        

        // change the id so that each ID is unique
        SkyharborNFT.totalSupply = SkyharborNFT.totalSupply + (1 as UInt64)

        return <-newNFT
    }

    
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ) {
            // create a new NFT
            var newNFT <- create NFT(
                id: SkyharborNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            SkyharborNFT.totalSupply = SkyharborNFT.totalSupply + (1 as UInt64)
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/skyharborNFTCollection
        self.CollectionPublicPath = /public/skyharborNFTCollection
        self.MinterStoragePath = /storage/skyharborNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&SkyharborNFT.Collection{NonFungibleToken.CollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}