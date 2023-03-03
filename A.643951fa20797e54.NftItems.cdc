// This is an example implementation of a Flow Non-Fungible Token
// It is not part of the official standard but it assumed to be
// very similar to how many NFTs would implement the core functionality.

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
pub contract NftItems: NonFungibleToken {

    pub var totalSupply: UInt64

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64,name: String,description: String,thumbnail: String, metadataobjs: {UInt64: { String : String }},properties: {UInt64: { String : String }},cid:String,path:String?)
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
       
        pub let id: UInt64
        pub let name: String
        pub let thumbnail: String
        pub let description: String
        access(self) var metadataobjs: {UInt64: { String : String }}
        pub fun getMetadata(): {UInt64: { String : String }}{
         return self.metadataobjs
        }
        access(self) var properties: {UInt64: { String : String }}
        pub fun getProperties(): {UInt64: { String : String }}{
         return self.properties
        }
        pub let cid: String
        pub let path: String?

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.IPFSFile>(),
                Type<MetadataViews.NFTCollectionData>()

            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                   )
                case Type<MetadataViews.IPFSFile>():
                    return MetadataViews.IPFSFile(
                        cid: self.cid,
                        path: self.path
                    )
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: NftItems.CollectionStoragePath,
                        publicPath: NftItems.CollectionPublicPath,
                        providerPath: /private/nftItemsCollectionsV9,
                        publicCollection: Type<&NftItems.Collection{NftItems.NftItemsCollectionPublic}>(),
                        publicLinkedType: Type<&NftItems.Collection{NftItems.NftItemsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&NftItems.Collection{NftItems.NftItemsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-NftItems.createEmptyCollection()
                        })
                    )
            }

            return nil
        }
        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            initMetadataObjs: {UInt64: { String : String }},
            initProperties: {UInt64: { String : String }},
            cid: String,
            path:String?,
            
        ) { 
            self.id = id
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
            self.metadataobjs = initMetadataObjs
            self.properties= initProperties
            self.cid= cid
            self.path=path
        }
    }
    pub resource interface NftItemsCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowNftItems(id: UInt64): &NftItems.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow NftItems reference: the ID of the returned reference is incorrect"
            }
        }
    } 
    pub resource Collection: NftItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @NftItems.NFT

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
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowNftItems(id: UInt64): &NftItems.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &NftItems.NFT
            }

            return nil
        }
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let NftItems = nft as! &NftItems.NFT
            return NftItems as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
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
            metadataobjs:{UInt64: { String : String }},
            properties: {UInt64: { String : String }},
            cid: String,
            path:String?,
        ) {


            // deposit it in the recipient's account using their reference
         recipient.deposit(token: <-create NftItems.NFT(id: NftItems.totalSupply, name: name, description: description,thumbnail: thumbnail,initMetadataObjs: metadataobjs,initProperties:properties,cid:cid,path:path))


            emit Minted(
                id: NftItems.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                metadataobjs:metadataobjs,
                properties:properties,
                cid:cid,
                path:path,
            )

            NftItems.totalSupply = NftItems.totalSupply + (1 as UInt64)
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/nftItemsCollectionV9
        self.CollectionPublicPath = /public/nftItemsCollectionV9
        self.MinterStoragePath = /storage/nftItemsMinterV9
        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&NftItems.Collection{NonFungibleToken.CollectionPublic, NftItems.NftItemsCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
