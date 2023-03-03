import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30 : NonFungibleToken {

    pub var totalSupply: UInt64

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let MinterPublicPath: PublicPath
    //pub var CollectionPrivatePath: PrivatePath
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, creator: Address, metadata: {String:String})
    pub event Destroy(id: UInt64)

    // We use dict to store raw metadata
    pub resource interface RawMetadata {
        pub fun getRawMetadata(): {String: String}
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, RawMetadata {
        pub let id: UInt64
        pub let creator: Address
        access(self) let metadata: {String:String}

        init(
            id: UInt64,
            creator: Address,
            metadata: {String: String}
        ) {
            self.id = id
            self.creator = creator
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
                        name: self.metadata["name"]!,
                        description: self.metadata["description"]!,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata["thumbnail"]!
                        )
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

    pub resource interface Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowHexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30(id: UInt64): &Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow NFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
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
            let token <- token as! @Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.NFT

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

        pub fun borrowHexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30(id: UInt64): &Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.NFT?
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mlNFT = nft as! &Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.NFT
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

            let creator = self.owner!.address
            // create a new NFT
            var newNFT <- create NFT(
                id: Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.totalSupply,
                creator: creator,
                metadata: metadata
            )

            let tokenRef = &newNFT as &NonFungibleToken.NFT
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.totalSupply = Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.totalSupply + 1

            emit Mint(id: tokenRef.id, creator: creator, metadata: metadata)

            return tokenRef
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/MatrixMarketHexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30Collection
        self.CollectionPublicPath = /public/MatrixMarketHexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30Collection
        self.MinterStoragePath = /storage/MatrixMarketHexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30Minter
        self.MinterPublicPath = /public/MatrixMarketHexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30Minter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30.Hexi_Coll_04ae90b4_35a7_11ed_9411_4851c5d34c30CollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
