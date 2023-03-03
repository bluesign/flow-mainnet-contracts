/* 
*
*  This is an example implementation of a Flow Non-Fungible Token
*  It is not part of the official standard but it assumed to be
*  similar to how many NFTs would implement the core functionality.
*
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract FlowtyTestNFT: NonFungibleToken {

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event CollectionCreated(id: UInt64)
    pub event CollectionDestroyed(id: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let MinterPublicPath: PublicPath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let data: {String: AnyStruct}
        access(self) let royalties: [MetadataViews.Royalty]

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
            self.data = {
                "name": name,
                "createdOn": getCurrentBlock().timestamp
            }
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
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
                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(name: "Flowty Test NFT Edition", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://flowty.io/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: FlowtyTestNFT.CollectionStoragePath,
                        publicPath: FlowtyTestNFT.CollectionPublicPath,
                        providerPath: /private/FlowtyTestNFTCollection,
                        publicCollection: Type<&FlowtyTestNFT.Collection{FlowtyTestNFT.FlowtyTestNFTCollectionPublic}>(),
                        publicLinkedType: Type<&FlowtyTestNFT.Collection{FlowtyTestNFT.FlowtyTestNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&FlowtyTestNFT.Collection{FlowtyTestNFT.FlowtyTestNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-FlowtyTestNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Flowty Test NFT Collection",
                        description: "This collection is used for testing things out on flowty.",
                        externalURL: MetadataViews.ExternalURL("https://flowty.io/"),
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"
                            ),
                            mediaType: "image/jpeg"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: "https://storage.googleapis.com/flowty-images/flowty-banner.jpeg"
                            ),
                            mediaType: "image/jpeg"
                        ),
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flowty_io")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    return MetadataViews.dictToTraits(dict: self.data, excludedNames: [])
            }
            return nil
        }
    }

    pub resource interface FlowtyTestNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFlowtyTestNFT(id: UInt64): &FlowtyTestNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FlowtyTestNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: FlowtyTestNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
            emit CollectionCreated(id: self.uuid)
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
            let token <- token as! @FlowtyTestNFT.NFT

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
 
        pub fun borrowFlowtyTestNFT(id: UInt64): &FlowtyTestNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FlowtyTestNFT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FlowtyTestNFT = nft as! &FlowtyTestNFT.NFT
            return FlowtyTestNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
            emit CollectionDestroyed(id: self.uuid)
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @FlowtyTestNFT.Collection {
        return <- (create Collection() as! @FlowtyTestNFT.Collection)
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
        ) {
            let royaltyRecipient = getAccount(FlowtyTestNFT.account.address).getCapability<&AnyResource{FungibleToken.Receiver}>(/public/placeholder)
            let cutInfo = MetadataViews.Royalty(receiver: royaltyRecipient, cut: 0.0, description: "")

            FlowtyTestNFT.totalSupply = FlowtyTestNFT.totalSupply + 1

            let thumbnail = "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"
            let name = "Flowty Test NFT #".concat(FlowtyTestNFT.totalSupply.toString())
            let description = "This nft is used for testing things out on flowty."

            // create a new NFT
            var newNFT <- create NFT(
                id: FlowtyTestNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: [cutInfo]
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/FlowtyTestNFTCollection
        self.CollectionPublicPath = /public/FlowtyTestNFTCollection
        self.MinterStoragePath = /storage/FlowtyTestNFTMinter
        self.MinterPublicPath = /public/FlowtyTestNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&FlowtyTestNFT.Collection{NonFungibleToken.CollectionPublic, FlowtyTestNFT.FlowtyTestNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)
        self.account.link<&FlowtyTestNFT.NFTMinter>(self.MinterPublicPath, target: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 