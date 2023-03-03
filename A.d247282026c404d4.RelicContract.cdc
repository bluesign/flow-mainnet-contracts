import NonFungibleToken from 0xd247282026c404d4
import MetadataViews from 0xd247282026c404d4

pub contract RelicContract: NonFungibleToken {

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, rarity: String, artistName: String)
    pub event Transfer(id: UInt64, from: Address?, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let ManagerStoragePath: StoragePath

    pub var totalSupply: UInt64
    pub var serialCounter: UInt64 

    pub var bronzeSupply: UInt64
    pub var silverSupply: UInt64
    pub var goldSupply: UInt64
    pub var platinumSupply: UInt64
    pub var diamondSupply: UInt64

    pub var bronzeMaxSupply: UInt64
    pub var silverMaxSupply: UInt64
    pub var goldMaxSupply: UInt64
    pub var platinumMaxSupply: UInt64
    pub var diamondMaxSupply: UInt64
    

   pub fun getTotalSupply(): [UInt64] {
        var supplies: [UInt64] = [ 
            RelicContract.bronzeSupply,  
            RelicContract.silverSupply,  
            RelicContract.goldSupply,  
            RelicContract.platinumSupply,  
            RelicContract.diamondSupply,
            RelicContract.serialCounter,
            RelicContract.totalSupply 
        ]
        return supplies
    }
    
   pub fun getMaxSupply(): [UInt64] {
        var maxSupplies: [UInt64] = [ 
            RelicContract.bronzeMaxSupply,  
            RelicContract.silverMaxSupply,  
            RelicContract.goldMaxSupply,  
            RelicContract.platinumMaxSupply,  
            RelicContract.diamondMaxSupply
        ]
        return maxSupplies
    }

    pub resource Relic: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let rarity: String
        pub let category: String
        pub let type: String
        pub let artistName: String
        pub let title: String
        pub let description: String
        pub let serialNumber: UInt64
        pub let edition: UInt64
        pub let editionSize: UInt64
        pub let mintDate: String
        pub var assetVideoURL: String
        pub var assetImageURL: String
        pub var musicURL: String
        pub var artworkURL: String
        pub var marketDisplay: String

        access(self) let royalties: [MetadataViews.Royalty]

        init(
            _initID: UInt64, 
            _rarity: String, 
            _category: String,  
            _type: String, 
            _artistName: String,
            _title: String, 
            _description: String, 
            _serialNumber: UInt64, 
            _edition: UInt64, 
            _editionSize: UInt64, 
            _mintDate: String, 
            _assetVideoURL: String, 
            _assetImageURL: String, 
            _musicURL: String, 
            _artworkURL: String,
            _royalties: [MetadataViews.Royalty]
        ) {
            self.id = _initID
            self.rarity = _rarity
            self.category = _category
            self.type = _type
            self.artistName = _artistName
            self.title = _title
            self.description = _description
            self.serialNumber = _serialNumber
            self.edition = _edition
            self.editionSize = _editionSize
            self.mintDate = _mintDate
            self.assetVideoURL = _assetVideoURL
            self.assetImageURL = _assetImageURL
            self.musicURL = _musicURL
            self.artworkURL = _artworkURL
            self.marketDisplay = _assetImageURL
            self.royalties = _royalties
        }
        
        pub fun updateVideoURL(_newAssetVideoURL: String) {
            self.assetVideoURL = _newAssetVideoURL
        }

        pub fun updateAssetURL(_newAssetImageURL: String) {
            self.assetImageURL = _newAssetImageURL
        }

        pub fun updateMusicURL(_newMusicURL: String) {
            self.musicURL = _newMusicURL
        }

        pub fun updateArtworkURL(_newArtworkURL: String) {
            self.artworkURL = _newArtworkURL
        }

        pub fun updateMarketDisplay(_newURL: String) {
            self.marketDisplay = _newURL
        }
    
        pub fun updateMediaURLs(_newAssetVideoURL: String, _newAssetImageURL: String, _newMusicURL: String, _newArtworkURL: String ) {
            self.assetVideoURL = _newAssetVideoURL
            self.assetImageURL = _newAssetImageURL
            self.musicURL = _newMusicURL
            self.artworkURL = _newArtworkURL
        }

        pub fun name(): String {
            return self.artistName.concat(" - ").concat(self.title)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Identity>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
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
                        name: self.name(),
                        description: self.description,
                        thumbnail: self.artworkURL,
                        id: self.id,
                        category: self.category,
                        rarity: self.rarity,
                        type: self.type,
                        artistName: self.artistName,
                        title: self.title,
                        mintDate: self.mintDate,
                        assetVideoURL: self.assetVideoURL,
                        assetImageURL: self.assetImageURL,
                        musicURL: self.musicURL,
                        artworkURL: self.artworkURL
                    )
                case Type<MetadataViews.Identity>():
                    return MetadataViews.Identity(
                        uuid: self.uuid
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(": https://www.musicrelics.com/".concat(self.id.toString()))

                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(name: self.rarity, number: self.edition, max: self.editionSize)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )

                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.serialNumber
                    )

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: RelicContract.CollectionStoragePath,
                        publicPath: RelicContract.CollectionPublicPath,
                        providerPath: /private/RelicContractCollection,
                        publicCollection: Type<&RelicContract.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        publicLinkedType: Type<&RelicContract.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&RelicContract.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-RelicContract.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let video = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: self.marketDisplay
                        ),
                        mediaType: "video/image"
                    )
                    let image = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: self.artworkURL
                        ),
                        mediaType: "image" 
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: self.name(),
                        description: self.description,
                        externalURL: MetadataViews.ExternalURL("https://www.musicrelics.com/"),
                        squareImage: video,
                        bannerImage: image,
                        socials: {
                           
                        }
                    )
            }

            return nil
        }
    }

    pub resource interface RelicCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.Relic)
        pub fun getIDs(): [UInt64]
        pub fun borrowRelic(id: UInt64): &NonFungibleToken.Relic
        pub fun borrowRelicSpecific(id: UInt64): &Relic
    }


    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, RelicCollectionPublic {
        pub var ownedRelics: @{UInt64: NonFungibleToken.Relic}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.Relic {
            let token <- self.ownedRelics.remove(key: withdrawID) ?? panic("missing Relic")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.Relic) {
            let relic <- token as! @RelicContract.Relic
            emit Deposit(id: relic.id, to: self.owner?.address)
            self.ownedRelics[relic.id] <-! relic
        }

        pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
            let token <- self.ownedRelics.remove(key: id) ?? panic("missing Relic")
            recipient.deposit(token: <- token)

            emit Transfer(id: id, from: self.owner?.address, to: recipient.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedRelics.keys
        }

        pub fun borrowRelic(id: UInt64): &NonFungibleToken.Relic {
            return (&self.ownedRelics[id] as &NonFungibleToken.Relic?)!
        }

        pub fun borrowRelicSpecific(id: UInt64): &Relic {
            let ref = (&self.ownedRelics[id] as auth &NonFungibleToken.Relic?)!
            return ref as! &Relic
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let relic = (&self.ownedRelics[id] as auth &NonFungibleToken.Relic?)!
            let getRelic = relic as! &Relic
            return getRelic
        }

        destroy() {
            destroy self.ownedRelics
        }

        init () {
            self.ownedRelics <- {}
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

	pub resource RelicMinter {
		pub fun mintRelic(
            recipient: &{NonFungibleToken.CollectionPublic}, 
            _rarity: String, 
            _category: String, 
            _type: String, 
            _artistName: String,
            _title: String, 
            _description: String, 
            _mintDate: String, 
            _assetVideoURL: String, 
            _assetImageURL: String, 
            _musicURL: String, 
            _artworkURL: String,
            _royalties: [MetadataViews.Royalty]
        )      {
            
            switch _rarity {
                case "Bronze":
                    if (RelicContract.bronzeSupply < RelicContract.bronzeMaxSupply) 
                    {
                        recipient.deposit(token: <- create RelicContract.Relic(
                            initID: RelicContract.totalSupply, 
                            rarity: _rarity,
                            category: _category,
                            type:_type,
                            artistName: _artistName,
                            title: _title, 
                            description: _description, 
                            serialNumber: RelicContract.serialCounter + 1, 
                            edition: RelicContract.bronzeSupply + 1, 
                            editionSize: RelicContract.bronzeMaxSupply, 
                            mintDate: _mintDate, 
                            assetVideoURL: _assetVideoURL, 
                            assetImageURL: _assetImageURL,
                            musicURL: _musicURL, 
                            artworkURL: _artworkURL,
                            royalties: _royalties
                            )
                        )

                        RelicContract.bronzeSupply = RelicContract.bronzeSupply + 1
                        RelicContract.totalSupply = RelicContract.totalSupply + 1
                        RelicContract.serialCounter = RelicContract.serialCounter + 1
                        emit Minted(id: RelicContract.totalSupply, rarity: _rarity, artistName: _artistName)
                    } else {
                        log("Bronze Mint attempted but failed, Max Supply exceeded")
                    }
                
                case "Silver":
                if (RelicContract.silverSupply < RelicContract.silverMaxSupply) 
                {
                    recipient.deposit(token: <- create RelicContract.Relic(
                        initID: RelicContract.totalSupply, 
                        rarity: _rarity,
                        category: _category,
                        type:_type,
                        artistName: _artistName,
                        title: _title, 
                        description: _description, 
                        serialNumber: RelicContract.serialCounter + 1, 
                        edition: RelicContract.silverSupply + 1, 
                        editionSize: RelicContract.silverMaxSupply, 
                        mintDate: _mintDate, 
                        assetVideoURL: _assetVideoURL, 
                        assetImageURL: _assetImageURL,
                        musicURL: _musicURL, 
                        artworkURL: _artworkURL,
                        royalties: _royalties
                        )
                    )

                    RelicContract.silverSupply = RelicContract.silverSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
                    RelicContract.serialCounter = RelicContract.serialCounter + 1
                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, artistName: _artistName)
                } else {
                    log("Silver Mint attempted but failed, Max Supply exceeded")
                }

                case "Gold":
                if (RelicContract.goldSupply < RelicContract.goldMaxSupply) 
                {
                    recipient.deposit(token: <-create RelicContract.Relic(
                        initID: RelicContract.totalSupply, 
                        rarity: _rarity,
                        category: _category,
                        type:_type,
                        artistName: _artistName,
                        title: _title, 
                        description: _description, 
                        serialNumber: RelicContract.serialCounter + 1, 
                        edition: RelicContract.goldSupply + 1, 
                        editionSize: RelicContract.goldMaxSupply, 
                        mintDate: _mintDate, 
                        assetVideoURL: _assetVideoURL, 
                        assetImageURL: _assetImageURL,
                        musicURL: _musicURL, 
                        artworkURL: _artworkURL,
                        royalties: _royalties
                        )
                    )

                    RelicContract.goldSupply = RelicContract.goldSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
                    RelicContract.serialCounter = RelicContract.serialCounter + 1
                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, artistName: _artistName)
                } else {
                    log("Gold Mint attempted but failed, Max Supply exceeded")
                }

                case "Platinum":
                if (RelicContract.platinumSupply < RelicContract.platinumMaxSupply) 
                {
                    recipient.deposit(token: <-create RelicContract.Relic(
                        initID: RelicContract.totalSupply, 
                        rarity: _rarity,
                        category: _category,
                        type:_type,
                        artistName: _artistName,
                        title: _title, 
                        description: _description, 
                        serialNumber: RelicContract.serialCounter + 1, 
                        edition: RelicContract.platinumSupply + 1, 
                        editionSize: RelicContract.platinumMaxSupply, 
                        mintDate: _mintDate, 
                        assetVideoURL: _assetVideoURL, 
                        assetImageURL: _assetImageURL,
                        musicURL: _musicURL, 
                        artworkURL: _artworkURL,
                        royalties: _royalties
                        )
                    )

                    RelicContract.platinumSupply = RelicContract.platinumSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
                    RelicContract.serialCounter = RelicContract.serialCounter + 1
                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, artistName: _artistName)
                } else {
                    log("Platinum Mint attempted but failed, Max Supply exceeded")
                }

                case "Diamond":
                if (RelicContract.diamondSupply < RelicContract.diamondMaxSupply) 
                {
                    recipient.deposit(token: <-create RelicContract.Relic(
                        initID: RelicContract.totalSupply, 
                        rarity: _rarity,
                        category: _category,
                        type:_type,
                        artistName: _artistName,
                        title: _title, 
                        description: _description, 
                        serialNumber: RelicContract.serialCounter + 1, 
                        edition: RelicContract.diamondSupply + 1, 
                        editionSize: RelicContract.diamondMaxSupply, 
                        mintDate: _mintDate, 
                        assetVideoURL: _assetVideoURL, 
                        assetImageURL: _assetImageURL,
                        musicURL: _musicURL, 
                        artworkURL: _artworkURL,
                        royalties: _royalties
                        )
                    )

                    RelicContract.diamondSupply = RelicContract.diamondSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
                    RelicContract.serialCounter = RelicContract.serialCounter + 1
                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, artistName: _artistName)
                } else {
                    log("Diamond Mint attempted but failed, Max Supply exceeded")
                }
            } 
        }

        pub fun resetRarityCounters() {
            RelicContract.bronzeSupply = 0
            RelicContract.silverSupply = 0
            RelicContract.goldSupply = 0
            RelicContract.platinumSupply = 0
            RelicContract.diamondSupply = 0
            RelicContract.serialCounter = 0
        }

        pub fun updateMaxSupplies(_bronze: UInt64, _silver: UInt64,  _gold: UInt64,  _platinum: UInt64,  _diamond: UInt64) {
            RelicContract.bronzeMaxSupply = _bronze
            RelicContract.silverMaxSupply = _silver
            RelicContract.goldMaxSupply = _gold
            RelicContract.platinumMaxSupply = _platinum
            RelicContract.diamondMaxSupply = _diamond
        }

        pub fun setSerialCounter(_number: UInt64) {
            RelicContract.serialCounter = _number
        }

	}


    init() {

        self.CollectionStoragePath = /storage/RelicCollection
        self.CollectionPublicPath = /public/RelicCollection
        self.MinterStoragePath = /storage/RelicMinter
        self.ManagerStoragePath = /storage/RelicManager

        self.totalSupply = 0
        self.bronzeSupply = 0
        self.silverSupply = 0
        self.goldSupply = 0
        self.platinumSupply = 0
        self.diamondSupply = 0

        self.bronzeMaxSupply = 500
        self.silverMaxSupply = 250
        self.goldMaxSupply = 100
        self.platinumMaxSupply = 10
        self.diamondMaxSupply = 1
        self.serialCounter = 0

        let minter <- create RelicMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        let collection <- RelicContract.createEmptyCollection()
        self.account.save(<-collection, to: RelicContract.CollectionStoragePath)

        self.account.link<&RelicContract.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, RelicCollectionPublic}>(
            self.CollectionPublicPath, 
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
 

 











 