import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract PlayTodayNFT: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, creator: Address, rarity: UInt8, uri: String, name: String, description: String)
    pub event Destroy(id: UInt64)
    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath


    // totalSupply
    // The total number of PlayTodayNFT that have been minted
    //
    pub var totalSupply: UInt64

    pub enum Rarity: UInt8 {
        pub case collector
        pub case platinum
    }

    pub fun rarityToString(_ rarity: Rarity): String {
        switch rarity {
            case Rarity.collector:
                return "Collector"
            case Rarity.platinum:
                return "Platinum"
        }
        return ""
    }

    // A Play Today NFT as an NFT
    //  
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        // The token rarity (e.g. Normal or Platinum)
        pub let creator: Address
        pub let rarity: Rarity
        pub let uri: String
        pub let name: String
        pub let description: String
        access(self) let royalties: [MetadataViews.Royalty]
        access(self) let metadata: {String: AnyStruct}
        
        init(id: UInt64, creator: Address, rarity: Rarity,  uri: String, name:String, description:String, royalties: [MetadataViews.Royalty], metadata: {String: AnyStruct},) {  
            self.id = id
            self.creator = creator
            self.rarity = rarity
            self.uri = uri
            self.name = name
            self.description = description
            self.royalties = royalties
            self.metadata = metadata
        }

 
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                )
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://ipfs.filebase.io/ipfs/".concat(self.uri)
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://playtodaynft.com/nft/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: PlayTodayNFT.CollectionStoragePath,
                        publicPath: PlayTodayNFT.CollectionPublicPath,
                        providerPath: /private/playTodayNFTCollection,
                        publicCollection: Type<&PlayTodayNFT.Collection{PlayTodayNFT.PlayTodayNFTCollectionPublic}>(),
                        publicLinkedType: Type<&PlayTodayNFT.Collection{PlayTodayNFT.PlayTodayNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&PlayTodayNFT.Collection{PlayTodayNFT.PlayTodayNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-PlayTodayNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://s3.ap-southeast-2.amazonaws.com/files.playtoday.cc/PT_NFT_B.jpg"
                        ),
                        mediaType: "image/svg+xml"
                    )

                    let squareMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://s3.ap-southeast-2.amazonaws.com/files.playtoday.cc/PT_NFT_B.jpg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Play Today Collection",
                        description: "PlayToday.NFT is the world's first Web3 golf project developed with Players for the Players.",
                        externalURL: MetadataViews.ExternalURL("https://playtodaynft.com"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/PlayTodayNFT"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/playtoday.nft/"),
                            "discord": MetadataViews.ExternalURL("https://discord.gg/6H3J85UU"),
                            "facebook": MetadataViews.ExternalURL("https://www.facebook.com/playtodaynft"),
                            "linkedin":MetadataViews.ExternalURL("https://www.linkedin.com/company/playtodaygolf")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits
                    let excludedTraits = ["mintedTime"]
                    let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: excludedTraits)

                    // mintedTime is a unix timestamp, we should mark it with a displayType so platforms know how to show it.
                    let mintedTimeTrait = MetadataViews.Trait(name: "mintedTime", value: self.metadata["mintedTime"]!, displayType: "Date", rarity: nil)
                    traitsView.addTrait(mintedTimeTrait)
                    
                    return traitsView
            }
      
            
            return nil
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }
    // This is the interface that users can cast their PlayTodayNFT Collection as
    // to allow others to deposit PlayTodayNFT into their Collection. It also allows for reading
    // the details of PlayTodayNFT in the Collection.
    pub resource interface PlayTodayNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowPlayTodayNFT(id: UInt64): &PlayTodayNFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow PlayTodayNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of PlayTodayNFT NFTs owned by an account
    //
    pub resource Collection: PlayTodayNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @PlayTodayNFT.NFT
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

        // borrowPlayTodayNFT
        // Gets a reference to an NFT in the collection as a PlayTodayNFT,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the PlayTodayNFT.
        //
        pub fun borrowPlayTodayNFT(id: UInt64): &PlayTodayNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &PlayTodayNFT.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let playTodayNFT = nft as! &PlayTodayNFT.NFT
            return playTodayNFT as &AnyResource{MetadataViews.Resolver}
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
            creator: Address,
            rarity: Rarity,
            uri: String,
            name: String,
            description: String,
            royalties: [MetadataViews.Royalty]
        ) {
            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp
            metadata["minter"] = recipient.owner!.address
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create PlayTodayNFT.NFT(
                id: PlayTodayNFT.totalSupply, 
                creator: creator, 
                rarity: rarity,
                uri:uri,
                name: name,
                description: description,
                royalties: royalties,
                metadata: metadata
                ))

            emit Minted(
                id: PlayTodayNFT.totalSupply, 
                creator: creator, 
                rarity: rarity.rawValue,
                uri:uri,
                name: name,
                description: description,
            )
            PlayTodayNFT.totalSupply = PlayTodayNFT.totalSupply + (1 as UInt64)
        }
    }
    // fetch
    // Get a reference to a PlayTodayNFT from an account's Collection, if available.
    // If an account does not have a PlayTodayNFT.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &PlayTodayNFT.NFT? {
        let collection = getAccount(from)
            .getCapability(PlayTodayNFT.CollectionPublicPath)!
            .borrow<&PlayTodayNFT.Collection{PlayTodayNFT.PlayTodayNFTCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust PlayTodayNFT.Collection.borowPlayTodayNFT to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowPlayTodayNFT(id: itemID)
    }

    // initializer
    //
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/playTodayNFTCollection
        self.CollectionPublicPath = /public/playTodayNFTCollection
        self.MinterStoragePath = /storage/playTodayNFTMinter

        // Initialize the total supply
        self.totalSupply = 0

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)
        // self.account.link<&NFTMinter>(self.MinterPublicPath, target: self.MinterStoragePath)

        // create a public capability for the collection
        self.account.link<&PlayTodayNFT.Collection{NonFungibleToken.CollectionPublic, PlayTodayNFT.PlayTodayNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )
        self.account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        
        emit ContractInitialized()
    }
}
 