import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract MonoCat : NonFungibleToken {

    pub var totalSupply: UInt64

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let MinterPublicPath: PublicPath
    //pub var CollectionPrivatePath: PrivatePath
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, metadata: {String:String})
    pub event Destroy(id: UInt64)

    // We use dict to store raw metadata
    pub resource interface RawMetadata {
        pub fun getRawMetadata(): {String: String}
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, RawMetadata {
        pub let id: UInt64
        access(self) let metadata: {String:String}

        init(
            id: UInt64,
            metadata: {String: String}
        ) {
            self.id = id
            self.metadata = metadata
        }

       pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.ExternalURL>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                // Display view
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.metadata["name"]!,
                        description: self.metadata["description"]!,
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://arweave.net/".concat(self.metadata["image"]!)
                        )
                    )
                // royalties view
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([MetadataViews.Royalty(
                        receiver: getAccount(0xc7246d622d0db9f1).getCapability<&FungibleToken.Vault>(/public/flowTokenReceiver),
                        cut: 0.075,
                        description: "MonoCats Official"
                    )])
                
                // collection data view
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: MonoCat.CollectionStoragePath,
                        publicPath: MonoCat.CollectionPublicPath,
                        providerPath: /private/MonoCatCollection,
                        publicCollection: Type<&MonoCat.Collection{MonoCat.MonoCatCollectionPublic}>(),
                        publicLinkedType: Type<&MonoCat.Collection{MonoCat.MonoCatCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&MonoCat.Collection{MonoCat.MonoCatCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-MonoCat.createEmptyCollection()
                        })
                    )
                
                // external url view
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://monocats.xyz/mainpage")
                
                // collection display view
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://static.mono.fun/public/contents/projects/a73c1a41-be88-4c7c-a32e-929d453dbd39/nft/monocats/MonoCatSet_350x350.png"
                        ),
                        mediaType: "image/png"
                    )
                    let banner = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://static.mono.fun/public/contents/projects/a73c1a41-be88-4c7c-a32e-929d453dbd39/carousels/mono%20cats%20PC.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "MonoCats",
                        description: "Each NFT represent a MonoCats from the Meow Planets comes with unique design and utility.",
                        externalURL: MetadataViews.ExternalURL("https://monocats.xyz/mainpage"),
                        squareImage: media,
                        bannerImage: banner,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://monocats.xyz/twitter"),
                            "discord": MetadataViews.ExternalURL("https://monocats.xyz/discord"),
                            "instagram": MetadataViews.ExternalURL("https://monocats.xyz/instagram")
                        }
                    )
            }

            return nil
        }

        pub fun getRawMetadata(): {String: String} {
            return self.metadata
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface MonoCatCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMonoCat(id: UInt64): &MonoCat.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow NFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: MonoCatCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @MonoCat.NFT

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

        pub fun borrowMonoCat(id: UInt64): &MonoCat.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &MonoCat.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mlNFT = nft as! &MonoCat.NFT
            return mlNFT
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
            metadata: {String: String}
        ): &NonFungibleToken.NFT {

            assert(MonoCat.totalSupply + 1 <= 12500, message:"Mint would exceed max supply")

            // create a new NFT
            var newNFT <- create NFT(
                id: MonoCat.totalSupply,
                metadata: metadata
            )


            let tokenRef = &newNFT as &NonFungibleToken.NFT
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            MonoCat.totalSupply = MonoCat.totalSupply + 1

            emit Mint(id: tokenRef.id, metadata: metadata)

            return tokenRef
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/MonoCatCollection
        self.CollectionPublicPath = /public/MonoCatCollection
        self.MinterStoragePath = /storage/MonoCatMinter
        self.MinterPublicPath = /public/MonoCatMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&MonoCat.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MonoCat.MonoCatCollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
