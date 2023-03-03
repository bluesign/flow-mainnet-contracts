import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract Bl0x2 : NonFungibleToken {

    pub var totalSupply: UInt64
    pub var nextID: UInt64
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath

    //pub var CollectionPrivatePath: PrivatePath
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, creator: Address, metadata: {String:String})
    pub event Destroy(id: UInt64)
    
    pub var baseURI: String
    pub var tokenData: {UInt64: AnyStruct}
    pub var extraFields: {String: AnyStruct}
    pub fun getTokenURI(id: UInt64): String {
        return self.baseURI.concat("/").concat(id.toString()) ;
    }
    
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
            return []
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }

        pub fun getRawMetadata(): {String: String} {
            return self.metadata
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface Bl0x2CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrow_NFT_NAME_(id: UInt64): &Bl0x2.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow NFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: Bl0x2CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
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
            let token <- token as! @Bl0x2.NFT

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

        pub fun borrow_NFT_NAME_(id: UInt64): &Bl0x2.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &Bl0x2.NFT?
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mlNFT = nft as! &Bl0x2.NFT
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

        // mintNFTWithID mints a new NFT with id
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFTWithID(
            id: UInt64,
            recipient: &{NonFungibleToken.CollectionPublic},
            metadata: {String: String}
        ): &NonFungibleToken.NFT {

            if(Bl0x2.nextID <= id){
                Bl0x2.nextID = id + 1
            }
            let creator = self.owner!.address
            // create a new NFT
            var newNFT <- create NFT(
                id: id,
                creator: creator,
                metadata: metadata
            )

            let tokenRef = &newNFT as &NonFungibleToken.NFT
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            Bl0x2.totalSupply = Bl0x2.totalSupply + 1

            emit Mint(id: tokenRef.id, creator: creator, metadata: metadata)

            return tokenRef
        }
        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            metadata: {String: String}
        ): &NonFungibleToken.NFT {

            let creator = self.owner!.address
            // create a new NFT
            var newNFT <- create NFT(
                id: Bl0x2.nextID,
                creator: creator,
                metadata: metadata
            )
            Bl0x2.nextID = Bl0x2.nextID + 1
            let tokenRef = &newNFT as &NonFungibleToken.NFT
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            Bl0x2.totalSupply = Bl0x2.totalSupply + 1

            emit Mint(id: tokenRef.id, creator: creator, metadata: metadata)

            return tokenRef
        }
    }
    
    pub resource Admin {
        pub fun setBaseURI(
            baseURI: String
        ){
            Bl0x2.baseURI = baseURI
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0
        self.nextID = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/MatrixMarketBl0x2Collection
        self.CollectionPublicPath = /public/MatrixMarketBl0x2Collection
        self.MinterStoragePath = /storage/MatrixMarketBl0x2Minter
        self.AdminStoragePath = /storage/MatrixMarketBl0x2Admin
        
        self.baseURI = "https://alpha.chainbase-api.matrixlabs.org/metadata/api/v1/apps/flow:testnet:1IEzdAr_iDJvek4-CE4-p/contracts/testnet_flow-A.7f3812b53dd4de20.Bl0x2/metadata/tokens"
        self.tokenData = {}
        self.extraFields = {}
        
        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&Bl0x2.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, Bl0x2.Bl0x2CollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)
        
        emit ContractInitialized()
    }
}
