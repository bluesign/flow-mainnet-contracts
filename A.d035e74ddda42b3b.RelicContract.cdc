/*******************************************/
// Modern Musician Relic Contract v.0.1.1
// developed by info@spaceleaf.io
/*******************************************/

import NonFungibleToken from 0xd035e74ddda42b3b
import MetadataViews from 0xd035e74ddda42b3b

pub contract RelicContract: NonFungibleToken {

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, rarity: String, creatorName: String)
    pub event Transfer(id: UInt64, from: Address?, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub var totalSupply: UInt64
    pub var bronzeSupply: UInt64
    pub var silverSupply: UInt64
    pub var goldSupply: UInt64
    pub var platinumSupply: UInt64
    pub var diamondSupply: UInt64   

    pub let idMap: { String : UInt64 }

    pub fun getTotalSupply(): [UInt64] {
        var supplies: [UInt64] = [ 
            RelicContract.bronzeSupply,  
            RelicContract.silverSupply,  
            RelicContract.goldSupply,  
            RelicContract.platinumSupply,  
            RelicContract.diamondSupply,
            RelicContract.totalSupply 
        ]
        return supplies
    }

    pub fun getRelicId(_relicId: String): UInt64? {
        return RelicContract.idMap[_relicId]
    }

    pub resource Relic: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let creatorId: String
        pub let relicId: String
        pub let rarity: String
        pub let category: String
        pub let type: String
        pub let creatorName: String
        pub let title: String
        pub let description: String
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
            _creatorId: String, 
            _relicId: String, 
            _rarity: String, 
            _category: String,  
            _type: String, 
            _creatorName: String,
            _title: String, 
            _description: String, 
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
            self.creatorId = _creatorId
            self.relicId = _relicId
            self.rarity = _rarity
            self.category = _category
            self.type = _type
            self.creatorName = _creatorName
            self.title = _title
            self.description = _description
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
        
        pub fun updateAssetVideoURL(_newAssetVideoURL: String) {
            self.assetVideoURL = _newAssetVideoURL
        }

        pub fun updateAssetImageURL(_newAssetImageURL: String) {
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
            return self.creatorName.concat(" - ").concat(self.title)
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
                        thumbnail: self.assetImageURL,
                        id: self.id,
                        category: self.category,
                        rarity: self.rarity,
                        type: self.type,
                        creatorName: self.creatorName,
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
                        self.id
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
            let token <- self.ownedRelics.remove(key: withdrawID) ?? panic("Relic not found.")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.Relic) {
            let relic <- token as! @RelicContract.Relic
            emit Deposit(id: relic.id, to: self.owner?.address)
            self.ownedRelics[relic.id] <-! relic
        }

        pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
            let token <- self.ownedRelics.remove(key: id) ?? panic("Relic not found.")
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
            _id: UInt64,
            _creatorId: String,
            _relicId: String,
            _rarity: String, 
            _category: String, 
            _type: String, 
            _creatorName: String,
            _title: String, 
            _description: String, 
            _edition: UInt64,
            _editionSize: UInt64,
            _mintDate: String, 
            _assetVideoURL: String, 
            _assetImageURL: String, 
            _musicURL: String, 
            _artworkURL: String,
            _royalties: [MetadataViews.Royalty]
        )      {
            switch _rarity {
                case "Bronze":
                        recipient.deposit(token: <- create RelicContract.Relic(
                            initID: _id, 
                            creatorId: _creatorId,
                            relicId: _relicId,
                            rarity: _rarity,
                            category: _category,
                            type:_type,
                            creatorName: _creatorName,
                            title: _title, 
                            description: _description, 
                            edition: _edition, 
                            editionSize: _editionSize, 
                            mintDate: _mintDate, 
                            assetVideoURL: _assetVideoURL, 
                            assetImageURL: _assetImageURL,
                            musicURL: _musicURL, 
                            artworkURL: _artworkURL,
                            royalties: _royalties
                            )
                        )

                        emit Minted(id: RelicContract.totalSupply, rarity: _rarity, creatorName: _creatorName)
                        RelicContract.idMap.insert(key: _relicId, RelicContract.totalSupply)
                        RelicContract.bronzeSupply = RelicContract.bronzeSupply + 1
                        RelicContract.totalSupply = RelicContract.totalSupply + 1
                
                case "Silver":
                    recipient.deposit(token: <- create RelicContract.Relic(
                            initID: _id, 
                            creatorId: _creatorId,
                            relicId: _relicId,
                            rarity: _rarity,
                            category: _category,
                            type:_type,
                            creatorName: _creatorName,
                            title: _title, 
                            description: _description, 
                            edition: _edition, 
                            editionSize: _editionSize, 
                            mintDate: _mintDate, 
                            assetVideoURL: _assetVideoURL, 
                            assetImageURL: _assetImageURL,
                            musicURL: _musicURL, 
                            artworkURL: _artworkURL,
                            royalties: _royalties
                        )
                    )

                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, creatorName: _creatorName)
                    RelicContract.idMap.insert(key: _relicId, RelicContract.totalSupply)
                    RelicContract.silverSupply = RelicContract.silverSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1


                case "Gold":
                    recipient.deposit(token: <-create RelicContract.Relic(
                            initID: _id, 
                            creatorId: _creatorId,
                            relicId: _relicId,
                            rarity: _rarity,
                            category: _category,
                            type:_type,
                            creatorName: _creatorName,
                            title: _title, 
                            description: _description, 
                            edition: _edition, 
                            editionSize: _editionSize, 
                            mintDate: _mintDate, 
                            assetVideoURL: _assetVideoURL, 
                            assetImageURL: _assetImageURL,
                            musicURL: _musicURL, 
                            artworkURL: _artworkURL,
                            royalties: _royalties
                        )
                    )

                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, creatorName: _creatorName)
                    RelicContract.idMap.insert(key: _relicId, RelicContract.totalSupply)
                    RelicContract.goldSupply = RelicContract.goldSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
                

                case "Platinum":
                    recipient.deposit(token: <-create RelicContract.Relic(
                            initID: _id, 
                            creatorId: _creatorId,
                            relicId: _relicId,
                            rarity: _rarity,
                            category: _category,
                            type:_type,
                            creatorName: _creatorName,
                            title: _title, 
                            description: _description, 
                            edition: _edition, 
                            editionSize: _editionSize, 
                            mintDate: _mintDate, 
                            assetVideoURL: _assetVideoURL, 
                            assetImageURL: _assetImageURL,
                            musicURL: _musicURL, 
                            artworkURL: _artworkURL,
                            royalties: _royalties
                        )
                    )
                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, creatorName: _creatorName)
                    RelicContract.idMap.insert(key: _relicId, RelicContract.totalSupply)
                    RelicContract.platinumSupply = RelicContract.platinumSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1


                case "Diamond":
                    recipient.deposit(token: <-create RelicContract.Relic(
                            initID: _id, 
                            creatorId: _creatorId,
                            relicId: _relicId,
                            rarity: _rarity,
                            category: _category,
                            type:_type,
                            creatorName: _creatorName,
                            title: _title, 
                            description: _description, 
                            edition: _edition, 
                            editionSize: _editionSize, 
                            mintDate: _mintDate, 
                            assetVideoURL: _assetVideoURL, 
                            assetImageURL: _assetImageURL,
                            musicURL: _musicURL, 
                            artworkURL: _artworkURL,
                            royalties: _royalties
                        )
                    )
                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, creatorName: _creatorName)
                    RelicContract.idMap.insert(key: _relicId, RelicContract.totalSupply)
                    RelicContract.diamondSupply = RelicContract.diamondSupply + 1
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
            } 
        }

        pub fun resetRarityCounters() {
            RelicContract.bronzeSupply = 0
            RelicContract.silverSupply = 0
            RelicContract.goldSupply = 0
            RelicContract.platinumSupply = 0
            RelicContract.diamondSupply = 0
        }
	}

    init() {
        self.CollectionStoragePath = /storage/RelicCollection
        self.CollectionPublicPath = /public/RelicCollection
        self.MinterStoragePath = /storage/RelicMinter

        self.totalSupply = 0
        self.bronzeSupply = 0
        self.silverSupply = 0
        self.goldSupply = 0
        self.platinumSupply = 0
        self.diamondSupply = 0
        self.idMap = {}

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
 

 











 