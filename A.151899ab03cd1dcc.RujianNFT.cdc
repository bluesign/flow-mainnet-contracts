import NonFungibleToken from 0x151899ab03cd1dcc 
import MetadataViews from 0x151899ab03cd1dcc

pub contract RujianNFT: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, 
                     resourceId: String, 
                     resourceName: String, 
                     ownerId: String,
                     resourceHash: String,
                     timeStamp: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupply
    // 如见NFT 已经铸造的NFT数量
    //
    pub var totalSupply: UInt64


    // 如见 资源存证NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        // 资源ID
        pub let resourceId: String
        // 资源名称
        pub let resourceName: String
        // 资源持有者
        pub let ownerId: String
        // 资源hash
        pub let resourceHash :String
        // 请求时间戳
        pub let timeStamp: String
        access(self) let royalties: [MetadataViews.Royalty]
        access(self) let metadata: {String: AnyStruct}
        
        init(id: UInt64, 
            resourceId: String, 
            resourceName: String, 
            ownerId: String, 
            resourceHash: String, 
            timeStamp: String,
            royalties: [MetadataViews.Royalty],
            metadata: {String: AnyStruct},) 
        {
            self.id = id
            self.resourceId = resourceId
            self.resourceName = resourceName
            self.ownerId = ownerId
            self.resourceHash = resourceHash
            self.timeStamp = timeStamp
            self.royalties = royalties
            self.metadata = metadata
        }

        pub fun description(): String {
            return "resourceId: "
                .concat(self.resourceId)
                .concat(" resourceName:")
                .concat(self.resourceName)
                .concat(" resourceHash")
                .concat(self.resourceHash)
        }
        
        pub fun thumbnail(): MetadataViews.HTTPFile {
          return MetadataViews.HTTPFile(url: "https://rujian-nft.rujian.com/resource/thumbnail?resourceId=".concat(self.resourceId))
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
                        name: self.resourceName,
                        description: self.description(),
                        thumbnail: self.thumbnail()
                    )
                case Type<MetadataViews.Editions>():
                    // 此合约没有可以铸造的最大数量的 NFT，因此最大版本字段值设置为 nil
                    let editionInfo = MetadataViews.Edition(name: "Rujian NFT Edition", number: self.id, max: nil)
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
                    return MetadataViews.ExternalURL("https://rujian-nft.rujian.com/nft/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: RujianNFT.CollectionStoragePath,
                        publicPath: RujianNFT.CollectionPublicPath,
                        providerPath: /private/KittyItemsCollection,
                        publicCollection: Type<&RujianNFT.Collection{RujianNFT.RujianNFTCollectionPublic}>(),
                        publicLinkedType: Type<&RujianNFT.Collection{RujianNFT.RujianNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&RujianNFT.Collection{RujianNFT.RujianNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-RujianNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://www.rujian.vip/images/logo_icon.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The RujianNFT Collection",
                        description: "This collection is used as an example to help you develop your next Flow NFT.",
                        externalURL: MetadataViews.ExternalURL("https://rujian-nft.rujian.com/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "weibo": MetadataViews.ExternalURL("https://weibo.com/rujianapp")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits
                    let excludedTraits = ["mintedTime", "resourceHash", "resourceOwnerId","resourceName"]
                    let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: excludedTraits)

                    // mintedTime is a unix timestamp, we should mark it with a displayType so platforms know how to show it.
                    let mintedTimeTrait = MetadataViews.Trait(name: "mintedTime", value: self.metadata["mintedTime"]!, displayType: "Date", rarity: nil)
                    traitsView.addTrait(mintedTimeTrait)

                    // NFT 资源ID、hash、持有者ID
                    let resourceOwnerIdTrait = MetadataViews.Trait(name: "resourceOwnerId", value: self.metadata["resourceOwnerId"], displayType: nil, rarity: nil)
                    let resourceHashTrait = MetadataViews.Trait(name: "resourceHash", value: self.metadata["resourceHash"], displayType: nil, rarity: nil)
                    let resourceNameTrait = MetadataViews.Trait(name: "resourceName", value: self.metadata["resourceName"], displayType: nil, rarity: nil)
                    traitsView.addTrait(resourceOwnerIdTrait)
                    traitsView.addTrait(resourceHashTrait)
                    traitsView.addTrait(resourceNameTrait)
                    
                    return traitsView

                
            }

            return nil
        }
    }

    // 接口，允许用户铸造 NFT(如见资源存证) 到 如见资源存证 NFT 集合
    // 从 集合中 查询 NFT(资源存证信息) 信息
    pub resource interface RujianNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowRujianNFT(id: UInt64): &RujianNFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow RujianNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }


    // 如见资源存证 NFT 作品集
    pub resource Collection: RujianNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // 初始化
        init () {
            self.ownedNFTs <- {}
        }

        //  提取
        // 从 NFT 作品集 取出一个，并转移到调用者
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        // 部署nft 
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @RujianNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        // 查询集合中 id 列表
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

        // borrowRujianNFT
        // Gets a reference to an NFT in the collection as a Ezy3dItem,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the Ezy3dItem.
        //
        pub fun borrowRujianNFT(id: UInt64): &RujianNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &RujianNFT.NFT
            } else {
                return nil
            }
        }
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let RjNft = nft as! &RujianNFT.NFT
            return RjNft as &AnyResource{MetadataViews.Resolver}
        }
        // destructor
        destroy() {
            destroy self.ownedNFTs
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
            resourceId: String, 
            resourceName: String, 
            ownerId: String,
            resourceHash: String, 
            timeStamp: String,
            royalties: [MetadataViews.Royalty]
        ) {
            // deposit it in the recipient's account using their reference
            //  TaskId: String, TaskName: String, ImgId: String
            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp
            metadata["minter"] = recipient.owner!.address
            metadata["resourceHash"] = resourceHash
            metadata["resourceName"] = resourceName
            metadata["resourceId"] = resourceId
            metadata["resourceOwnerId"] = ownerId
            recipient.deposit(token: <-create RujianNFT.NFT(id: RujianNFT.totalSupply, 
                                                             resourceId: resourceId, 
                                                             resourceName: resourceName, 
                                                             ownerId: ownerId, 
                                                             resourceHash: resourceHash,
                                                             timeStamp: timeStamp,
                                                             royalties:royalties,
                                                             metadata: metadata))

            emit Minted(
                id: RujianNFT.totalSupply,
                resourceId: resourceId, 
                resourceName: resourceName, 
                ownerId: ownerId,
                resourceHash: resourceHash,
                timeStamp:timeStamp
            )

            RujianNFT.totalSupply = RujianNFT.totalSupply + UInt64(1)
        }
    }

    // fetch
    // Get a reference to a RjResourceItems from an account's Collection, if available.
    // If an account does not have a RjResourceItems.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &RujianNFT.NFT? {
        let collection = getAccount(from)
            .getCapability(RujianNFT.CollectionPublicPath)!
            .borrow<&RujianNFT.Collection{RujianNFT.RujianNFTCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust RjResourceItems.Collection.borrowRujianNFT to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowRujianNFT(id: itemID)
    }

    // initializer
    //
    init() {
        // Initialize the total supply
        self.totalSupply = 0    
        // Set our named paths
        self.CollectionStoragePath = /storage/RujianNFTCollectionV1
        self.CollectionPublicPath = /public/RujianNFTCollectionV1
        self.MinterStoragePath = /storage/RujianNFTMinterV1
        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)
        // Create a public capability for the collection
        self.account.link<&RujianNFT.Collection{NonFungibleToken.CollectionPublic, RujianNFT.RujianNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )
        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)
        emit ContractInitialized()
    }
}
