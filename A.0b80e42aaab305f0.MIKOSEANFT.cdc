import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract MIKOSEANFT: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event ItemCreated(id:UInt64, metadata:{String:String}, itemSupply: UInt64)
    pub event UpdateItemMetadata(id:UInt64, metadata:{String:String}, itemSupply: UInt64)
    pub event ItemDeleted(itemId: UInt64)
    pub event ProjectCreated(projectId: UInt64, name:String, description:String, creatorAddress:Address, creatorFee:UFix64, platformFee:UFix64, mintPrice: UFix64)
    pub event ProjectUpdated(projectId: UInt64, name:String, description:String, creatorAddress:Address, creatorFee:UFix64, platformFee:UFix64, mintPrice: UFix64)
    pub event ItemAddedToProject(projectId: UInt64, itemId: UInt64)
    pub event ItemLock(projectId:UInt64, itemId:UInt64, numberOfNFTs:UInt64)
    pub event ProjectLocked(projectId:UInt64)
    pub event Minted(id:UInt64, projectId:UInt64, itemId:UInt64,tx_uiid:String, mintNumber:UInt64)
    pub event Destroyed(id: UInt64)

    // Path
    pub var CollectionPublicPath: PublicPath
    pub var CollectionStoragePath: StoragePath
    pub var MikoSeaAdmin: StoragePath


    // Entity Counts
    pub var nextItemId: UInt64
    pub var nextProjectId: UInt64
    pub var totalSupply: UInt64
    pub var nextCommentId: UInt64


    // Dictionaries
    pub var itemData: {UInt64: Item}
    pub var projectsData: {UInt64: ProjectData}
    pub var projects: @{UInt64: Project}
    pub var commentData: {UInt64: Comment}


    //------------------------------------------------------------
    // Comment Struct
    //------------------------------------------------------------

    pub struct Comment {
        pub var commentId: UInt64
        pub var projectId: UInt64
        pub var itemId: UInt64
        pub var userAddress: Address
        pub var nftId: UInt64
        pub var comment: String

        init(projectId:UInt64, itemId:UInt64, userAddress: Address, nftId:UInt64, comment: String){
            pre{
                comment.length != 0 : "Comment can not be empty"
            }
            self.commentId = MIKOSEANFT.nextCommentId
            self.projectId = projectId
            self.itemId = itemId
            self.userAddress = userAddress
            self.nftId = nftId
            self.comment = comment
            MIKOSEANFT.nextCommentId = MIKOSEANFT.nextCommentId + 1
        }
    }


    //------------------------------------------------------------
    // Item Struct hold Metadata associated with NFT
    //------------------------------------------------------------

    pub struct Item {

        pub let itemId:UInt64
        pub var metadata: {String:String}
        pub var itemSupply: UInt64
        init(metadata: {String:String}, itemSupply:UInt64){
            pre{
                metadata.length != 0: "New Item metadata cannot be empty"
            }
            self.itemId = MIKOSEANFT.nextItemId
            self.metadata = metadata
            self.itemSupply = itemSupply

            MIKOSEANFT.nextItemId = MIKOSEANFT.nextItemId + 1
            emit ItemCreated(id:self.itemId, metadata:metadata, itemSupply:itemSupply)
        }
    }


    //------------------------------------------------------------
    // Project
    //------------------------------------------------------------

    pub struct ProjectData{
        pub let projectId: UInt64
        pub let name: String
        pub let description: String
        pub let creatorAddress: Address
        pub let creatorFee: UFix64
        pub let platformFee: UFix64

        init(name: String, description: String, creatorAddress: Address, creatorFee:UFix64, platformFee:UFix64, mintPrice: UFix64){
            pre{
                name.length > 0: "New Project name cannot be empty"
                description.length > 0: "New Project description cannot be empty"
                creatorAddress != nil: "Creator address cannot be nil"
                creatorFee != nil : "Creator fee cannot be empty"
                platformFee >= 0.1 : "Platform fee is equal to 0.1"
            }
            self.projectId = MIKOSEANFT.nextProjectId
            self.name = name
            self.description = description
            self.creatorAddress = creatorAddress
            self.creatorFee = creatorFee
            self.platformFee = platformFee
            MIKOSEANFT.nextProjectId = MIKOSEANFT.nextProjectId + 1
            emit ProjectCreated(projectId: self.projectId, name:self.name, description:self.description, creatorAddress:self.creatorAddress, creatorFee:self.creatorFee, platformFee:self.platformFee, mintPrice: mintPrice)
        }
    }


    pub resource Project{
        pub let projectId: UInt64
        pub var items: [UInt64]
        pub var lockItems: {UInt64: Bool}
        pub var locked: Bool
        pub var numberMintedPerItem: {UInt64: UInt64}

        init(name:String, description:String, creatorAddress: Address, creatorFee:UFix64, platformFee:UFix64, mintPrice: UFix64){
            self.projectId = MIKOSEANFT.nextProjectId
            self.lockItems = {}
            self.locked = false
            self.items = []
            self.numberMintedPerItem = {}
            MIKOSEANFT.projectsData[self.projectId] = ProjectData(
                                                    name: name,
                                                    description: description,
                                                    creatorAddress: creatorAddress,
                                                    creatorFee:creatorFee,
                                                    platformFee:platformFee,
                                                    mintPrice: mintPrice)
        }

        pub fun addItem(id:UInt64){
            pre{
                self.numberMintedPerItem[id] == nil: "The item is already to project"
                !self.locked: "cannot add item to project, after project is lock"
                MIKOSEANFT.itemData[id] != nil: "cannot add item to project, item doesn't exist"
            }
            self.items.append(id)
            self.lockItems[id] = false
            self.numberMintedPerItem[id] = 0
            emit ItemAddedToProject(projectId:self.projectId, itemId:id)
        }

        pub fun addItems(ids: [UInt64]) {
            for i in ids{
                self.addItem(id: i)
            }
        }

        pub fun lockItem(id:UInt64){
            pre {
                self.lockItems[id] != nil: "Cannot lock the item: Item doesn't exist in this project!"
            }
            if !self.lockItems[id]! {
                self.lockItems[id] = true
                emit ItemLock(projectId:self.projectId, itemId:id, numberOfNFTs:self.numberMintedPerItem[id]!)
            }
        }

        pub fun lockAllItems() {
            for item in self.items {
                self.lockItem(id: item)
            }
        }

        pub fun projectLock(){
            if !self.locked{
                self.locked = true
                emit ProjectLocked(projectId: self.projectId)
            }
        }

        pub fun mintNFT(itemId:UInt64, tx_uiid:String): @NFT{
            pre{
                self.lockItems[itemId] != nil: "cannot mint the nft, this item does't not exist in project"
                !self.lockItems[itemId]! : "Cannot mint the nft from this item, item has been lock"
            }
            let numInItems = self.numberMintedPerItem[itemId]!
            let newNFT: @NFT <- create NFT(projectId: self.projectId, itemId: itemId, tx_uiid:tx_uiid, mintNumber:numInItems + 1)
            self.numberMintedPerItem[itemId] = numInItems + 1
            return <- newNFT
        }

        pub fun batchMintNFT(itemId: UInt64, quantity: UInt64, tx_uiid:String): @Collection {
            let newCollection <- create Collection()
            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintNFT(itemId: itemId, tx_uiid:tx_uiid))
                i = i + 1
            }
            return <-newCollection
        }
    }


    //------------------------------------------------------------
    // NFT
    //------------------------------------------------------------

    pub struct NFTData {
        pub let projectId: UInt64
        pub let itemId: UInt64
        pub let mintNumber: UInt64
        init(projectId: UInt64, itemId: UInt64, mintNumber:UInt64) {
            self.projectId = projectId
            self.itemId = itemId
            self.mintNumber = mintNumber
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver{
        pub let id: UInt64
        pub let tx_uiid: String
        pub var data: NFTData

        init(projectId: UInt64, itemId: UInt64, tx_uiid:String, mintNumber:UInt64, ){
            MIKOSEANFT.totalSupply = MIKOSEANFT.totalSupply + 1
            self.id = MIKOSEANFT.totalSupply
            self.tx_uiid = tx_uiid
            self.data = NFTData(projectId:projectId, itemId:itemId, mintNumber:mintNumber)
            emit Minted(id:self.id, projectId:self.data.projectId, itemId:self.data.itemId, tx_uiid:self.tx_uiid, mintNumber:self.data.mintNumber)
        }

        pub fun getImage() : String {
            let defaultValue = "https://mikosea.s3.ap-northeast-1.amazonaws.com/mikosea-project/mikoseanft_200.png"
            return MIKOSEANFT.getItemMetaDataByField(itemId: self.data.itemId, field: "image") ?? MIKOSEANFT.getItemMetaDataByField(itemId: self.data.itemId, field: "imageURL") ?? defaultValue
        }

        pub fun getTitle() : String {
            let defaultValue = "MikoSea 1st Membership NFT"
            return MIKOSEANFT.getProjectName(projectId: self.data.projectId) ?? defaultValue
        }

        pub fun getDescription() : String {
            let defaultValue = "MikoSea 1st Membership NFT はMikoSeaで最初に発行されるNFTになります。同じ価値観・感性をもった仲間と共同意識を持ちながら夢を実現させる手段として発行します。"
            return MIKOSEANFT.getProjectDescription(projectId: self.data.projectId) ?? defaultValue
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.getTitle(),
                        description: self.getDescription(),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.getImage()
                        )
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
                    return MetadataViews.ExternalURL("https://mikosea.io/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: MIKOSEANFT.CollectionStoragePath,
                        publicPath: MIKOSEANFT.CollectionPublicPath,
                        providerPath: /private/MiKoSeaNFTCollection,
                        publicCollection: Type<&MIKOSEANFT.Collection{MIKOSEANFT.MikoSeaCollectionPublic}>(),
                        publicLinkedType: Type<&MIKOSEANFT.Collection{MIKOSEANFT.MikoSeaCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&MIKOSEANFT.Collection{MIKOSEANFT.MikoSeaCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-MIKOSEANFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://storage.googleapis.com/studio-design-asset-files/projects/1pqD36e6Oj/s-300x50_aa59a692-741b-408b-aea3-bcd25d29c6bd.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://app.mikosea.io/mikosea_1.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "あらゆる事業者の思いを載せて神輿を担ぐNFTクラウドファンディングマーケット",
                        description: "MikoSeaはアーティスト、企業、インフルエンサーといったクリエイターや、あたらしく何かを始めたい人のためのクラウドファンディングサービスです。プロジェクトの発起人は、NFTを販売することで商品を販売するという一方向の取引を超え、プロジェクトの想いに共感した“熱狂的なファン“から資金を調達し、夢の実現へと近づけます。プロジェクト支援者は、プロジェクトを支援する目的でNFTを購入し、共創･協働のプロセスに参加することで、プロジェクトから特別な体験価値やメリットを得ることができます。",
                        externalURL: MetadataViews.ExternalURL("https://app.mikosea.io/"),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/MikoSea_io")
                        }
                    )
            }
            return nil
        }
    }


    //------------------------------------------------------------
    // Admin
    //------------------------------------------------------------

    pub resource Admin{

        pub fun createItem(metadata: {String:String}, itemSupply:UInt64): UInt64{
            var newItem = Item(metadata:metadata, itemSupply:itemSupply)
            let id = newItem.itemId
            MIKOSEANFT.itemData[id] = newItem
            return id
        }

        pub fun createItems(items: [{String: String}], projectId: UInt64, itemSupply:UInt64){
            var itemIds: [UInt64] = []
            for metadata in items {
                var Id = self.createItem(metadata: metadata, itemSupply:itemSupply)
                itemIds.append(Id)
            }
            self.borrowProject(projectId: projectId).addItems(ids: itemIds)
        }

        pub fun updateItemMetadata(itemId:UInt64, newData:{String:String}, itemSupply:UInt64){
            let latestItemId = MIKOSEANFT.nextItemId
            MIKOSEANFT.nextItemId = itemId
            MIKOSEANFT.itemData[itemId] = Item(metadata:newData, itemSupply:itemSupply)

            MIKOSEANFT.nextItemId = latestItemId
            emit UpdateItemMetadata(id: itemId, metadata: newData, itemSupply: itemSupply)
        }

        pub fun createProject(name:String, description:String, creatorAddress: Address, creatorFee:UFix64, platformFee: UFix64, mintPrice: UFix64){
            var newProject <- create Project(name:name, description:description, creatorAddress:creatorAddress, creatorFee:creatorFee, platformFee:platformFee, mintPrice: mintPrice)
            MIKOSEANFT.projects[newProject.projectId] <-! newProject
        }

        pub fun borrowProject(projectId: UInt64): &Project {
            pre {
                MIKOSEANFT.projects[projectId] != nil: "Cannot borrow Project: The Project doesn't exist"
            }
            return (&MIKOSEANFT.projects[projectId] as &Project?)!
        }

        pub fun deleteItem(id:UInt64){
            pre{
                MIKOSEANFT.itemData[id] != nil : "Could not delete Item, Item does not exist"
            }
            MIKOSEANFT.itemData.remove(key: id)
            emit ItemDeleted(itemId: id)
        }

        pub fun createNewAdmin(): @Admin{
            return <- create Admin()
        }

        pub fun updateProject(projectId: UInt64, name:String, description:String, creatorAddress: Address, creatorFee:UFix64, platformFee: UFix64, mintPrice: UFix64) {
            if MIKOSEANFT.projectsData[projectId] == nil {
                panic("not found project")
            }
            let oldLatestProjectId = MIKOSEANFT.nextProjectId

            MIKOSEANFT.nextProjectId = projectId
            MIKOSEANFT.projectsData[projectId] = ProjectData(
                                                    name: name,
                                                    description: description,
                                                    creatorAddress: creatorAddress,
                                                    creatorFee:creatorFee,
                                                    platformFee:platformFee,
                                                    mintPrice: mintPrice)
            MIKOSEANFT.nextProjectId = oldLatestProjectId
            emit ProjectUpdated(projectId: projectId, name: name, description: description, creatorAddress: creatorAddress, creatorFee: creatorFee, platformFee: platformFee, mintPrice: mintPrice)
        }
    }

    //------------------------------------------------------------
    // Collection Resource
    //------------------------------------------------------------

    pub resource interface MikoSeaCollectionPublic{
        pub fun deposit(token:@NonFungibleToken.NFT)
        pub fun batchDeposit(tokens:@NonFungibleToken.Collection)
        pub fun getIDs():[UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun destroyNFT(id:UInt64)
        pub fun borrowMiKoSeaNFT(id:UInt64): &MIKOSEANFT.NFT?{
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow MiKoSeaAsset reference: The Id of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: MikoSeaCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init(){
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID:UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing nft")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT){
            let token <- token as! @MIKOSEANFT.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id:id, to:self.owner?.address)
            destroy oldToken
        }

        pub fun batchWithdraw(ids:[UInt64]): @NonFungibleToken.Collection{
            var batchCollection <- create Collection()
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            return <-batchCollection
        }

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {
            let keys = tokens.getIDs()
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }
            destroy tokens
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            pre {
                self.ownedNFTs[id] != nil: "Cannot borrow NFT, no such id"
            }

            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mikoseaNFT = nft as! &MIKOSEANFT.NFT
            return mikoseaNFT as &AnyResource{MetadataViews.Resolver}
        }

        pub fun borrowMiKoSeaNFT(id: UInt64): &MIKOSEANFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &MIKOSEANFT.NFT
            } else {
                return nil
            }
        }

        pub fun borrowNFTSafe(id: UInt64): &MIKOSEANFT.NFT? {
            return self.borrowMiKoSeaNFT(id: id)
        }

        pub fun getIDs(): [UInt64]{
            return self.ownedNFTs.keys
        }

        pub fun destroyNFT(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")
            destroy token
            emit Destroyed(id: id)
        }

        destroy (){
            destroy self.ownedNFTs
        }
    }


    //------------------------------------------------------------
    // Public function
    //------------------------------------------------------------

    pub fun createEmptyCollection(): @Collection{
        return <- create Collection()
    }

    pub fun checkCollection(_ address: Address): Bool {
        return getAccount(address)
        .getCapability<&{MIKOSEANFT.MikoSeaCollectionPublic}>(MIKOSEANFT.CollectionPublicPath)
        .check()
    }

    pub fun purchaseNFT(projectId:UInt64, itemId:UInt64, tx_uiid:String): @MIKOSEANFT.NFT {
        let buy = (&MIKOSEANFT.projects[projectId] as &Project?)!
        return <- buy.mintNFT(itemId: itemId, tx_uiid:tx_uiid)
    }

    //------------------------------------------------------------
    // Comment Public function
    //------------------------------------------------------------

    pub fun createComment(projectId:UInt64, itemId:UInt64, userAddress: Address, nftId:UInt64, comment: String): UInt64{
        var newComment = Comment(projectId:projectId, itemId:itemId, userAddress: userAddress, nftId:nftId, comment: comment)
        var newId = newComment.commentId
        MIKOSEANFT.commentData[newId] = newComment
        return newId
    }

    pub fun deleteComment(commentId:UInt64){
        MIKOSEANFT.commentData.remove(key: commentId)
    }

    pub fun editComment(commentId:UInt64, projectId:UInt64, itemId:UInt64, userAddress: Address, nftId:UInt64, newComment:String): UInt64{
        MIKOSEANFT.commentData[commentId] = Comment(projectId:projectId, itemId:itemId, userAddress: userAddress, nftId:nftId, comment: newComment)
        return commentId
    }

    pub fun getCommentById(id:UInt64): String? {
        return MIKOSEANFT.commentData[id]?.comment
    }

    pub fun getCommentAddressById(id:UInt64): Address? {
        return MIKOSEANFT.commentData[id]?.userAddress
    }

    pub fun getCommentProjectIdById(id:UInt64): UInt64? {
        return MIKOSEANFT.commentData[id]?.projectId
    }

    pub fun getCommentItemIdById(id:UInt64): UInt64? {
        return MIKOSEANFT.commentData[id]?.itemId
    }

    pub fun getCommentNFTIdById(id:UInt64): UInt64? {
        return MIKOSEANFT.commentData[id]?.nftId
    }

    pub fun getAllComments(): [MIKOSEANFT.Comment]{
        return self.commentData.values
    }

    pub fun removeAllCommentByNftId(_ nftId: UInt64) {
        for commentId in MIKOSEANFT.commentData.keys {
            let commentNftId = MIKOSEANFT.getCommentNFTIdById(id: commentId)
            if nftId == commentNftId {
                MIKOSEANFT.deleteComment(commentId: commentId)
            }
        }
    }



    //------------------------------------------------------------
    // Item Public function
    //------------------------------------------------------------

    pub fun getAllItems(): [MIKOSEANFT.Item]{
        return self.itemData.values
    }

    pub fun getItemMetaData(itemId: UInt64): {String: String}? {
        return self.itemData[itemId]?.metadata
    }

    pub fun getItemsInProject(projectId: UInt64): [UInt64]? {
        return MIKOSEANFT.projects[projectId]?.items
    }

    pub fun getItemMetaDataByField(itemId: UInt64, field: String): String? {
        if let item = self.itemData[itemId] {
            return item.metadata[field]
        } else {
            return nil
        }
    }

    pub fun getItemSupply(itemId:UInt64): UInt64?{
        let item = self.itemData[itemId]
        return item?.itemSupply
    }

    pub fun isProjectItemLocked(projectId: UInt64, itemId: UInt64): Bool? {
        if let projectToRead <- self.projects.remove(key: projectId) {
            let locked = projectToRead.lockItems[itemId]
            self.projects[projectId] <-! projectToRead
            return locked
        } else {
            return nil
        }
    }

    //------------------------------------------------------------
    // Project Public function
    //------------------------------------------------------------

    pub fun getAllProjects(): [MIKOSEANFT.ProjectData]{
        return self.projectsData.values
    }

    pub fun getProjectName(projectId: UInt64): String? {
        return self.projectsData[projectId]?.name
    }

    pub fun getProjectDescription(projectId: UInt64): String? {
        return self.projectsData[projectId]?.description
    }

    pub fun getProjectCreatorAddress(projectId: UInt64): Address? {
        return self.projectsData[projectId]?.creatorAddress
    }

    pub fun getProjectCreatorFee(projectId: UInt64): UFix64? {
        return self.projectsData[projectId]?.creatorFee
    }

    pub fun getProjectPlatformFee(projectId: UInt64): UFix64? {
        return self.projectsData[projectId]?.platformFee
    }

    pub fun isProjectLocked(projectId: UInt64): Bool? {
        return self.projects[projectId]?.locked
    }

    pub fun getProjectIdByName(projectName: String): [UInt64]? {
        var projectIds: [UInt64] = []

        for projectDatas in self.projectsData.values {
            if projectName == projectDatas.name {
                projectIds.append(projectDatas.projectId)
            }
        }

        if projectIds.length == 0 {
            return nil
        } else {
            return projectIds
        }
    }

    // fetch the nft from user collection
    pub fun fetch(_from:Address, itemId:UInt64): &MIKOSEANFT.NFT?{
        let collection = getAccount(_from).getCapability(MIKOSEANFT.CollectionPublicPath).borrow<&AnyResource{MIKOSEANFT.MikoSeaCollectionPublic}>()?? panic("does't not collection")
        return collection.borrowMiKoSeaNFT(id: itemId)
    }

    // get total count of minted nft from project item
    pub fun getTotalMintedNFTFromProjectItem(projectId:UInt64, itemId:UInt64): UInt64?{
        if let projectToRead <- self.projects.remove(key: projectId) {
            let value = projectToRead.numberMintedPerItem[itemId]
            self.projects[projectId] <-! projectToRead
            return value
        } else {
            return nil
        }
    }

    //------------------------------------------------------------
    // Initializer
    //------------------------------------------------------------

    init(){
        // Initialize contract paths
        self.CollectionStoragePath = /storage/MikoSeaCollection
        self.CollectionPublicPath = /public/MikoSeaCollection
        self.MikoSeaAdmin = /storage/MiKoSeaNFTAdmin

        // Initialize contract fields
        self.nextItemId = 1
        self.nextProjectId = 1
        self.nextCommentId = 1
        self.totalSupply = 0
        self.itemData = {}
        self.projectsData = {}
        self.projects <- {}
        self.commentData = {}

        // Put the new Collection into the account storage
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        // Put the Admin in storage
        self.account.save(<- create Admin(), to: self.MikoSeaAdmin)
        // Creating public capability of the Collection resource
        self.account.link<&{MikoSeaCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        emit ContractInitialized()
    }
}
