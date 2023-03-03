import NonFungibleToken from 0x5cb714790301ed17 
import MetadataViews from 0x5cb714790301ed17
pub contract Ezy3dItems: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, 
                     TaskId: String, 
                     TaskName: String, 
                     ImgId: String,
                     TaskFrame: String,
                     TaskHolder: String,
                     TaskDetail: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupply
    // The total number of Ezy3dItems that have been minted
    //
    pub var totalSupply: UInt64


    // A Exy3d Item as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        // 作品ID
        pub let TaskId: String
        // 作品名称
        pub let TaskName: String
        // 缩略图片ID
        pub let ImgId: String
        // 作品帧数
        pub let TaskFrame :String
        // 作品持有者
        pub let TaskHolder: String
        // 作品详情
        pub let TaskDetail: String

        init(id: UInt64, 
            TaskId: String, 
            TaskName: String, 
            ImgId: String, 
            TaskFrame: String, 
            TaskHolder: String, 
            TaskDetail:String) 
        {
            self.id = id
            self.TaskId = TaskId
            self.TaskName = TaskName
            self.ImgId = ImgId
            self.TaskFrame = TaskFrame
            self.TaskHolder = TaskHolder
            self.TaskDetail = TaskDetail
        }

        pub fun description(): String {
            return "TaskId: "
                .concat(self.TaskId)
                .concat(" TaskName:")
                .concat(self.TaskName)
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
                        name: self.TaskName,
                        description: self.description(),
                        taskId: self.TaskId,
                        thumbnail: self.ImgId
                    )
            }

            return nil
        }
    }

    // This is the interface that users can cast their Ezy3dItems Collection as
    // to allow others to deposit Ezy3dItems into their Collection. It also allows for reading
    // the details of Ezy3dItems in the Collection.
    pub resource interface Ezy3dItemsCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowEzy3dItem(id: UInt64): &Ezy3dItems.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Ezy3dItem reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of Ezy3dItem NFTs owned by an account
    //
    pub resource Collection: Ezy3dItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @Ezy3dItems.NFT

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

        // borrowEzy3dItem
        // Gets a reference to an NFT in the collection as a Ezy3dItem,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the Ezy3dItem.
        //
        pub fun borrowEzy3dItem(id: UInt64): &Ezy3dItems.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Ezy3dItems.NFT
            } else {
                return nil
            }
        }
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let Ezy3dItem = nft as! &Ezy3dItems.NFT
            return Ezy3dItem as &AnyResource{MetadataViews.Resolver}
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
    pub resource NFTMinter {

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic}, 
            TaskId: String, 
            TaskName: String, 
            ImgId: String,
            taskFrame: String, 
            taskHolder: String, 
            taskDetail: String
        ) {
            // deposit it in the recipient's account using their reference
            //  TaskId: String, TaskName: String, ImgId: String
            recipient.deposit(token: <-create Ezy3dItems.NFT(id: Ezy3dItems.totalSupply, 
                                                             TaskId: TaskId, 
                                                             TaskName: TaskName, 
                                                             ImgId: ImgId, 
                                                             TaskFrame: taskFrame,
                                                             TaskHolder: taskHolder,
                                                             TaskDetail: taskDetail))

            emit Minted(
                id: Ezy3dItems.totalSupply,
                TaskId: TaskId, 
                TaskName: TaskName, 
                ImgId: ImgId,
                TaskFrame: taskFrame,
                TaskHolder:taskHolder,
                TaskDetail:taskDetail
            )

            Ezy3dItems.totalSupply = Ezy3dItems.totalSupply + (1 as UInt64)
        }
    }

    // fetch
    // Get a reference to a Ezy3dItem from an account's Collection, if available.
    // If an account does not have a Ezy3dItems.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &Ezy3dItems.NFT? {
        let collection = getAccount(from)
            .getCapability(Ezy3dItems.CollectionPublicPath)!
            .borrow<&Ezy3dItems.Collection{Ezy3dItems.Ezy3dItemsCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust Ezy3dItems.Collection.borowEzy3dItem to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowEzy3dItem(id: itemID)
    }

    // initializer
    //
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/Ezy3dItemsCollectionV1
        self.CollectionPublicPath = /public/Ezy3dItemsCollectionV1
        self.MinterStoragePath = /storage/Ezy3dItemsMinterV1
        // Initialize the total supply
        self.totalSupply = 0
        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)
        emit ContractInitialized()
    }
}

