//SPDX-License-Identifier : CC-BY-NC-4.0
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import FlowUtilityToken from 0xead892083b3e2c6c

// Metaverse
// NFT for Metaverse
//
pub contract MetaverseMarket: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, typeID: UInt64, metadata: {String:String})
    pub event BatchMinted(ids: [UInt64], typeID: [UInt64], metadata: {String:String})
    pub event NFTBurned(id: UInt64)
    pub event NFTsBurned(ids: [UInt64])
    pub event CategoryCreated(categoryName: String)
    pub event SubCategoryCreated(subCategoryName: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // totalSupply
    // The total number of MetaverseMarkets that have been minted
    //
    pub var totalSupply: UInt64

    // List with all categories and respective code
    access(self) var categoriesList: {UInt64 :String}

    // {CategoryName: [NFT To Sell ID]}
    access(self) var categoriesNFTsToSell: {UInt64: [UInt64]}

    // Dictionary with NFT List Data
    access(self) var nftsToSell: {UInt64: OzoneListToSellMetadata}


    pub struct OzoneListToSellMetadata {
      //List ID that will came from the backend, all NFTs from same list will have same listId
      pub let listId: UInt64
      pub var name: String
      pub var description: String
      pub var categoryId: UInt64
      pub let creator: Address?
      pub let creatorDapperAddress: Address?
      pub let fileName: String
      pub var previewImage: String
      pub let format: String
      pub let fileIPFS: String
      pub var price: UFix64
      pub let maxSupply: UInt64
      pub var minted: UInt64

      pub fun addMinted(){
        self.minted = self.minted + (1 as UInt64)
      }

      pub fun changePrice(newPrice: UFix64){
        self.price = newPrice
      }


      pub fun updateList(newPreviewImage: String?, newName: String?, newDescription: String?, newCategoryId: UInt64?){
        if newPreviewImage != nil {
            self.previewImage = newPreviewImage!
        } 
        if newName != nil {
            self.name = newName!
        } 
        if newDescription != nil {
            self.description = newDescription!
        } 
        if newCategoryId != nil {
            self.categoryId = newCategoryId!
        }
      }

      init(_listId: UInt64, _name: String, _description: String, _categoryId: UInt64, _creator: Address?, _creatorDapperAddress: Address? ,_fileName: String, _previewImage: String, _format: String, _fileIPFS: String, _price: UFix64, _maxSupply: UInt64){
        self.listId = _listId
        self.name = _name
        self.description = _description
        self.categoryId = _categoryId
        self.creator = _creator
        self.creatorDapperAddress = _creatorDapperAddress
        self.fileName = _fileName
        self.previewImage = _previewImage
        self.format = _format
        self.fileIPFS = _fileIPFS
        self.price = _price
        self.maxSupply = _maxSupply
        self.minted = 0
      }
    }

    // NFT
    // MetaverseMarket as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // The token's ID
        //NFT CONTRACT GLOBAL ID -> Current TotalSupply
        pub let id: UInt64

        //Current List minted(List TotalSupply)
        pub let uniqueListId: UInt64

        //List ID that will came from the backend, all NFTs from same list will have same listId
        pub let listId: UInt64

        pub let name: String

        pub let description: String

        pub let previewImage: String

        pub let categoryId: UInt64

        pub let creator: Address?

        pub let creatorDapperWallet: Address?

        pub let fileName: String

        pub let format: String

        pub let fileIPFS: String



        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.fileIPFS
                        )
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://ozonemetaverse.io/")
                case Type<MetadataViews.Royalties>(): 
                    let royalties : [MetadataViews.Royalty] = []
                    royalties.append(MetadataViews.Royalty(recipient: getAccount(MetaverseMarket.account.address).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver), cut: 0.03, description: "Ozone Marketplace Secondary Sale Royalty"))
                    royalties.append(MetadataViews.Royalty(recipient: getAccount(self.creator!).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver), cut: 0.07, description: "NFT Creator Secondary Sale Royalty"))
                    return MetadataViews.Royalties(cutInfos: royalties)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: MetaverseMarket.CollectionStoragePath,
                        publicPath: MetaverseMarket.CollectionPublicPath,
                        providerPath: /private/ProvenancedCollectionsV9,
                        publicCollection: Type<&MetaverseMarket.Collection{MetaverseMarket.MetaverseMarketCollectionPublic, NonFungibleToken.CollectionPublic}>(),
                        publicLinkedType: Type<&MetaverseMarket.Collection{MetaverseMarket.MetaverseMarketCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&MetaverseMarket.Collection{MetaverseMarket.MetaverseMarketCollectionPublic,NonFungibleToken.Provider,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-MetaverseMarket.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                           url: "https://d19wottuqbmkwr.cloudfront.net/nft/banners1.jpg"
                        ),
                        mediaType: "image"
                    )
                    let bannerMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://d19wottuqbmkwr.cloudfront.net/nft/banners2.jpg"
                        ),
                        mediaType: "image"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Ozone Metaverse Marketplace",
                        description: "The first ever virtual world building creator NFT marketplace on Flow. Made by creators, for creators. Instantly create listings of all media file types including 3D models which can be immediately used in virtual world building studio. Build the new metaverse economy today by becoming a creator or simply start to build worlds today. Built on Flow. Powered by Ozone.",
                        externalURL: MetadataViews.ExternalURL("https://ozonemetaverse.io"),
                        squareImage: squareMedia,
                        bannerImage: bannerMedia,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/ozonemetaverse"),
                            "discord": MetadataViews.ExternalURL("https://discord.gg/ozonemetaverse")
                        }
                    )
            }

            return nil
        }

        // initializer
        //
        init(initID: UInt64, uniqueListId: UInt64, listId: UInt64, name: String, categoryId: UInt64, description: String, previewImage: String, creator: Address?, creatorDapperWallet: Address?, fileName: String, format: String, fileIPFS: String) {
            self.id = initID
            self.uniqueListId = uniqueListId
            self.listId = listId
            self.name = name
            self.description = description
            self.previewImage = previewImage
            self.categoryId = categoryId
            self.creator = creator
            self.creatorDapperWallet = creatorDapperWallet
            self.fileName = fileName
            self.format = format
            self.fileIPFS = fileIPFS

        }

        // If the NFT is burned, emit an event to indicate
        // to outside observers that it has been destroyed
        destroy() {
            emit NFTBurned(id: self.id)
        }
    }

    // This is the interface that users can cast their MetaverseMarket Collection as
    // to allow others to deposit MetaverseMarket into their Collection. It also allows for reading
    // the details of MetaverseMarket in the Collection.
    pub resource interface MetaverseMarketCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun getNFTs(): &{UInt64: NonFungibleToken.NFT}
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMetaverseMarket(id: UInt64): &MetaverseMarket.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow MetaverseMarket reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of MetaverseMarket NFTs owned by an account
    //
    pub resource Collection: MetaverseMarketCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @MetaverseMarket.NFT

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

        pub fun getNFTs(): &{UInt64: NonFungibleToken.NFT} {
            return (&self.ownedNFTs as auth &{UInt64: NonFungibleToken.NFT}?)!
            
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowMetaverseMarket
        // Gets a reference to an NFT in the collection as a MetaverseMarket,
        // exposing all of its fields (including the typeID).
        // This is safe as there are no functions that can be called on the MetaverseMarket.
        //
        pub fun borrowMetaverseMarket(id: UInt64): &MetaverseMarket.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &MetaverseMarket.NFT
            } else {
                return nil
            }
        }

        pub fun borrowNFTSafe(id: UInt64): &NFT? {
            post {
                result == nil || result!.id == id: "The returned reference's ID does not match the requested ID"
            }

            return self.ownedNFTs[id] != nil 
                ? (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &MetaverseMarket.NFT 
                : nil
        }

        // borrowViewResolver
        // Gets a reference to the MetadataViews resolver in the collection,
        // giving access to all metadata information made available.
        //
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let metaverseNft = nft as! &MetaverseMarket.NFT
            return metaverseNft as &AnyResource{MetadataViews.Resolver}
        }

        // destructor
        destroy() {
            emit NFTsBurned(ids: self.ownedNFTs.keys)
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

    // NFTAdmin
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
	pub resource Admin {

        pub fun createCategory(categoryId: UInt64, categoryName: String){

            if UInt64(MetaverseMarket.categoriesList.length + 1) != categoryId {
                panic("Category ID already exists")
            }

            MetaverseMarket.categoriesList[categoryId] = categoryName

            MetaverseMarket.categoriesNFTsToSell[categoryId] = []

            emit CategoryCreated(categoryName: categoryName)
        }

        pub fun createList(
            listId: UInt64,
            name: String,
            description: String,
            categoryId: UInt64,
            creator: Address?,
            creatorDapperAddress: Address?,
            fileName: String,
            previewImage: String,
            format: String,
            fileIPFS: String,
            price: UFix64,
            maxSupply: UInt64
            ){

            if UInt64(MetaverseMarket.nftsToSell.length + 1) != listId {
                panic("NFT List ID already exists")
            }

            let list = OzoneListToSellMetadata(
                _listId: listId,
                _name: name,
                _description: description,
                _categoryId: categoryId,
                _creator: creator,
                _creatorDapperAddress: creatorDapperAddress,
                _fileName: fileName,
                _previewImage: previewImage,
                _format: format,
                _fileIPFS: fileIPFS,
                _price: price,
                _maxSupply: maxSupply
            )

            MetaverseMarket.nftsToSell[listId] = list

            //Add the list to the categoriesNFTsToSell
            MetaverseMarket.categoriesNFTsToSell[categoryId]!.append(listId)

        }

		// mintNFT
        // Mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
        //
		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, payment: @FungibleToken.Vault, listedNftId: UInt64) {
            pre{
                MetaverseMarket.nftsToSell[listedNftId] != nil: "Listed ID does not exists!"
                payment.balance == MetaverseMarket.nftsToSell[listedNftId]!.price: "Incorrect price!"
                MetaverseMarket.nftsToSell[listedNftId]!.maxSupply != MetaverseMarket.nftsToSell[listedNftId]!.minted: "Max Supply reached!"
            }

            let list = MetaverseMarket.nftsToSell[listedNftId]!
            MetaverseMarket.nftsToSell[listedNftId]!.addMinted()

            let royalty <- payment.withdraw(amount: payment.balance * 0.1)

            switch payment.getType() {
                case Type<@FlowToken.Vault>(): 
                    // Get a reference to the recipient's Receiver
                    let receiverRef =  getAccount(list.creator!).getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()
                                    ?? panic("Could not borrow receiver reference to the recipient's Vault")
                    
                    // Get a reference to the recipient's Receiver
                    let royaltyReceiver = getAccount(MetaverseMarket.account.address).getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()
                                    ?? panic("Could not borrow receiver reference to the recipient's Vault")

                    royaltyReceiver.deposit(from: <- royalty)
                    receiverRef.deposit(from: <- payment)     

                    // deposit it in the recipient's account using their reference
                    recipient.deposit(token: <- create MetaverseMarket.NFT(
                                            initID: MetaverseMarket.totalSupply,
                                            uniqueListId: list.minted, 
                                            listId: list.listId, 
                                            name: list.name,
                                            categoryId: list.categoryId,
                                            description: list.description,
                                            previewImage: list.previewImage,
                                            creator: list.creator,
                                            creatorDapperAddress: list.creatorDapperAddress,
                                            fileName: list.fileName,
                                            format: list.format,
                                            fileIPFS: list.fileIPFS
                                            ))          
                
                case Type<@FlowUtilityToken.Vault>(): 
                    // Get a reference to the recipient's Receiver
                    let receiverRef =  getAccount(list.creatorDapperAddress!).getCapability(/public/flowUtilityTokenReceiver).borrow<&{FungibleToken.Receiver}>()
                                    ?? panic("Could not borrow receiver reference to the creator Dapper Address Vault")
                    
                    // Get a reference to the recipient's Receiver
                    let royaltyReceiver = getAccount(0x291d4a4ca55e2575).getCapability(/public/flowUtilityTokenReceiver).borrow<&{FungibleToken.Receiver}>()
                                    ?? panic("Could not borrow receiver reference to the recipient's Vault")

                    royaltyReceiver.deposit(from: <- royalty)
                    receiverRef.deposit(from: <- payment)

                    // deposit it in the recipient's account using their reference
                    recipient.deposit(token: <- create MetaverseMarket.NFT(
                                            initID: MetaverseMarket.totalSupply,
                                            uniqueListId: list.minted, 
                                            listId: list.listId, 
                                            name: list.name,
                                            categoryId: list.categoryId,
                                            description: list.description,
                                            previewImage: list.previewImage,
                                            creator: list.creatorDapperAddress,
                                            creatorDapperAddress: list.creatorDapperAddress,
                                            fileName: list.fileName,
                                            format: list.format,
                                            fileIPFS: list.fileIPFS
                                            ))

                default: 
                    panic("Unsupported token type")
            }

            MetaverseMarket.totalSupply = MetaverseMarket.totalSupply + (1 as UInt64)
		}

        //TransferNft, mint and transfer to Account NFT
        pub fun transferNFT(recipient: &{NonFungibleToken.CollectionPublic}, listedNftId: UInt64) {
                pre{
                    MetaverseMarket.nftsToSell[listedNftId] != nil: "Listed ID does not exists!"
                    MetaverseMarket.nftsToSell[listedNftId]!.maxSupply != MetaverseMarket.nftsToSell[listedNftId]!.minted: "Max Supply reached!"
                }

                let list = MetaverseMarket.nftsToSell[listedNftId]!
                MetaverseMarket.nftsToSell[listedNftId]!.addMinted()

                // deposit it in the recipient's account using their reference
                recipient.deposit(token: <- create MetaverseMarket.NFT(
                                        initID: MetaverseMarket.totalSupply,
                                        uniqueListId: list.minted, 
                                        listId: list.listId, 
                                        name: list.name,
                                        categoryId: list.categoryId,
                                        description: list.description,
                                        previewImage: list.previewImage,
                                        creator: list.creator,
                                        creatorDapperAddress: list.creatorDapperAddress,
                                        fileName: list.fileName,
                                        format: list.format,
                                        fileIPFS: list.fileIPFS
                                        ))

                MetaverseMarket.totalSupply = MetaverseMarket.totalSupply + (1 as UInt64)
        }

        //Delete Listing
        pub fun deleteListing(listedNftId: UInt64) {
            pre{
                MetaverseMarket.nftsToSell[listedNftId] != nil: "Listed ID does not exists!"
            }

            let list = MetaverseMarket.nftsToSell[listedNftId]!

            MetaverseMarket.nftsToSell.remove(key: listedNftId)
        }

        //Change Price
        pub fun changePrice(listedNftId: UInt64, newPrice: UFix64){
            pre{
                MetaverseMarket.nftsToSell[listedNftId] != nil: "Listed ID does not exists!"
            }

            let list = MetaverseMarket.nftsToSell[listedNftId]!

            MetaverseMarket.nftsToSell[listedNftId]!.changePrice(newPrice: newPrice)
        }

        pub fun updateList(listedNftId: UInt64, newPreviewImage: String?, newName: String?, newDescription: String?, newCategoryId: UInt64?){
            pre{
                MetaverseMarket.nftsToSell[listedNftId] != nil: "Listed ID does not exists!"
            }

            let list = MetaverseMarket.nftsToSell[listedNftId]!

            MetaverseMarket.nftsToSell[listedNftId]!.updateList(newPreviewImage: newPreviewImage, newName: newName, newDescription: newDescription, newCategoryId: newCategoryId)
        }
	}

    

    // fetch
    // Get a reference to a MetaverseMarket from an account's Collection, if available.
    // If an account does not have a MetaverseMarket.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &MetaverseMarket.NFT? {
        let collection = getAccount(from)
            .getCapability(MetaverseMarket.CollectionPublicPath)
            .borrow<&MetaverseMarket.Collection{MetaverseMarket.MetaverseMarketCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust MetaverseMarket.Collection.borowMetaverseMarket to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowMetaverseMarket(id: itemID)
    }

    pub fun getAllNftsFromAccount(_ from: Address): &{UInt64: NonFungibleToken.NFT}? {
        let collection = getAccount(from)
            .getCapability(MetaverseMarket.CollectionPublicPath)
            .borrow<&MetaverseMarket.Collection{MetaverseMarket.MetaverseMarketCollectionPublic}>()
            ?? panic("Couldn't get collection")
        return collection.getNFTs()
    }

    pub fun getCategories(): {UInt64:String} {
        return MetaverseMarket.categoriesList
    }

    pub fun getCategoriesIds(): [UInt64] {
        return MetaverseMarket.categoriesList.keys
    }

    pub fun getCategorieName(id: UInt64): String {
        return MetaverseMarket.categoriesList[id] ?? panic("Category does not exists")
    }

    pub fun getCategoriesListLength(): UInt64 {
        return UInt64(MetaverseMarket.categoriesList.length)
    }

    pub fun getNftToSellListLength(): UInt64{
        return UInt64(MetaverseMarket.nftsToSell.length)
    }

    pub fun getCategoriesNFTsToSell(categoryId: UInt64): [UInt64]?{
        return MetaverseMarket.categoriesNFTsToSell[categoryId]
    }

    pub fun getNftToSellData(listId: UInt64): OzoneListToSellMetadata? {
         return MetaverseMarket.nftsToSell[listId]
    }

    pub fun getAllListToSell(): [UInt64]{
        return MetaverseMarket.nftsToSell.keys
    }

    pub fun cleanListing(listId: UInt64){
        pre{
            MetaverseMarket.nftsToSell[listId]!.minted != MetaverseMarket.nftsToSell[listId]!.maxSupply: "Only Admin can deleted a not finished listing"
        }

        MetaverseMarket.nftsToSell.remove(key: listId)
    }

    // initializer
    //
	init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/NftMetaverseMarketCollectionVersionTwo
        self.CollectionPublicPath = /public/NftMetaverseMarketCollectionVersionTwo
        self.AdminStoragePath = /storage/metaverseMarketV2Admin

        self.categoriesList = {}

        self.categoriesNFTsToSell = {}

        self.nftsToSell = {}

        // Initialize the total supply
        self.totalSupply = 0

        // Create a Admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Create and link collection to this account
        self.account.save(<- self.createEmptyCollection(), to: self.CollectionStoragePath)
        self.account.link<&MetaverseMarket.Collection{NonFungibleToken.CollectionPublic, MetaverseMarket.MetaverseMarketCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        emit ContractInitialized()
	}
}
 