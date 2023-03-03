
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe


pub contract TopTCollection2: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event WithdrawBadge(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event DepositBadge(id: UInt64, to: Address?)
    pub event Minted(id: UInt64,name:String,to: Address)
    pub event MintedBadge(id: UInt64,name:String)
    
    
    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath


    pub var totalSupplyBadges: UInt64
    pub var totalSupply: UInt64

    

    pub struct Metadata {
		
		pub let artistAddress:Address
		pub let storageRef: String
        pub let caption: String
		init(
		
		artistAddress:Address, 
        storagePath: String, 
        caption: String
		) {
			self.artistAddress=artistAddress
            self.storageRef = storagePath
            self.caption = caption
			
		}

	}

    
    pub struct ArtData {
		pub let metadata: TopTCollection2.Metadata
		pub let id: UInt64
		
		init(metadata: TopTCollection2.Metadata, id: UInt64) {
			self.metadata= metadata
			self.id=id
			
		}
	}
    pub enum Kind: UInt8 {
        pub case Cooking
        pub case Dancing
        pub case Singing
        
    }
    pub fun kindToStoragePath(_ kind: Kind): String {
        switch kind {
            case Kind.Cooking:
                return "Cooking"
            case Kind.Dancing:
                return "Dancing"
            case Kind.Singing:
                return "Singing"
        }

        return ""
    }
    pub fun kindToString(_ kind: Kind): String {
        switch kind {
            case Kind.Cooking:
                return "Cooking"
            case Kind.Dancing:
                return "Dancing"
            case Kind.Singing:
                return "Singing"
        }

        return ""
    }
    // pub struct BadgeData {
    //     pub let id: UInt64
	// 	pub let kind: Kind
    //     pub let storagePath:String
    //     pub let royalty: MetadataViews.Royalty
		
	// 	init(
    //     id: UInt64,
    //     kind: Kind,
    //     storagePath:String,
    //     royalty: MetadataViews.Royalty

    //     ) {
	// 		self.id=id
    //         self.kind = kind
    //         self.storagePath = storagePath
    //         self.royalty = royalty
			
	// 	}
	// }
    
    pub resource BADGE: NonFungibleToken.INFT{
        pub let id: UInt64
        pub let kind: Kind
        pub let marketRoyalty: MetadataViews.Royalty

        init(
            initID: UInt64,
            kind:Kind,
            marketRoyalty: MetadataViews.Royalty

        ){
            self.id = initID
            self.kind = kind
            self.marketRoyalty = marketRoyalty
        }
        // pub fun getBadgeData(): {
        //         return TopTCollection.BadgeData(id: self.id,kind:self.kind,storagePath:self.storagePath,royalty:self.royalty)
        // }
    }   

    pub resource NFT: NonFungibleToken.INFT,MetadataViews.Resolver {

        pub let id: UInt64
        pub let metadata: Metadata

        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let royalties: [MetadataViews.Royalty]
        // Initialize both fields in the init function
        init(
        initID: UInt64,
        metadata: Metadata,
        name: String,
        description: String,
        thumbnail: String,
        royalties: [MetadataViews.Royalty]
        ) {
            
            self.id = initID
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
            self.metadata = metadata
        }

        
        
        pub fun getArtData(): TopTCollection2.ArtData {
                return TopTCollection2.ArtData(metadata: self.metadata, id: self.id)
        }

    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata.storageRef
                        )
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
                    return MetadataViews.ExternalURL(self.metadata.storageRef)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: TopTCollection2.CollectionStoragePath,
                        publicPath: TopTCollection2.CollectionPublicPath,
                        providerPath: /private/topTNFTCollection,
                        publicCollection: Type<&TopTCollection2.Collection{TopTCollection2.TopTCollectionPublic}>(),
                        publicLinkedType: Type<&TopTCollection2.Collection{TopTCollection2.TopTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&TopTCollection2.Collection{TopTCollection2.TopTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-TopTCollection2.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: self.metadata.storageRef
                        ),
                        mediaType: "mp4"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The TopT Collection",
                        description: self.description,
                        externalURL: MetadataViews.ExternalURL(self.metadata.storageRef),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                        }
                    )
            }
            return nil
        }
}

    // This is the interface that users can cast their KittyItems Collection as
    // to allow others to deposit KittyItems into their Collection. It also allows for reading
    // the details of KittyItems in the Collection.
    pub resource interface TopTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun depositBadge(token: @TopTCollection2.BADGE)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowBADGE(): &BADGE?
        pub fun borrowToptItem(id: UInt64): &TopTCollection2.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow TopTItem reference: The ID of the returned reference is incorrect"
            }
        }
    }
    pub resource interface BadgeReceiver {

        // deposit takes an NFT as an argument and adds it to the Collection
        //
        pub fun depositBadge(token: @BADGE)
        pub fun isExists(): Bool

    }

    pub resource interface BadgeProvider {
        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdrawBadge(): @BADGE 
        
    }
    // Collection
    // A collection of KittyItem NFTs owned by an account
    //
    pub resource Collection: TopTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, BadgeProvider, BadgeReceiver{
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var badge: @BADGE?
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        
        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }
        
        pub fun withdrawBadge(): @BADGE {
            pre{
                self.badge != nil: "There's no badge" 
            }
            let id = self.borrowBADGE()!.id
            let token <- self.badge <- nil 
            // let id = token.id
            emit WithdrawBadge(id: id, from: self.owner?.address)

            return <-token!
            // post{
            //     self.badge == nil ?? panic()
            // }
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @TopTCollection2.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun depositBadge(token: @BADGE) {
            pre{
                self.badge == nil : "Can only have one badge at a time!!!" 
            }
            let token <- token as! @TopTCollection2.BADGE

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.badge <- token

            emit DepositBadge(id: id, to: self.owner?.address)

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
        pub fun isExists(): Bool {
            return self.badge != nil
        }
        // borrowKittyItem
        // Gets a reference to an NFT in the collection as a KittyItem,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the KittyItem.
        //
        pub fun borrowToptItem(id: UInt64): &TopTCollection2.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &TopTCollection2.NFT
            } else {
                return nil
            }
        }
        
        pub fun borrowBADGE(): &TopTCollection2.BADGE? {
            if self.badge != nil {
            let ref = (&self.badge as auth &TopTCollection2.BADGE?)!
            return ref as! &TopTCollection2.BADGE
            }
            else{
                return nil
            }
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
            destroy self.badge
        }

        // initializer
        //
        init () {
            self.badge <- nil
            self.ownedNFTs <- {}
        }
    
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let topTNFT = nft as! &TopTCollection2.NFT
            return topTNFT as &AnyResource{MetadataViews.Resolver}        }
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
        pub fun mintBADGE(
            recipient: &{TopTCollection2.TopTCollectionPublic}, 
            kind: Kind,
            marketRoyalty: MetadataViews.Royalty

        ) {
            pre{
                recipient.borrowBADGE() == nil: "Can only have one badge at a time!!!"
            }
            let marketWalletCap = getAccount(0xf8d6e0586b0a20c7).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

            // deposit it in the recipient's account using their reference
            recipient.depositBadge(token: <-create TopTCollection2.BADGE(
                id: TopTCollection2.totalSupplyBadges,
                kind: kind,
                marketRoyalty:  MetadataViews.Royalty(marketWalletCap,0.1,"Market")
                ))

            emit MintedBadge(
                id: TopTCollection2.totalSupplyBadges,
                name: TopTCollection2.kindToString(kind),
                
            )

            TopTCollection2.totalSupplyBadges = TopTCollection2.totalSupplyBadges + (1 as UInt64)
        }
        

}
    // fetch
    // Get a reference to a KittyItem from an account's Collection, if available.
    // If an account does not have a KittyItems.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &TopTCollection2.NFT? {
        let collection = getAccount(from)
            .getCapability(TopTCollection2.CollectionPublicPath)
            .borrow<&TopTCollection2.Collection{TopTCollection2.TopTCollectionPublic}>()
            ?? panic("Couldn't get collection") 
        // We trust KittyItems.Collection.borowKittyItem to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowToptItem(id: itemID)
    }

     pub fun mintNFT(name:String,description: String ,caption: String ,storagePath: String , artistAddress: Address,royalties: [MetadataViews.Royalty],thumbnail: String) : @TopTCollection2.NFT {       
        let marketWalletCap = getAccount(0xf8d6e0586b0a20c7).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
		var newNFT <- create NFT(
			initID: TopTCollection2.totalSupply,
            metadata: Metadata(
				artistAddress: artistAddress,
                storagePath: storagePath,
                caption: caption,
			),
            name: name,
            description: description,
            thumbnail: thumbnail,
            royalties: royalties.concat([MetadataViews.Royalty(marketWalletCap,0.1,"Market")]
),
		)
		emit Minted(id: TopTCollection2.totalSupply,name:name, to: artistAddress)

		TopTCollection2.totalSupply = TopTCollection2.totalSupply + UInt64(1)
		return <- newNFT
	}
    pub fun getBadge(address:Address) : &TopTCollection2.BADGE? {

		
		
		if let artCollection = getAccount(address).getCapability(self.CollectionPublicPath).borrow<&{TopTCollection2.TopTCollectionPublic}>()  {
        return artCollection.borrowBADGE()  
		}
		return nil
	} 
    pub fun getArt(address:Address) : [ArtData] {

		var artData: [ArtData] = []
		

		if let artCollection = getAccount(address).getCapability(self.CollectionPublicPath).borrow<&{TopTCollection2.TopTCollectionPublic}>()  {
			for id in artCollection.getIDs() {
				var art=artCollection.borrowToptItem(id: id) 
                    ?? panic("ddd")
				artData.append(ArtData( metadata: art.metadata, id: id, ))
			}
		}
		return artData
	} 

    // initializer
    //
    init() {
       

        
        self.totalSupply = 0
        self.totalSupplyBadges = 0
		self.CollectionPublicPath=/public/TopTArtCollection
		self.CollectionStoragePath=/storage/TopTArtCollection
        self.MinterStoragePath = /storage/TopTBadgesMinterV1
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        // Create a Minter resource and save it to storage
        
        emit ContractInitialized()
    }
    
}