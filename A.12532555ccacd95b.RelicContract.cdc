/*******************************************
Modern Musician Relic Contract v.0.1.2
description: This smart contract functions as the main Modern Musician NFT ('Relic') production contract.
It follows Flow's NonFungibleToken standards with customizations to the NonFungibleToken.NFT defition as 
well as a custom MetadataViews implementation.
developed by info@spaceleaf.io
*******************************************/

import NonFungibleToken from 0x12532555ccacd95b
import MetadataViews from 0x12532555ccacd95b

pub contract RelicContract: NonFungibleToken {

    // define events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, rarity: String, creatorName: String)
    pub event Transfer(id: UInt64, from: Address?, to: Address?)

    // define storage paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // track total supply of Relics
    pub var totalSupply: UInt64

    // maps all relics to creatorId->  creatorId : [relicId]
    access(self) var creatorRelicMap: { String : [String] }
    // maps all editions by relicId-> relicId : [editions]
    access(self) var relicEditionMap: { String : [UInt64] }
    // maps all editions by creatorId-> creatorId : [editions]
    access(self) var creatorEditionMap: { String : [UInt64] }

    // returns total supply
    pub fun getTotalSupply(): UInt64 {
        return RelicContract.totalSupply
    }

    // mapping of RelicIds produced by CreatorId, returns an array of Strings or nil
    pub fun getRelicsByCreatorId(_creatorId: String): [String]? {
        return RelicContract.creatorRelicMap[_creatorId]
    }

    // mapping of Edition ids by relicId, returns an array of UInt64 or nil
    pub fun getEditionsByRelicId(_relicId: String): [UInt64]? {
        return RelicContract.relicEditionMap[_relicId]
    }

    // mapping of Editions by creatorId, returns an array of UInt64 or nil
    pub fun getEditionsByCreatorId(_creatorId: String): [UInt64]? {
        return RelicContract.creatorEditionMap[_creatorId]
    }

    // Relic resource definition
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
                        _name: self.name(),
                        _description: self.description,
                        _thumbnail: self.assetImageURL,
                        _id: self.id,
                        _category: self.category,
                        _rarity: self.rarity,
                        _type: self.type,
                        _creatorName: self.creatorName,
                        _title: self.title,
                        _mintDate: self.mintDate,
                        _assetVideoURL: self.assetVideoURL,
                        _assetImageURL: self.assetImageURL,
                        _musicURL: self.musicURL,
                        _artworkURL: self.artworkURL
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

    // defines the public Relic Collection resource interface
    pub resource interface RelicCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.Relic)
        pub fun getIDs(): [UInt64]
        pub fun borrowRelic(id: UInt64): &NonFungibleToken.Relic
        pub fun borrowRelicSpecific(id: UInt64): &Relic
    }

    // defines the public Relic Collection resource
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

    // the RelicMinter is stored on the deployment account and used to mint all Relics
	pub resource RelicMinter {
		pub fun mintRelic(
            recipient: &{NonFungibleToken.CollectionPublic},
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
                    recipient.deposit(token: <- create RelicContract.Relic(
                        _initID: RelicContract.totalSupply, 
                        _creatorId: _creatorId,
                        _relicId: _relicId,
                        _rarity: _rarity,
                        _category: _category,
                        _type:_type,
                        _creatorName: _creatorName,
                        _title: _title, 
                        _description: _description, 
                        _edition: _edition, 
                        _editionSize: _editionSize, 
                        _mintDate: _mintDate, 
                        _assetVideoURL: _assetVideoURL, 
                        _assetImageURL: _assetImageURL,
                        _musicURL: _musicURL, 
                        _artworkURL: _artworkURL,
                        _royalties: _royalties
                        )
                    )

                    emit Minted(id: RelicContract.totalSupply, rarity: _rarity, creatorName: _creatorName)

                    // update the creatorRelicMap
                    if (RelicContract.creatorRelicMap[_creatorId] == nil) {
                        RelicContract.creatorRelicMap.insert(key: _creatorId, [_relicId])
                    } else if (RelicContract.creatorRelicMap[_creatorId]!.contains(_relicId)) {
                        log("relicId already present in creatorRelicMap")
                    } else {
                        RelicContract.creatorRelicMap[_creatorId]!.append(_relicId)
                    }
                    
                    // update the relicEditionMap
                    if (RelicContract.relicEditionMap[_relicId] == nil) {
                        RelicContract.relicEditionMap.insert(key: _relicId, [RelicContract.totalSupply])
                    } else {
                        RelicContract.relicEditionMap[_relicId]!.append(RelicContract.totalSupply)
                    }
                    
                    // update the creatorEditionMap
                    if (RelicContract.creatorEditionMap[_creatorId] == nil) {
                        RelicContract.creatorEditionMap.insert(key: _creatorId, [RelicContract.totalSupply])
                    } else {
                        RelicContract.creatorEditionMap[_creatorId]!.append(RelicContract.totalSupply)
                    }
                    
                    // increment total supply by 1 after mint is complete
                    RelicContract.totalSupply = RelicContract.totalSupply + 1
        }
	}

    // initialize contract states
    init() {
        self.CollectionStoragePath = /storage/RelicCollection
        self.CollectionPublicPath = /public/RelicCollection
        self.MinterStoragePath = /storage/RelicMinter

        self.totalSupply = 0
        self.creatorRelicMap = {}
        self.creatorEditionMap = {}
        self.relicEditionMap = {}

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
 

 











 