import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract KeeprItems: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, name: String, imageUrl: String, thumbnailUrl: String, imageCid: String, thumbCid: String, docId: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupply
    // The total number of KeeprItems that have been minted
    //
    pub var totalSupply: UInt64
    
    // A Keepr Item as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let cid: String
        pub let path: String
        pub let thumbCid: String
        pub let thumbPath: String
        pub let cardBackCid: String?
        pub let cardBackPath: String?
        pub let name: String
        pub let description: String

        init(id: UInt64, cid: String, path: String, thumbCid: String, thumbPath: String, name: String, description: String, cardBackCid: String, cardBackPath: String) {
            self.id = id
            self.cid = cid
            self.path = path
            self.thumbCid = thumbCid
            self.thumbPath = thumbPath
            self.name = name
            self.description = description
            self.cardBackCid = cardBackCid
            self.cardBackPath = cardBackPath
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
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.thumbCid, 
                            path: self.thumbPath
                        )
                    )
                case Type<MetadataViews.IPFSFile>():
                    return MetadataViews.IPFSFile(
                        cid: self.cid, 
                        path: self.path
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "KittyItems NFT Edition", number: self.id, max: nil)
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
                        []
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://keepr.gg/nftdirect/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: KeeprItems.CollectionStoragePath,
                        publicPath: KeeprItems.CollectionPublicPath,
                        providerPath: /private/KittyItemsCollection,
                        publicCollection: Type<&KeeprItems.Collection{KeeprItems.KeeprItemsCollectionPublic}>(),
                        publicLinkedType: Type<&KeeprItems.Collection{KeeprItems.KeeprItemsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&KeeprItems.Collection{KeeprItems.KeeprItemsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-KeeprItems.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://firebasestorage.googleapis.com/v0/b/keepr-86355.appspot.com/o/static%2Flogo-dark.svg?alt=media&token=9d66d7ea-9b3e-4fe0-8604-04df064af359"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Keepr Collection",
                        description: "This collection is used as an example to help you develop your next Flow NFT.",
                        externalURL: MetadataViews.ExternalURL("https://keepr.gg/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/keeprGG")
                        }
                    )

            }

            return nil
        }
    }

    // This is the interface that users can cast their KeeprItems Collection as
    // to allow others to deposit KeeprItems into their Collection. It also allows for reading
    // the details of KeeprItems in the Collection.
    pub resource interface KeeprItemsCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowKeeprItem(id: UInt64): &KeeprItems.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow KeeprItem reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of KeeprItem NFTs owned by an account
    //
    pub resource Collection: KeeprItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @KeeprItems.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowKeeprItem
        // Gets a reference to an NFT in the collection as a KeeprItem,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the KeeprItem.
        //
        pub fun borrowKeeprItem(id: UInt64): &KeeprItems.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &KeeprItems.NFT
            } else {
                return nil
            }
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let item = nft as! &KeeprItems.NFT
            return item as &AnyResource{MetadataViews.Resolver}
        }        

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        pub fun dwebURL(_ cid: String, _ path: String): String {
            var url = "https://"
                .concat(cid)
                .concat(".ipfs.dweb.link/")
            
            return url.concat(path)
        }

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}, 
            cid: String, 
            path: String, 
            thumbCid: String, 
            thumbPath: String, 
            name: String, 
            description: String,
            docId: String,
            cardBackCid: String,
            cardBackPath: String
        ) {
            // deposit it in the recipient's account using their reference
            let item <-create KeeprItems.NFT(id: KeeprItems.totalSupply, cid, path, thumbCid, thumbPath, name, description, cardBackCid, cardBackPath)
            
            emit Minted(
                id: KeeprItems.totalSupply,
                name: name,
                imageUrl: self.dwebURL(item.cid, item.path),
                thumbnailUrl: self.dwebURL(item.thumbCid, item.thumbPath),
                imageCid: cid,
                thumbCid: thumbCid,
                docId: docId
            )

            recipient.deposit(token: <-item)

            KeeprItems.totalSupply = KeeprItems.totalSupply + (1 as UInt64)
        }
    }

    // fetch
    // Get a reference to a KeeprItem from an account's Collection, if available.
    // If an account does not have a KeeprItems.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &KeeprItems.NFT? {
        let collection = getAccount(from)
            .getCapability(KeeprItems.CollectionPublicPath)!
            .borrow<&KeeprItems.Collection{KeeprItems.KeeprItemsCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust KeeprItems.Collection.borowKeeprItem to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowKeeprItem(id: itemID)
    }

    // initializer
    //
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/KeeprItemsCollectionV10
        self.CollectionPublicPath = /public/KeeprItemsCollectionV10
        self.MinterStoragePath = /storage/KeeprItemsMinterV10

        // Initialize the total supply
        self.totalSupply = 0

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 