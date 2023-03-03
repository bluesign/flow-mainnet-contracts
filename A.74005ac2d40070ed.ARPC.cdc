import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleTokenMinter from 0x3b16cb9f5c036412

pub contract ARPC: NonFungibleToken, NonFungibleTokenMinter {
    pub var totalSupply: UInt64
    pub let mintedNfts: {UInt64: Bool};

    pub event ContractInitialized()
    pub event Minted(to: Address, id: UInt64, metadata: {String:String})
    pub event Mint(id: UInt64, metadata: {String:String})
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let metadata: {String:String}

        init(id: UInt64, metadata: {String:String}) {
            self.id = id
            self.metadata = metadata
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.metadata["name"] ?? "",
                        description: self.metadata["description"] ?? "",
                        thumbnail: MetadataViews.HTTPFile(url: self.metadata["metaURI"] ?? ""),
                    )
            }
            return nil
        }

        pub fun getMetadata(): {String:String} {
            return self.metadata
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowNFTARPC(id: UInt64): &ARPC.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ARPC reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @ARPC.NFT

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
 
        pub fun borrowNFTARPC(id: UInt64): &ARPC.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &ARPC.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let exampleNFT = nft as! &ARPC.NFT
            return (exampleNFT as &AnyResource{MetadataViews.Resolver}?)!
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
    pub resource NFTMinter: NonFungibleTokenMinter.MinterProvider {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}, metadata: {String: String}) {
            pre {
                ARPC.mintedNfts[id] == nil || ARPC.mintedNfts[id] == false:
                    "This id has been minted before"
            }
            // create a new NFT
            var newNFT <- create NFT(id: id, metadata: metadata)

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            ARPC.mintedNfts[id] = true

            ARPC.totalSupply = ARPC.totalSupply + 1

            emit Minted(to: recipient.owner!.address, id: id, metadata: metadata)
        }

        pub fun mint(id: UInt64, metadata: {String:String}): @NonFungibleToken.NFT {
            pre {
                ARPC.mintedNfts[id] == nil || ARPC.mintedNfts[id] == false:
                    "This id has been minted before"
            }
            ARPC.totalSupply = ARPC.totalSupply + 1
            let token <- create NFT(
                id: id,
                metadata: metadata
            )

            ARPC.mintedNfts[id] = true

            emit Mint(id: token.id, metadata: metadata)
            return <- token
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0
        self.mintedNfts = {}

        // Set the named paths
        self.CollectionStoragePath = /storage/ARPCStoragePath
        self.CollectionPublicPath = /public/ARPCPublicPath
        self.MinterStoragePath = /storage/ARPCMinterStoragePath

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&ARPC.Collection{NonFungibleToken.CollectionPublic, ARPC.CollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
