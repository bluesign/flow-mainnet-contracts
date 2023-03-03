/*******************************************
Modern Musician Relic Contract v.0.1.3
description: This smart contract functions as the main Modern Musician NFT ('Relics') production contract.
It follows Flow's NonFungibleToken standards as well as uses a MetadataViews implementation.
developed by info@spaceleaf.io
*******************************************/

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x18cbcde9d9c98842

pub contract Relics: NonFungibleToken {

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

    // maps all relicIds to creatorId->  creatorId : [relicId]
    access(self) var creatorRelicMap: { String : [String] }
    // maps all editions by relicId-> relicId : [editions]
    access(self) var relicEditionMap: { String : [UInt64] }
    // maps all editions by creatorId-> creatorId : [editions]
    access(self) var creatorEditionMap: { String : [UInt64] }

    // returns total supply
    pub fun getTotalSupply(): UInt64 {
        return Relics.totalSupply
    }

    // mapping of RelicIds produced by CreatorId, returns an array of Strings or nil
    pub fun getRelicsByCreatorId(_creatorId: String): [String]? {
        return Relics.creatorRelicMap[_creatorId]
    }

    // mapping of Edition ids by relicId, returns an array of UInt64 or nil
    pub fun getEditionsByRelicId(_relicId: String): [UInt64]? {
        return Relics.relicEditionMap[_relicId]
    }

    // mapping of Editions by creatorId, returns an array of UInt64 or nil
    pub fun getEditionsByCreatorId(_creatorId: String): [UInt64]? {
        return Relics.creatorEditionMap[_creatorId]
    }

    // Relic NFT resource definition
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
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
                        thumbnail: MetadataViews.HTTPFile(url:self.assetImageURL),
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
                    return MetadataViews.ExternalURL(": https://www.musicRelics.com/".concat(self.id.toString()))

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
                        storagePath: Relics.CollectionStoragePath,
                        publicPath: Relics.CollectionPublicPath,
                        providerPath: /private/RelicsCollection,
                        publicCollection: Type<&Relics.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        publicLinkedType: Type<&Relics.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Relics.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-Relics.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: self.marketDisplay
                        ),
                        mediaType: "image"
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
                        externalURL: MetadataViews.ExternalURL("https://www.musicRelics.com/"),
                        squareImage: media,
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
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowRelic(id: UInt64): &Relics.NFT? {
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Moment reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // defines the public Relic Collection resource
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, RelicCollectionPublic {
        // Dictionary of Relic conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Relic not found.")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let relic<- token as! @Relics.NFT
            emit Deposit(id: relic.id, to: self.owner?.address)
            self.ownedNFTs[relic.id] <-! relic
        }

        pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("Relic not found.")
            recipient.deposit(token: <- token)

            emit Transfer(id: id, from: self.owner?.address, to: recipient.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowRelic(id: UInt64): &Relics.NFT? {
            if self.ownedNFTs[id] != nil {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return ref as! &Relics.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let relic = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let getRelic = relic as! &Relics.NFT
            return getRelic
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Relics.Collection()
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
                    recipient.deposit(token: <- create NFT(
                        _initID: Relics.totalSupply, 
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

                    emit Minted(id: Relics.totalSupply, rarity: _rarity, creatorName: _creatorName)

                    // update the creatorRelicMap
                    if (Relics.creatorRelicMap[_creatorId] == nil) {
                        Relics.creatorRelicMap.insert(key: _creatorId, [_relicId])
                    } else if (Relics.creatorRelicMap[_creatorId]!.contains(_relicId)) {
                        log("relicId already present in creatorRelicMap")
                    } else {
                        Relics.creatorRelicMap[_creatorId]!.append(_relicId)
                    }
                    
                    // update the relicEditionMap
                    if (Relics.relicEditionMap[_relicId] == nil) {
                        Relics.relicEditionMap.insert(key: _relicId, [Relics.totalSupply])
                    } else {
                        Relics.relicEditionMap[_relicId]!.append(Relics.totalSupply)
                    }
                    
                    // update the creatorEditionMap
                    if (Relics.creatorEditionMap[_creatorId] == nil) {
                        Relics.creatorEditionMap.insert(key: _creatorId, [Relics.totalSupply])
                    } else {
                        Relics.creatorEditionMap[_creatorId]!.append(Relics.totalSupply)
                    }
                    
                    // increment total supply by 1 after mint is complete
                    Relics.totalSupply = Relics.totalSupply + 1
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

        let collection <- Relics.createEmptyCollection()
        self.account.save(<-collection, to: Relics.CollectionStoragePath)

        self.account.link<&Relics.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, RelicCollectionPublic}>(
            self.CollectionPublicPath, 
            target: self.CollectionStoragePath
        )
        emit ContractInitialized()
    }
}
 

 











 