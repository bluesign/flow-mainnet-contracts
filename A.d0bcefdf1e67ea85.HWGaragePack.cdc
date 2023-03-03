/*
*
*   This is an implemetation of a Flow Non-Fungible Token
*   It is not a part of the official standard but it is assumed to be
*   similar to how NFTs would implement the core functionality
*
*
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

pub contract HWGaragePack: NonFungibleToken {

    /* 
    *   NonFungibleToken Standard Events
    */

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    /* 
    *   Project Events
    */

    pub event Mint(id: UInt64)
    pub event Burn(id: UInt64)

    /* 
    *   Named Paths
    */

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    /* 
    *   NonFungibleToken Standard Fields
    */

    pub var totalSupply: UInt64

    /*
    *   Pack State Variables
    */

    pub var name: String

    access(self) var collectionMetadata: { String: String }
    access(self) let idToPackMetadata: { UInt64: PackMetadata }

    pub struct PackMetadata {
        pub let metadata: { String: String }

        init(metadata: { String: String }) {
            self.metadata = metadata
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let packID: UInt64
        pub let packEditionID: UInt64

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    var ipfsImage = MetadataViews.IPFSFile(cid: "No thumbnail cid set", path: "No thumbnail path set")
                    if (self.getMetadata().containsKey("thumbnailCID")){
                        ipfsImage = MetadataViews.IPFSFile(cid: self.getMetadata()["thumbnailCID"]!, path: self.getMetadata()["thumbnailPath"])
                    }
                    return MetadataViews.Display(
                        name: self.getMetadata()["name"] ?? "No name set",
                        description: self.getMetadata()["description"] ?? "No description set",
                        thumbnail: ipfsImage
                    )

                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("")

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: HWGaragePack.CollectionStoragePath,
                        publicPath: HWGaragePack.CollectionPublicPath,
                        providedPath: /private/HWGaragePackCollection,
                        publicCollection: Type<&HWGaragePack.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, HWGaragePack.PackCollectionPublic, MetadataViews.ResolverCollection}>(),
                        publicLinkedType: Type<&HWGaragePack.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, HWGaragePack.PackCollectionPublic, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&HWGaragePack.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, HWGaragePack.PackCollectionPublic, MetadataViews.ResolverCollection}>(),
                        createEmptyCollection: fun(): @NonFungibleToken.Collection {return <- HWGaragePack.createEmptyCollection()}
                    )
                
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let externalURL = MetadataViews.ExternalURL("")
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: ""),
                        mediaType: "image/png")
                    let bannerImage = MetadataViews.Media(file: MetadataViews.HTTPFile(url: ""), mediaType: "image/png")
                    let socialMap: {String: MetadataViews.ExternalURL} = {
                        "facebook": MetadataViews.ExternalURL(""),
                        "instagram": MetadataViews.ExternalURL(""),
                        "twitter": MetadataViews.ExternalURL("")
                    }
                    return MetadataViews.NFTCollectionDisplay(
                        name: "HWGaragePack",
                        description: "",
                        externalURL: externalURL,
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: socialMap
                        )
                case Type<MetadataViews.Royalties>(): return MetadataViews.Royalties([])
            }

            return nil
        }

        pub fun getMetadata(): {String: String} {
            if (HWGaragePack.idToPackMetadata[self.id] != nil){
                return HWGaragePack.idToPackMetadata[self.id]!.metadata
            } else {
                return {}
            }
        }

        init(id: UInt64, packID: UInt64, packEditionID: UInt64) {
            self.id = id
            self.packID = packID
            self.packEditionID = packEditionID
            emit Mint(id: self.id)
        }

        destroy() {
            emit Burn(id: self.id)
        }
    }

    pub resource interface PackCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowPack(id: UInt64): &HWGaragePack.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow HWGaragePack reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: PackCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @HWGaragePack.NFT
            let id: UInt64 = token.id
            self.ownedNFTs[id] <-! token
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowPack(id: UInt64): &HWGaragePack.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &HWGaragePack.NFT
            } else {
                return nil
            }
        }
    
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let nftPack = nft as! &HWGaragePack.NFT
            return nftPack as &AnyResource{MetadataViews.Resolver}
        }

        destroy () {
            destroy self.ownedNFTs
        }
    }

    /* 
    *   Admin Functions
    */
    access(account) fun setEditionMetadata(editionNumber: UInt64, metadata: {String: String}) {
        self.idToPackMetadata[editionNumber] = PackMetadata(metadata: metadata)
    }

    access(account) fun setCollectionMetadata(metadata: {String: String}) {
        self.collectionMetadata = metadata
    }

    access(account) fun mint(nftID: UInt64, packID: UInt64, packEditionID: UInt64): @NonFungibleToken.NFT {
        self.totalSupply = self.totalSupply + 1
        return <- create NFT(id: nftID, packID: packID, packEditionID: packEditionID)
    }

    /* 
    *   Public Functions
    */
    pub fun getTotalSupply(): UInt64 {
        return self.totalSupply
    }

    pub fun getName(): String {
        return self.name
    }

    pub fun getCollectionMetadata(): {String: String} {
        return self.collectionMetadata
    }

    pub fun getEditionMetadata(_ edition: UInt64): {String: String} {
        if ( self.idToPackMetadata[edition] != nil) {
            return self.idToPackMetadata[edition]!.metadata
        } else {
            return {}
        }
    }

    pub fun getMetadataLength(): Int {
            return self.idToPackMetadata.length
        }


    /* 
    *   NonFungibleToken Standard Functions
    */
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // initialize contract state variables
    init(){
        self.name = "HWGaragePack"
        self.totalSupply = 0

        self.collectionMetadata = {}
        self.idToPackMetadata = {}

        // set the named paths
        self.CollectionStoragePath = /storage/HWGaragePackCollection
        self.CollectionPublicPath = /public/HWGaragePackCollection

        emit ContractInitialized()   
    }

}
 