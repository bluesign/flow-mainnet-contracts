import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

 pub contract SPORTCASTER: NonFungibleToken {

    pub event ContractInitialized()
   
    // Initialize the total supply
    pub var totalSupply: UInt64

    //total collection created
    pub var totalCollection: UInt64

     //link public of the collection
    pub var CollectionPublicPath: PublicPath

    //storagre of the collection
    pub let CollectionStoragePath : StoragePath

    //storage of SPORTCASTER User
    pub let MinterStoragePath: StoragePath
   
    /* withdraw event */
    pub event Withdraw(id: UInt64, from: Address?)
    /* Event that is issued when an NFT is deposited */
    pub event Deposit(id: UInt64, to: Address?)
    /* event that is emitted when a new collection is created */
    pub event NewCollection(collectionName: String, collectionID:UInt64)
    /* Event that is emitted when new NFT is created*/
    pub event NewNFTminted(name: String, id: UInt64)
    /* Event that returns how many IDs a collection has */ 
    pub event TotalsIDs(ids:[UInt64])
    
    /* ## ~~This is the contract where we manage the flow of our collections and NFTs~~  ## */

    /* 
    Through the contract you can find variables such as Metadata,
    which are no longer a name to refer to the attributes of our NFTs. 
    which could be the url where our images live
    */

    //In this section you will find our variables and fields for our NFTs and Collections
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    // The unique ID that each NFT has
        pub let id: UInt64

        access(self) var metadata : {String: AnyStruct}
        pub let name: String
        pub let description: String
        pub let thumbnail: String

        init(id : UInt64, name: String, metadata: {String:AnyStruct}, thumbnail: String, description: String) {
            self.id = id
            self.metadata = metadata
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
        }
        
        pub fun getMetadata(): {String: AnyStruct} {
        return self.metadata
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
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.thumbnail, 
                            path: "sm.png"
                        )
                    )
            }
            return nil
        }

    }

    // We define this interface purely as a way to allow users
    // They would use this to only expose getIDs
    // borrowGMDYNFT
    // and idExists fields in their Collection
    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun idExists(id: UInt64): Bool
        pub fun getRefNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowSPORTCASTERNFT(id: UInt64): &SPORTCASTER.NFT? {
            post {
                (result == nil) || (result?.id == id):
                "Cannot borrow NFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    // We define this interface simply as a way to allow users to
    // to create a banner of the collections with their Name and Metadata
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
        pub var metadata: {String: AnyStruct}

        pub var name: String

        init (name: String, metadata: {String: AnyStruct}) {
            self.ownedNFTs <- {}
            self.name = name
            self.metadata = metadata
        }

         /* Function to remove the NFt from the Collection */
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            // If the NFT isn't found, the transaction panics and reverts
            let exist = self.idExists(id: withdrawID)
            if exist == false {
                    panic("id NFT Not exist")
            }
           let token <- self.ownedNFTs.remove(key: withdrawID)!

             /* Emit event when a common user withdraws an NFT*/
            emit Withdraw(id:withdrawID, from: self.owner?.address)

           return <-token
        }

        /*Function to deposit a  NFT in the collection*/
        pub fun deposit(token: @NonFungibleToken.NFT) {

            let token <- token as! @SPORTCASTER.NFT

            let id: UInt64 = token.id
            let name : String = token.name
            
            self.ownedNFTs[token.id] <-! token
            
            emit NewNFTminted(name: name, id: id)
            emit Deposit(id: id, to: self.owner?.address )
        }

        //fun get IDs nft
        pub fun getIDs(): [UInt64] {

            emit TotalsIDs(ids: self.ownedNFTs.keys)
            
            return self.ownedNFTs.keys
        }

        /*Function get Ref NFT*/
        pub fun getRefNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        /*Function borrow NFT*/
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
           return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!  
        }
           /*Function borrow SPORTCASTER View NFT*/
        pub fun borrowSPORTCASTERNFT(id: UInt64): &SPORTCASTER.NFT? {
             let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &SPORTCASTER.NFT?
        }

        // fun to check if the NFT exists
        pub fun idExists(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }
        
        destroy () {
            destroy self.ownedNFTs
        }
    }


    // We define this interface simply as a way to allow users to
    // to add the first NFTs to an empty collection.
    pub resource interface NFTCollectionReceiver {
      pub fun mintNFT(collection: Capability<&SPORTCASTER.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>)
    }

    pub resource NFTTemplate: NFTCollectionReceiver {

        priv var metadata : {String: AnyStruct}
        // array NFT
        priv var collectionNFT : [UInt64]
        priv var counteriDs: [UInt64]
        pub let name : String
        pub let thumbnail:  String
        pub let description: String
 
        init(name: String,  metadata: {String: AnyStruct}, thumbnail: String, description: String,
         collection: Capability<&SPORTCASTER.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>) { 
            self.metadata = metadata
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
            self.collectionNFT = []
            self.counteriDs = []
            self.mintNFT(collection: collection)
        }

        pub fun mintNFT(collection: Capability<&SPORTCASTER.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>) {
            let collectionBorrow = collection.borrow() ?? panic("cannot borrow collection")
            SPORTCASTER.totalSupply = SPORTCASTER.totalSupply + 1
              let newNFT <- create NFT(id: SPORTCASTER.totalSupply, name: self.name, metadata: self.metadata, thumbnail: self.thumbnail, description: self.description)
            collectionBorrow.deposit(token: <- newNFT)
        }
    
    }

    pub resource NFTMinter {
         pub fun createNFTTemplate(name: String,
                                metadata: {String: AnyStruct}, thumbnail: String, 
                                description: String, 
                                collection: Capability<&SPORTCASTER.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>
                                ): @NFTTemplate {
        return <- create NFTTemplate(
            name: name, 
            metadata: metadata, 
            thumbnail: thumbnail,
            description:  description,
            collection: collection,
            )
        }

    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection(name: "", metadata: {})
    }

    pub fun createEmptyCollectionNFT(name: String, metadata: {String:AnyStruct}): @NonFungibleToken.Collection {
        var newID = SPORTCASTER.totalCollection + 1
        SPORTCASTER.totalCollection = newID
        emit NewCollection(collectionName: name, collectionID: SPORTCASTER.totalCollection)
        return <-  create Collection(name: name, metadata: metadata)
    }

    init() {

        // Initialize the total supply
        self.totalSupply = 0

        // Initialize the total collection
        self.totalCollection = 0

        self.MinterStoragePath = /storage/SPORTCASTERMinterV1

        self.CollectionPublicPath = /public/SPORTCASTERCollectionPublic

        self.CollectionStoragePath = /storage/SPORTCASTERNFTCollection

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<- minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 