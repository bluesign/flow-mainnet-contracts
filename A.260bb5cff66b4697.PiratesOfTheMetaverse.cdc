import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61

pub contract PiratesOfTheMetaverse: NonFungibleToken {

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let ClaimedPiratesPath: PublicPath

    // totalSupply
    pub var totalSupply: UInt64
    
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        priv let imageUrl: String
        access(self) let metadata: {String: String}

        init(id: UInt64, imageUrl: String, metadata: {String: String}) {
            self.id = id
            self.imageUrl = imageUrl
            self.metadata = metadata
        }

        pub fun name(): String {
            return "POTM #".concat(self.id.toString())
        }

        pub fun description(): String {
            return "Thrust into a strange future by tragedy and twist of fate, Ethero Caspain must rally a crew of degen pirates to help him locate the most coveted treasure in all the metaverse: a key rumored to unlock inter-dimensional travel.\n\nPirates of the Metaverse™ by Drip Studios is a collection of 10,000 digitally unique NFTs about to embark on an uncharted journey across blockchains."
        }

        pub fun imageCID(): String {
            return self.imageUrl
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.description(),
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.imageCID(),
                            path: nil
                        )
                    )
                case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits
                    return MetadataViews.dictToTraits(dict: self.metadata, excludedNames: nil)
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://www.piratesnft.io/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: PiratesOfTheMetaverse.CollectionStoragePath,
                        publicPath: PiratesOfTheMetaverse.CollectionPublicPath,
                        providerPath: /private/piratesOfTheMetaverseCollection,
                        publicCollection: Type<&PiratesOfTheMetaverse.Collection{PiratesOfTheMetaverse.PiratesOfTheMetaverseCollectionPublic}>(),
                        publicLinkedType: Type<&PiratesOfTheMetaverse.Collection{PiratesOfTheMetaverse.PiratesOfTheMetaverseCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&PiratesOfTheMetaverse.Collection{PiratesOfTheMetaverse.PiratesOfTheMetaverseCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-PiratesOfTheMetaverse.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let banner = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://potm-collection-images.s3.amazonaws.com/banner.jpeg"
                        ),
                        mediaType: "image/jpeg"
                    )
                    let square = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://potm-collection-images.s3.amazonaws.com/square.png"
                        ),
                        mediaType: "image/png"
                    )             
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Pirates Of The Metaverse",
                        description: self.description(),
                        externalURL: MetadataViews.ExternalURL("https://www.piratesnft.io/"),
                        squareImage: square,
                        bannerImage: banner,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/PiratesMeta")
                        }
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        [MetadataViews.Royalty(
                            reciever: getAccount(0xc97017ed85e496bf).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                            cut: 0.05,
                            description: "POTM royalties")
                        ]
                    )
            }

            return nil
        }
    }

    // This is the interface that users can cast their pirates Collection as
    // to allow others to deposit pirates into their Collection. It also allows for reading
    // the details of pirate in the Collection.
    pub resource interface PiratesOfTheMetaverseCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowPirate(id: UInt64): &PiratesOfTheMetaverse.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow pirate reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    //
    pub resource Collection: PiratesOfTheMetaverseCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @PiratesOfTheMetaverse.NFT

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

        // borrowPirate
        // Gets a reference to an NFT in the collection
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the pirate.
        //
        pub fun borrowPirate(id: UInt64): &PiratesOfTheMetaverse.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &PiratesOfTheMetaverse.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let pirate = nft as! &PiratesOfTheMetaverse.NFT
            return pirate as &AnyResource{MetadataViews.Resolver}
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
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

    pub resource interface  HasClaims {
        pub fun hasBeenClaimed(id: UInt64): Bool
    }

    pub resource NFTMinter: HasClaims {

        access(contract) var mintedAlready: {UInt64: Bool}

        init() {
            self.mintedAlready = {}
        }

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            id: UInt64,
            imageUrl: String,
            metadata: {String: String}
        ) {
            if self.mintedAlready.containsKey(id) {
                panic("Id has already been claimed!")
            }
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create PiratesOfTheMetaverse.NFT(id: id, imageUrl: imageUrl, metadata: metadata))
            self.mintedAlready.insert(key: id, true)

            emit Minted(id: id)
        }

        pub fun hasBeenClaimed(id: UInt64): Bool {
            return self.mintedAlready.containsKey(id)
        }

    }

    // fetch
    // Get a reference to a pirate from an account's Collection, if available.
    // If an account does not have a pirate.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &PiratesOfTheMetaverse.NFT? {
        let collection = getAccount(from)
            .getCapability(PiratesOfTheMetaverse.CollectionPublicPath)!
            .borrow<&PiratesOfTheMetaverse.Collection{PiratesOfTheMetaverse.PiratesOfTheMetaverseCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust pirate.Collection.borowPirate to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowPirate(id: itemID)
    }

    pub fun hasBeenClaimed(id: UInt64): Bool {
        let claimedPirates = self.account.getCapability<&{HasClaims}>(self.ClaimedPiratesPath)
        let claimedPiratesRef = claimedPirates.borrow()!
        return claimedPiratesRef.hasBeenClaimed(id: id)
    }

    // initializer
    //
    init() {

        // Set our named paths
        self.CollectionStoragePath = /storage/piratesOfTheMetaverseCollection
        self.CollectionPublicPath = /public/piratesOfTheMetaverseCollection
        self.MinterStoragePath = /storage/piratesOfTheMetaverseMinter
        self.ClaimedPiratesPath = /public/claimedPirates

        // Initialize the total supply
        self.totalSupply = 10000

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)
        self.account.link<&{HasClaims}>(self.ClaimedPiratesPath, target: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 