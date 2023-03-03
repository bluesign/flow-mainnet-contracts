// import NonFungibleToken from "./NonFungibleToken.cdc"   
// import NonFungibleToken from 0x631e88ae7f1d7c20 // Testnet
import NonFungibleToken from 0x1d7e57aa55817448 // Mainnet
// import MetadataViews from "./MetadataViews.cdc"
// import MetadataViews from 0x631e88ae7f1d7c20 // Testnet
import MetadataViews from 0x1d7e57aa55817448 // Mainnet

// KreatrItems
// NFT items for ArtWork!
//
pub contract KreatrItems: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(
        id: UInt64, 
        slug: String,
        thumbnailUri: String,
        typeID: UInt64,    
        supply: UInt64, 
        uri: String, 
        creatorRoyalties: {String: UFix64}?
        )

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupply
    // The total number of KreatrItems that have been minted
    //
    pub var totalSupply: UInt64

    // Rarity -> Price mapping
    // pub var itemRarityPriceMap: {UInt64: UFix64}

    // NFT
    // A Kreatr Item as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // The token's ID
        pub let id: UInt64
        // The token's slug
        pub let slug: String
        // The uri to public thumbnail
        pub let thumbnailUri: String
        // The token's type, e.g. 1 == Digital 2 == Physical 3 == Hybrid
        pub let typeID: UInt64
        // The token's supply
        pub let supply: UInt64
        // The uri holding the metadata. We def want to make this part of the blockchain
        pub let uri: String
        // The dictionary of creators with GUID and royalties percentage
        access(self) var creatorRoyalties: {String: UFix64}?

        // initializer
        init(
            initID: UInt64,
            initSlug: String,
            initThumbnailUri: String,
            initTypeID: UInt64,
            initSupply: UInt64,
            initUri: String,
            initCreatorRoyalties: {String: UFix64}? // {creatorGUID: royaltyDistributionAsPercent}
            ) {
            self.id = initID
            self.slug = initSlug
            self.thumbnailUri = initThumbnailUri
            self.typeID = initTypeID
            self.supply = initSupply
            self.uri = initUri
            self.creatorRoyalties = initCreatorRoyalties
        }

        pub fun description(): String {
            return "A "
                .concat("piece of created art called")
                .concat(self.slug)
                .concat(" with id ")
                .concat(self.id.toString())
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
                        name: self.slug,
                        description: self.description(),
                        thumbnail: MetadataViews.HTTPFile(self.thumbnailUri)
                    )
            }

            return nil
        }
    }

    // This is the interface that users can cast their KreatrItems Collection as
    // to allow others to deposit KreatrItems into their Collection. It also allows for reading
    // the details of KreatrItems in the Collection.
    pub resource interface KreatrItemsCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowKreatrItem(id: UInt64): &KreatrItems.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow KreatrItem reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of KreatrItem NFTs owned by an account
    //
    pub resource Collection: KreatrItemsCollectionPublic,  NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection  {
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
            let token <- token as! @KreatrItems.NFT

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

        // borrowKreatrItem
        // Gets a reference to an NFT in the collection as a KreatrItem,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the KreatrItem.
        //
        pub fun borrowKreatrItem(id: UInt64): &KreatrItems.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &KreatrItems.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let kreatrItem = nft as! &KreatrItems.NFT
            return kreatrItem as &AnyResource{MetadataViews.Resolver}
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
            typeID: UInt64, 
            slug: String, 
            thumbnailUri: String, 
            supply: UInt64, 
            uri: String, 
            creatorRoyalties: {String: UFix64}?): @NFT {
            KreatrItems.totalSupply = KreatrItems.totalSupply + 1
            var newNFT <- create NFT(
                initID: KreatrItems.totalSupply, 
                initSlug: slug, 
                initThumbnailUri: thumbnailUri,initTypeID: typeID, 
                initSupply: supply, 
                initUri: uri, 
                initCreatorRoyalties: creatorRoyalties)
            emit Minted(
                id: KreatrItems.totalSupply, 
                slug: slug,
                thumbnailUri: thumbnailUri,
                typeID: typeID, 
                supply: supply, 
                uri: uri, 
                creatorRoyalties: creatorRoyalties)
            
            return <-newNFT
		}
	}

    // fetch
    // Get a reference to a KreatrItem from an account's Collection, if available.
    // If an account does not have a KreatrItems.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &KreatrItems.NFT? {
        let collection = getAccount(from)
            .getCapability(KreatrItems.CollectionPublicPath)!
            .borrow<&KreatrItems.Collection{KreatrItems.KreatrItemsCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust KreatrItems.Collection.borowKreatrItem to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowKreatrItem(id: itemID)
    }

    // initializer
    //
	init() {
        // set rarity price mapping
        // self.itemRarityPriceMap = {
        //     1: 125.0,
        //     2: 25.0,
        //     3: 5.0,
        //     4: 1.0
        // }

        // Set our named paths
        self.CollectionStoragePath = /storage/KreatrItemsCollectionV9
        self.CollectionPublicPath = /public/KreatrItemsCollectionV9
        self.MinterStoragePath = /storage/KreatrItemsMinterV9

        // Initialize the total supply
        self.totalSupply = 0

       

        // store an empty NFT Collection in account storage
        self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)

        // publish a reference to the Collection in storage
        self.account.link<&{KreatrItemsCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

         // Create a Minter resource and save it to storage
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)

        emit ContractInitialized()
	}
}
 