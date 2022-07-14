// AUTO-GENERATED CONTRACT
import Beam from 0x86b4a0010a71cfc3
import CNN_NFT from 0x329feb3ab062d289
import CaaPass from 0x98c9c2e548b84d31
import Crave from 0x6d008a788fc27265
import CricketMoments from 0xed398881d9bf40fb
import Domains from 0x233eb012d34b0070
import Eternal from 0xc38aea683c0c4d38
import Gaia from 0x8b148183c28ff88f
import KOTD from 0x23dddd854fcc8c6f
import KlktnNFT from 0xabd6e80be7e9682c
import KlktnNFT2 from 0xabd6e80be7e9682c
import MatrixWorldFlowFestNFT from 0x2d2750f240198f91
import MetadataViews from 0x1d7e57aa55817448
import Mynft from 0xf6fcbef550d97aa5
import NonFungibleToken from 0x1d7e57aa55817448
import RaceDay_NFT from 0x329feb3ab062d289
import RareRooms_NFT from 0x329feb3ab062d289
import Shard from 0x82b54037a8f180cf
import SportsIconCollectible from 0x8de96244f54db422
import StarlyCard from 0x5b82f21c0edf76e3
import TuneGO from 0x0d9bc5af3fc0c2e3
import Vouchers from 0x444f5ea22c6ea12c

/*
    A wrapper contract around the script provided by the Alchemy GitHub respository.
    Allows for on-chain storage of NFT Metadata, allowing consumers to query upon.
    This contract will be periodically updated based on new onboarding PRs and deployed.
    Any consumers calling the public methods below will retrieve the latest and greatest data.
*/
pub contract AlchemyMetadataWrapperMainnetShard1 {
    // Structs copied over as-is from getNFT(ID)?s.cdc for backwards-compatability.
    pub struct NFTCollection {
        pub let owner: Address
        pub let nfts: [NFTData]
    
        init(owner: Address) {
            self.owner = owner
            self.nfts = []
        }
    }

    pub struct NFTData {
        pub let contract: NFTContractData
        pub let id: UInt64
        pub let uuid: UInt64?
        pub let title: String?
        pub let description: String?
        pub let external_domain_view_url: String?
        pub let token_uri: String?
        pub let media: [NFTMedia?]
        pub let metadata: {String: String?}
    
        init(
            contract: NFTContractData,
            id: UInt64,
            uuid: UInt64?,
            title: String?,
            description: String?,
            external_domain_view_url: String?,
            token_uri: String?,
            media: [NFTMedia?],
            metadata: {String: String?}
        ) {
            self.contract = contract
            self.id = id
            self.uuid = uuid
            self.title = title
            self.description = description
            self.external_domain_view_url = external_domain_view_url
            self.token_uri = token_uri
            self.media = media
            self.metadata = metadata
        }
    }

    pub struct NFTContractData {
        pub let name: String
        pub let address: Address
        pub let storage_path: String
        pub let public_path: String
        pub let public_collection_name: String
        pub let external_domain: String
    
        init(
            name: String,
            address: Address,
            storage_path: String,
            public_path: String,
            public_collection_name: String,
            external_domain: String
        ) {
            self.name = name
            self.address = address
            self.storage_path = storage_path
            self.public_path = public_path
            self.public_collection_name = public_collection_name
            self.external_domain = external_domain
        }
    }

    pub struct NFTMedia {
        pub let uri: String?
        pub let mimetype: String?
    
        init(
            uri: String?,
            mimetype: String?
        ) {
            self.uri = uri
            self.mimetype = mimetype
        }
    }
    
    // Same method signature as getNFTs.cdc for backwards-compatability.
    pub fun getNFTs(ownerAddress: Address, ids: {String:[UInt64]}): [NFTData?] {
        let NFTs: [NFTData?] = []
        let owner = getAccount(ownerAddress)
    
        for key in ids.keys {
            for id in ids[key]! {
                var d: NFTData? = nil
    
                // note: unfortunately dictonairy containing functions is not
                // working on mainnet for now so we have to fallback to switch
                switch key {
                    case "CNN": d = self.getCnnNFT(owner: owner, id: id)
                    case "Gaia": d = self.getGaia(owner: owner, id: id)
                    case "TopShot": continue
                    case "MatrixWorldFlowFestNFT": d = self.getMatrixWorldFlowFest(owner: owner, id: id)
                    case "StarlyCard": d = self.getStarlyCard(owner: owner, id: id)
                    case "EternalShard": d = self.getEternalShard(owner: owner, id: id)
                    case "Mynft": d = self.getMynft(owner: owner, id: id)
                    case "Vouchers": d = self.getVoucher(owner: owner, id: id)
                    case "MusicBlock": continue
                    case "NyatheesOVO": continue
                    case "RaceDay_NFT": d = self.getRaceDay(owner: owner, id: id)
                    case "Andbox_NFT": continue
                    case "FantastecNFT": continue
                    case "Everbloom": continue
                    case "Domains": d = self.getFlownsDomain(owner: owner, id:id)
                    case "EternalMoment": d = self.getEternalMoment(owner: owner, id: id)
                    case "ThingFund": d = self.getCaaPass(owner: owner, id: id)
                    case "TFCItems": continue
                    case "Gooberz": continue
                    case "MintStoreItem": continue
                    case "BiscuitsNGroovy": continue
                    case "GeniaceNFT": continue
                    case "Xtingles": continue
                    case "Beam": d = self.getBeam(owner: owner, id: id)
                    case "KOTD": d = self.getKOTD(owner: owner, id: id)
                    case "KlktnNFT": d = self.getKlktnNFT(owner: owner, id: id)
                    case "KlktnNFT2": d = self.getKlktnNFT2(owner: owner, id: id)
                    case "RareRooms_NFT": d = self.getRareRooms(owner: owner, id: id)
                    case "Crave": d = self.getCrave(owner: owner, id: id)
                    case "CricketMoments": d = self.getCricketMoments(owner: owner, id: id)
                    case "SportsIconCollectible": d = self.getSportsIconCollectible(owner: owner, id: id)
                    case "InceptionAnimals": continue
                    case "OneFootballCollectible": continue
                    case "TheFabricantMysteryBox_FF1": continue
                    case "DieselNFT": continue
                    case "MiamiNFT": continue
                    case "Bitku": continue
                    case "FlowFans": continue
                    case "AllDay": continue
                    case "PackNFT": continue
                    case "ItemNFT": continue
                    case "TheFabricantS1ItemNFT": continue
                    case "ZeedzINO" : continue
                    case "Kicks" : continue
                    case "BarterYardPack": continue
                    case "BarterYardClubWerewolf": continue
                    case "DayNFT" : continue
                    case "Costacos_NFT": continue
                    case "Canes_Vault_NFT": continue
                    case "AmericanAirlines_NFT": continue
                    case "The_Next_Cartel_NFT": continue
                    case "Atheletes_Unlimited_NFT": continue
                    case "Art_NFT": continue
                    case "DGD_NFT": continue
                    case "NowggNFT": continue
                    case "GogoroCollectible": continue
                    case "YahooCollectible": continue
                    case "YahooPartnersCollectible": continue
                    case "BlindBoxRedeemVoucher": continue
                    case "SomePlaceCollectible": continue
                    case "ARTIFACTPack": continue
                    case "ARTIFACT": continue
                    case "NftReality": continue
                    case "MatrixWorldAssetsNFT": continue
                    case "TuneGO": d = self.getTuneGO(owner: owner, id: id)
                    case "TicalUniverse": continue
                    case "RacingTime": continue
                    case "Momentables": continue
                    case "GoatedGoats": continue
                    case "GoatedGoatsTrait": continue
                    case "DropzToken": continue
                    case "Necryptolis": continue
                    case "FLOAT" : continue
                    case "BreakingT_NFT": continue
                    case "Owners": continue
                    case "Metaverse": continue
                    case "NFTContract": continue
                    case "Swaychain": continue
                    case "TheFabricantS2ItemNFT": continue
                    case "VnMiss": continue
                    case "AvatarArt": continue
                    case "Dooverse": continue
                    case "TrartContractNFT": continue
                    case "SturdyItems": continue
                    case "PartyMansionDrinksContract": continue
                    case "CryptoPiggo": continue
                    case "Evolution": continue
                    case "Moments": continue
                    case "MotoGPCard": continue
                    case "UFC_NFT": continue
                    default:
                        panic("adapter for NFT not found: ".concat(key))
                }
    
                NFTs.append(d)
            }
        }
    
        return NFTs
    }

    pub fun getCnnNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "CNN_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "CNN_NFT.CollectionStoragePath",
            public_path: "CNN_NFT.CollectionPublicPath",
            public_collection_name: "CNN_NFT.CNN_NFTCollectionPublic",
            external_domain: "https://vault.cnn.com/",
        )
    
        let col = owner.getCapability(CNN_NFT.CollectionPublicPath)
            .borrow<&{CNN_NFT.CNN_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCNN_NFT(id: id)
        if nft == nil { return nil }
    
        let setMeta = CNN_NFT.getSetMetadata(setId: nft!.setId)!
        let seriesMeta = CNN_NFT.getSeriesMetadata(
            seriesId: CNN_NFT.getSetSeriesId(setId: nft!.setId)!
        )
        let seriesId = CNN_NFT.getSetSeriesId(setId: nft!.setId)!
        let nftEditions = CNN_NFT.getSetMaxEditions(setId: nft!.setId)!
        let externalTokenViewUrl = setMeta!["external_url"]!.concat("tokens/").concat(nft!.id.toString())
    
        var mimeType = "image"
        if setMeta!["image_file_type"]!.toLower() == "mp4" {
            mimeType = "video/mp4"
        } else if setMeta!["image_file_type"]!.toLower() == "glb" {
            mimeType = "model/gltf-binary"
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: setMeta!["name"],
            description: setMeta!["description"],
            external_domain_view_url: externalTokenViewUrl,
            token_uri: nil,
            media: [
                NFTMedia(uri: setMeta!["image"], mimetype: mimeType),
                NFTMedia(uri: setMeta!["preview"], mimetype: "image")
            ],
            metadata: {
                "editionNumber": nft!.editionNum.toString(),
                "editionCount": nftEditions!.toString(),
                "set_id": nft!.setId.toString(),
                "series_id": seriesId!.toString()
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x8b148183c28ff88f/contract/Gaia
    
    
    pub fun getGaia(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Gaia",
            address: 0x8b148183c28ff88f,
            storage_path: "Gaia.CollectionStoragePath",
            public_path: "Gaia.CollectionPublicPath",
            public_collection_name: "Gaia.CollectionPublic",
            external_domain: "ballerz.xyz"
        )
    
        let col = owner.getCapability(Gaia.CollectionPublicPath)
            .borrow<&{Gaia.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowGaiaNFT(id: id)
        if nft == nil { return nil }
    
        let metadata = Gaia.getTemplateMetaData(templateID: nft!.data.templateID)
    
        // Populate Gaia NFT data attributes into the metadata
        metadata!.insert(key: "setID", nft!.data.setID.toString())
        metadata!.insert(key: "templateID", nft!.data.templateID.toString())
        metadata!.insert(key: "mintNumber", nft!.data.mintNumber.toString())
    
        let rawMetadata: {String:String?} = {}
        for key in metadata!.keys {
            rawMetadata.insert(key: key, metadata![key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!["title"],
            description: metadata!["description"],
            external_domain_view_url: metadata!["uri"],
            token_uri: nil,
            media: [NFTMedia(uri: metadata!["img"], mimetype: "image")],
            metadata: rawMetadata,
        )
    }
    
    
    
    pub fun stringStartsWith(string: String, prefix: String): Bool {
        if(string.length < prefix.length) {
            return false
        }
    
        let beginning = string.slice(from: 0, upTo: prefix.length)
    
        let prefixArray = prefix.utf8
        let beginningArray = beginning.utf8
    
        for index, element in prefixArray {
            if(beginningArray[index] != prefixArray[index]) {
                return false
            }
        }
    
        return true
    }
    
    // https://flow-view-source.com/mainnet/account/0x86b4a0010a71cfc3/contract/Beam
    
    
    pub fun getBeam(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Beam",
            address: 0x86b4a0010a71cfc3,
            storage_path: "Beam.CollectionStoragePath",
            public_path: "Beam.CollectionPublicPath",
            public_collection_name: "Beam.BeamCollectionPublic",
            external_domain: "frightclub.niftory.com"
        )
    
        let col = owner.getCapability(Beam.CollectionPublicPath)
            .borrow<&{Beam.BeamCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCollectible(id: id)
        if nft == nil { return nil }
    
        let metadata = Beam.getCollectibleItemMetaData(collectibleItemID: nft!.data.collectibleItemID)
    
        let ipfsScheme = "ipfs://"
        let httpsScheme = "https://"
    
        var mediaUrl: String? = nil
        if metadata!["mediaUrl"]  != nil {
            let metadataUrl = metadata!["mediaUrl"]!
            if self.stringStartsWith(string: metadataUrl, prefix: ipfsScheme) || self.stringStartsWith(string: metadataUrl, prefix: httpsScheme) {
                mediaUrl = metadataUrl
            }
            else if metadataUrl.length > 0 {
                mediaUrl = ipfsScheme.concat(metadataUrl)
            }
        }
    
        var domainUrl: String? = nil
        if metadata!["domainUrl"] != nil {
            let metadataDomainUrl = metadata!["domainUrl"]!
            if self.stringStartsWith(string: metadataDomainUrl, prefix: httpsScheme) {
                domainUrl = metadataDomainUrl
            }
            else if metadataDomainUrl.length > 0 {
                domainUrl = httpsScheme.concat(metadataDomainUrl)
            }
        }
    
        let rawMetadata: {String:String?} = {}
        for key in metadata!.keys {
            rawMetadata.insert(key: key, metadata![key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!["title"],
            description: metadata!["description"],
            external_domain_view_url: domainUrl,
            token_uri: nil,
            media: [NFTMedia(uri: mediaUrl, mimetype: metadata!["mediaType"]),
                NFTMedia(uri: "ipfs://bafybeichtxzrocxo7ec5qybfxxlyod5bbymblitjwb2aalv2iyhe42pk4e/Frightclub.jpg", mimetype:"image/jpeg")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x6d008a788fc27265/contract/Crave
    
    
    pub fun getCrave(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Crave",
            address: 0x6d008a788fc27265,
            storage_path: "Crave.CollectionStoragePath",
            public_path: "Crave.CollectionPublicPath",
            public_collection_name: "Crave.CraveCollectionPublic",
            external_domain: "crave.niftory.com"
        )
    
        let col = owner.getCapability(Crave.CollectionPublicPath)
            .borrow<&{Crave.CraveCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCollectible(id: id)
        if nft == nil { return nil }
    
        let metadata = Crave.getCollectibleItemMetaData(collectibleItemID: nft!.data.collectibleItemID)
    
        let ipfsScheme = "ipfs://"
        let httpsScheme = "https://"
    
        var mediaUrl: String? = nil
        if metadata!["mediaUrl"]  != nil {
            let metadataUrl = metadata!["mediaUrl"]!
            if self.stringStartsWith(string: metadataUrl, prefix: ipfsScheme) || self.stringStartsWith(string: metadataUrl, prefix: httpsScheme) {
                mediaUrl = metadataUrl
            }
            else if metadataUrl.length > 0 {
                mediaUrl = ipfsScheme.concat(metadataUrl)
            }
        }
    
        var domainUrl: String? = nil
        if metadata!["domainUrl"]  != nil {
            let metadataDomainUrl = metadata!["domainUrl"]!
            if self.stringStartsWith(string: metadataDomainUrl, prefix: httpsScheme) {
                domainUrl = metadataDomainUrl
            }
            else if metadataDomainUrl.length > 0 {
                domainUrl = httpsScheme.concat(metadataDomainUrl)
            }
        }
    
        let rawMetadata: {String:String?} = {}
        for key in metadata!.keys {
            rawMetadata.insert(key: key, metadata![key])
        }
    
       return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!["title"],
            description: metadata!["description"],
            external_domain_view_url: domainUrl,
            token_uri: nil,
            media: [NFTMedia(uri: mediaUrl, mimetype: metadata!["mediaType"]),
                NFTMedia(uri: "ipfs://bafybeiedrlfjykj4svmaka7jdxnhr3osigtudyrhitxsf7ska5ljeiwlxa/Crave Critics Banner.jpg", mimetype:"image/jpeg")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xed398881d9bf40fb/contract/CricketMoments
    
    
    pub fun getCricketMoments(owner: PublicAccount, id: UInt64): NFTData? {
    
        let col = owner.getCapability(CricketMoments.CollectionPublicPath)
            .borrow<&{CricketMoments.CricketMomentsCollectionPublic}>()
        if col == nil { return nil }
    
        if let nft = col!.borrowCricketMoment(id: id){
            let contract = NFTContractData(
                name: "CricketMoments",
                address: 0xed398881d9bf40fb,
                storage_path: "CricketMoments.CollectionStoragePath",
                public_path: "CricketMoments.CollectionPublicPath",
                public_collection_name: "CricketMoments.CricketMomentsCollectionPublic",
                external_domain: ""
            )
    
            let metadata = nft!.getMetadata()
            let rawMetadata: {String:String?} = {}
            for key in metadata!.keys {
                rawMetadata.insert(key: key, metadata![key])
            }
    
            return NFTData(
                contract: contract,
                id: nft!.id,
                uuid: nft!.uuid,
                title: nil,
                description: metadata["description"],
                external_domain_view_url: nil,
                token_uri: "https://gateway.pinata.cloud/ipfs/".concat(metadata["ipfs"]!),
                media: [],
                metadata: rawMetadata,
            )
        }
        return nil
    
    }
    
    // https://flow-view-source.com/mainnet/account/0xe703f7fee6400754/contract/Everbloom
    
    
    pub fun getEternalMoment(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Eternal",
            address: 0xc38aea683c0c4d38,
            storage_path: "/storage/EternalMomentCollection",
            public_path: "/public/EternalMomentCollection",
            public_collection_name: "Eternal.MomentCollectionPublic",
            external_domain: "https://eternal.gg/"
        )
    
        let col = owner.getCapability(/public/EternalMomentCollection)
            .borrow<&{Eternal.MomentCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowMoment(id: id)
        if nft == nil { return nil }
    
        let metadata = Eternal.getPlayMetaData(playID: nft!.data.playID)
        if metadata == nil { return nil }
    
        let rawMetadata: {String:String?} = {}
        for key in metadata!.keys {
            rawMetadata.insert(key: key, metadata![key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!["Title"],
            description: metadata!["Game"]!.concat(" - ").concat(metadata!["Influencer"]!),
            external_domain_view_url: "https://eternal.gg/moments/".concat(nft!.id.toString()),
            token_uri: nil,
            media: [NFTMedia(
                uri: "https://gateway.pinata.cloud/ipfs/".concat(metadata!["Hash"]!),
                mimetype: "video"
            )],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x82b54037a8f180cf/contract/Shard
    
    
    pub fun getEternalShard(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Shard",
            address: 0x82b54037a8f180cf,
            storage_path: "/storage/EternalShardCollection",
            public_path: "/public/EternalShardCollection",
            public_collection_name: "Shard.ShardCollectionPublic",
            external_domain: "https://eternal.gg/"
        )
    
        let col = owner.getCapability(/public/EternalShardCollection)
            .borrow<&{Shard.ShardCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowShardNFT(id: id)
        if nft == nil { return nil }
    
        let clip = Shard.getClip(clipID: nft!.clipID)
        let clipMetadata = Shard.getClipMetadata(clipID: nft!.clipID)
        let momentMetadata = Shard.getMomentMetadata(momentID: clip!.momentID)
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: clipMetadata!["title"],
            description: "Deposit your Shard at Eternal.gg to merge them into a Crystal!",
            external_domain_view_url: "https://eternal.gg/shards/".concat(nft!.id.toString()),
            token_uri: nil,
            media: [NFTMedia(uri: clipMetadata!["video_url"], mimetype: "video")],
            metadata: {
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x2e1ee1e7a96826ce/contract/FantastecNFT
    
    
    pub fun getVoucher(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Vouchers",
            address: 0x444f5ea22c6ea12c,
            storage_path: "Vouchers.CollectionStoragePath",
            public_path: "Vouchers.CollectionPublicPath",
            public_collection_name: "Vouchers.CollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(Vouchers.CollectionPublicPath)
            .borrow<&{Vouchers.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowVoucher(id: id)
        if nft == nil { return nil }
    
        let metadata = nft!.getMetadata()
        if metadata == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!.name,
            description: metadata!.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: metadata!.mediaURI, mimetype: metadata!.mediaType)],
            metadata: {
                "mediaHash": metadata!.mediaURI,
                "mediaType": metadata!.mediaType,
                "mediaURI": metadata!.mediaURI,
                "name": metadata!.name,
                "description": metadata!.description,
                "typeID": nft!.typeID.toString()
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x23dddd854fcc8c6f/contract/KOTD
    
    
    pub fun getKOTD(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "KOTD",
            address: 0x23dddd854fcc8c6f,
            storage_path: "KOTD.CollectionStoragePath",
            public_path: "KOTD.CollectionPublicPath",
            public_collection_name: "KOTD.NiftoryCollectibleCollectionPublic",
            external_domain: "kotd.niftory.com"
        )
    
        let col = owner.getCapability(KOTD.CollectionPublicPath)
            .borrow<&{KOTD.NiftoryCollectibleCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCollectible(id: id)
        if nft == nil { return nil }
    
        let metadata = KOTD.getCollectibleItemMetaData(collectibleItemID: nft!.data.collectibleItemID)
    
        let ipfsScheme = "ipfs://"
        let httpsScheme = "https://"
    
        var mediaUrl: String? = nil
        if metadata!["mediaUrl"]  != nil {
            let metadataUrl = metadata!["mediaUrl"]!
            if self.stringStartsWith(string: metadataUrl, prefix: ipfsScheme) || self.stringStartsWith(string: metadataUrl, prefix: httpsScheme) {
                mediaUrl = metadataUrl
            }
            else if metadataUrl.length > 0 {
                 mediaUrl = ipfsScheme.concat(metadataUrl)
            }
        }
    
        var domainUrl: String? = nil
        if metadata!["domainUrl"]  != nil {
            let metadataDomainUrl = metadata!["domainUrl"]!
            if self.stringStartsWith(string: metadataDomainUrl, prefix: httpsScheme) {
                domainUrl = metadataDomainUrl
            }
            else if metadataDomainUrl.length > 0 {
                domainUrl = httpsScheme.concat(metadataDomainUrl)
            }
        }
    
        let rawMetadata: {String:String?} = {}
        for key in metadata!.keys {
            rawMetadata.insert(key: key, metadata![key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!["title"],
            description: metadata!["description"],
            external_domain_view_url: domainUrl,
            token_uri: nil,
            media: [NFTMedia(uri: mediaUrl, mimetype: metadata!["mediaType"]),
                NFTMedia(uri: "ipfs://bafybeidy62mofvdpzr5gujq57kcpm27pciqx33pahxbfuwgzea646k2nay/s1_poster.jpg", mimetype:"image/jpeg")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xabd6e80be7e9682c/contract/KlktnNFT
    
    
    pub fun getKlktnNFT(owner: PublicAccount, id: UInt64): NFTData? {
    
        let col = owner.getCapability(KlktnNFT.CollectionPublicPath)
            .borrow<&{KlktnNFT.KlktnNFTCollectionPublic}>()
        if col == nil { return nil }
    
        if let nft = col!.borrowKlktnNFT(id: id){
    
            let metadata = nft!.getNFTMetadata()
    
                let contract = NFTContractData(
                name: "KlktnNFT",
                address: 0xabd6e80be7e9682c,
                storage_path: "KlktnNFT.CollectionStoragePath",
                public_path: "KlktnNFT.CollectionPublicPath",
                public_collection_name: "KlktnNFT.KlktnNFTCollectionPublic",
                external_domain: ""
            )
    
            let rawMetadata: {String:String?} = {}
            for key in metadata!.keys {
                rawMetadata.insert(key: key, metadata![key])
            }
    
            return NFTData(
                contract: contract,
                id: nft!.id,
                uuid: nft!.uuid,
                title: metadata["name"],
                description:metadata["description"],
                external_domain_view_url: nil,
                token_uri: nil,
                media: [NFTMedia(uri: metadata["media"], mimetype: metadata["mimeType"])],
                metadata: rawMetadata,
            )
        }
        return nil
    
    }
    
    // https://flow-view-source.com/mainnet/account/0xabd6e80be7e9682c/contract/KlktnNFT2
    
    
    pub fun getKlktnNFT2(owner: PublicAccount, id: UInt64): NFTData? {
    
        let col = owner.getCapability(KlktnNFT2.CollectionPublicPath)
            .borrow<&{KlktnNFT2.KlktnNFTCollectionPublic}>()
        if col == nil { return nil }
    
        if let nft = col!.borrowKlktnNFT(id: id){
    
            let template = nft!.getFullMetadata()
    
                let contract = NFTContractData(
                name: "KlktnNFT2",
                address: 0xabd6e80be7e9682c,
                storage_path: "KlktnNFT2.CollectionStoragePath",
                public_path: "KlktnNFT2.CollectionPublicPath",
                public_collection_name: "KlktnNFT2.KlktnNFTCollectionPublic",
                external_domain: ""
            )
    
            let rawMetadata: {String:String?} = {}
            for key in template.metadata.keys {
                rawMetadata.insert(key: key, template.metadata[key])
            }
    
            return NFTData(
                contract: contract,
                id: nft!.id,
                uuid: nft!.uuid,
                title: template.metadata["name"] ?? "",
                description:template.metadata["description"] ?? "",
                external_domain_view_url: nil,
                token_uri: template.metadata["uri"] ?? "",
                media: [NFTMedia(uri: template.metadata["media"] ?? "", mimetype: template.metadata["mimeType"] ?? "")],
                metadata: rawMetadata,
            )
        }
        return nil
    
    }
    
    // https://flow-view-source.com/mainnet/account/0x5634aefcb76e7d8c/contract/MusicBlock
    
    
    pub fun getMynft(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Mynft",
            address: 0xf6fcbef550d97aa5,
            storage_path: "Mynft.CollectionStoragePath",
            public_path: "Mynft.CollectionPublicPath",
            public_collection_name: "Mynft.MynftCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(Mynft.CollectionPublicPath)
            .borrow<&{Mynft.MynftCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowArt(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nft!.metadata!.name,
            description: nft!.metadata!.description,
            external_domain_view_url: "",
            token_uri: nil,
            media: [NFTMedia(uri: nft!.metadata!.ipfsLink, mimetype: nft!.metadata!.type)],
            metadata: {
                "artist": nft!.metadata!.artist,
                "arLink": nft!.metadata!.arLink,
                "ipfsLink": nft!.metadata!.ipfsLink,
                "MD5Hash": nft!.metadata!.MD5Hash,
                "type": nft!.metadata!.type,
                "name": nft!.metadata!.name,
                "description": nft!.metadata!.description
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x75e0b6de94eb05d0/contract/NyatheesOVO
    
    
    pub fun getRaceDay(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "RaceDay_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "RaceDay_NFT.CollectionStoragePath",
            public_path: "RaceDay_NFT.CollectionPublicPath",
            public_collection_name: "RaceDay_NFT.RaceDay_NFTCollectionPublic",
            external_domain: "https://racedaynft.com/"
        )
    
        let col = owner.getCapability(RaceDay_NFT.CollectionPublicPath)
            .borrow<&{RaceDay_NFT.RaceDay_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowRaceDay_NFT(id: id)
        if nft == nil { return nil }
    
        let setMeta = RaceDay_NFT.getSetMetadata(setId: nft!.setId)!
        let seriesMeta = RaceDay_NFT.getSeriesMetadata(
            seriesId: RaceDay_NFT.getSetSeriesId(setId: nft!.setId)!
        )
    
        let seriesId = RaceDay_NFT.getSetSeriesId(setId: nft!.setId)!
        let nftEditions = RaceDay_NFT.getSetMaxEditions(setId: nft!.setId)!
        let externalTokenViewUrl = setMeta!["external_url"]!.concat("/tokens/").concat(nft!.id.toString())
    
        var mimeType = "image"
        if setMeta!["image_file_type"]!.toLower() == "mp4" {
            mimeType = "video/mp4"
        } else if setMeta!["image_file_type"]!.toLower() == "glb" {
            mimeType = "model/gltf-binary"
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: setMeta!["name"],
            description: setMeta!["description"],
            external_domain_view_url: externalTokenViewUrl,
            token_uri: nil,
            media: [
                NFTMedia(uri: setMeta!["image"], mimetype: mimeType),
                NFTMedia(uri: setMeta!["preview"], mimetype: "image")
            ],
            metadata: {
                "editionNumber": nft!.editionNum.toString(),
                "editionCount": nftEditions!.toString(),
                "set_id": nft!.setId.toString(),
                "series_id": seriesId!.toString()
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x329feb3ab062d289/contract/Andbox_NFT
    
    
    pub fun getRareRooms(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "RareRooms_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "RareRooms_NFT.CollectionStoragePath",
            public_path: "RareRooms_NFT.CollectionPublicPath",
            public_collection_name: "RareRooms_NFT.RareRooms_NFTCollectionPublic",
            external_domain: "https://rarerooms.io/"
        )
    
        let col = owner.getCapability(RareRooms_NFT.CollectionPublicPath)
            .borrow<&{RareRooms_NFT.RareRooms_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowRareRooms_NFT(id: id)
        if nft == nil { return nil }
    
        let setMeta = RareRooms_NFT.getSetMetadata(setId: nft!.setId)!
        let seriesMeta = RareRooms_NFT.getSeriesMetadata(
            seriesId: RareRooms_NFT.getSetSeriesId(setId: nft!.setId)!
        )
    
        let seriesId = RareRooms_NFT.getSetSeriesId(setId: nft!.setId)!
        let nftEditions = RareRooms_NFT.getSetMaxEditions(setId: nft!.setId)!
        let externalTokenViewUrl = "https://rarerooms.io/tokens/".concat(nft!.id.toString())
    
        var mimeType = "image"
        if setMeta!["image_file_type"]!.toLower() == "mp4" {
            mimeType = "video/mp4"
        } else if setMeta!["image_file_type"]!.toLower() == "glb" {
            mimeType = "model/gltf-binary"
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: setMeta!["name"],
            description: setMeta!["description"],
            external_domain_view_url: externalTokenViewUrl,
            token_uri: nil,
            media: [
                NFTMedia(uri: setMeta!["image"], mimetype: mimeType),
                NFTMedia(uri: setMeta!["preview"], mimetype: "image")
            ],
            metadata: {
                "editionNumber": nft!.editionNum.toString(),
                "editionCount": nftEditions!.toString(),
                "set_id": nft!.setId.toString(),
                "series_id": seriesId!.toString()
            },
        )
    
    }
    
    // https://flow-view-source.com/mainnet/account/0x8de96244f54db422/contract/SportsIconCollectible
    
    
    pub fun getSportsIconCollectible(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "SportsIconCollectible",
            address: 0x8de96244f54db422,
            storage_path: "SportsIconCollectible.CollectionStoragePath",
            public_path: "SportsIconCollectible.CollectionPublicPath",
            public_collection_name: "SportsIconCollectible.CollectibleCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(SportsIconCollectible.CollectionPublicPath)
            .borrow<&{SportsIconCollectible.CollectibleCollectionPublic}>()
        if col == nil { return nil }
    
        let collectible = col!.borrowCollectible(id: id)
        let nft = col!.borrowNFT(id: id)
        if nft == nil { return nil }
    
        let setData = SportsIconCollectible.getSetMetadataForNFTByUUID(uuid: nft!.uuid)!
        let editionData = SportsIconCollectible.getCollectibleDataForNftByUUID(uuid: nft!.uuid)!
        let setMetadata = setData.getMetadata()
    
        let rawMetadata: {String:String?} = {}
        for key in setMetadata.keys {
            rawMetadata.insert(key: key, setMetadata[key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: setMetadata["title"],
            description: setMetadata["description"],
            external_domain_view_url: "https://app.sportsicon.com/collectible/".concat(editionData.getSetID().toString()).concat("/").concat(editionData.getEditionNumber().toString()),
            token_uri: nil,
            media: [NFTMedia(uri: setMetadata!["contentURL"], mimetype: "video/mp4")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x5b82f21c0edf76e3/contract/StarlyCard
    
    
    pub fun getStarlyCard(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "StarlyCard",
            address: 0x5b82f21c0edf76e3,
            storage_path: "StarlyCard.CollectionStoragePath",
            public_path: "StarlyCard.CollectionPublicPath",
            public_collection_name: "StarlyCard.StarlyCardCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(StarlyCard.CollectionPublicPath)
            .borrow<&{StarlyCard.StarlyCardCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowStarlyCard(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nil,
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [],
            metadata: {
                "id": nft!.starlyID
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x98c9c2e548b84d31/contract/CaaPass
    
    
    pub fun getCaaPass(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "CaaPass",
            address: 0x98c9c2e548b84d31,
            storage_path: "CaaPass.CollectionStoragePath",
            public_path: "CaaPass.CollectionPublicPath",
            public_collection_name: "CaaPass.CollectionPublic",
            external_domain: "thing.fund"
        )
    
        let col = owner.getCapability(CaaPass.CollectionPublicPath)
            .borrow<&{CaaPass.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCaaPass(id: id)
        if nft == nil { return nil }
    
        let metadata: CaaPass.Metadata? = nft!.getMetadata()
        if metadata == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata!.name,
            description: metadata!.description,
            external_domain_view_url: "https://thing.fund/",
            token_uri: nil,
            media: [
                NFTMedia(uri: "ipfs://".concat(metadata!.mediaHash), mimetype: metadata!.mediaType)
            ],
            metadata: {
                "name": metadata!.name,
                "description": metadata!.description,
                "mediaType": metadata!.mediaType,
                "mediaHash": metadata!.mediaHash
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x0d9bc5af3fc0c2e3/contract/TuneGO
    
    
    pub fun getTuneGO(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "TuneGO",
            address: 0x0d9bc5af3fc0c2e3,
            storage_path: "TuneGO.CollectionStoragePath",
            public_path: "TuneGO.CollectionPublicPath",
            public_collection_name: "TuneGO.TuneGOCollectionPublic",
            external_domain: "tunegonft.com"
        )
    
        let col = owner.getCapability(TuneGO.CollectionPublicPath)
            .borrow<&{TuneGO.TuneGOCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCollectible(id: id)
        if nft == nil { return nil }
    
        let data = nft!.data
        let itemMetadata = TuneGO.getItemMetadata(itemId: data.itemId)!
        let editionNumber = data.serialNumber!
        let editionCount = TuneGO.getNumberCollectiblesInEdition(setId: data.setId, itemId: data.itemId)!
    
        var metadata = itemMetadata
        let rawMetadata: {String:String?} = {}
        for key in metadata.keys {
            rawMetadata.insert(key: key, metadata[key])
        }
        rawMetadata["editionNumber"] = editionNumber.toString()
        rawMetadata["editionCount"] = editionCount.toString()
        rawMetadata["royaltyAddress"] = "0x8039244113ff6251"
        rawMetadata["royaltyPercentage"] = "5.0"
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: itemMetadata["Title"],
            description: itemMetadata["Description"],
            external_domain_view_url: "https://tunegonft.com/collectible/".concat(nft!.uuid.toString()),
            token_uri: nil,
            media: [ NFTMedia(uri: itemMetadata["Media URL"]!, mimetype: "video/mp4") ],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xfef48806337aabf1/contract/TicalUniverse
    
    
    pub fun getMatrixWorldFlowFest(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "MatrixWorldFlowFestNFT",
            address: 0x2d2750f240198f91,
            storage_path: "MatrixWorldFlowFestNFT.CollectionStoragePath",
            public_path: "MatrixWorldFlowFestNFT.CollectionPublicPath",
            public_collection_name: "MatrixWorldFlowFestNFT.MatrixWorldFlowFestNFTCollectionPublic",
            external_domain: "matrixworld.org"
        )
    
        let col = owner.getCapability(MatrixWorldFlowFestNFT.CollectionPublicPath)
            .borrow<&{MatrixWorldFlowFestNFT.MatrixWorldFlowFestNFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowVoucher(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nft!.metadata.name,
            description: nft!.metadata.description,
            external_domain_view_url: "matrixworld.org",
            token_uri: nil,
            media: [NFTMedia(uri: nft!.metadata.animationUrl, mimetype: "image")],
            metadata: {
                "type": nft!.metadata.type,
                "hash": nft!.metadata.hash
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x0b2a3299cc857e29/contract/TopShot
    
    
    pub fun getFlownsDomain(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "FlownsDomain",
            address: 0x233eb012d34b0070,
            storage_path: "Domains.CollectionStoragePath",
            public_path: "Domains.CollectionPublicPath",
            public_collection_name: "Domains.CollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(Domains.CollectionPublicPath)
            .borrow<&{Domains.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowDomain(id: id)
        if nft == nil { return nil }
    
        let name = nft!.getDomainName()
    
        let URI = "https://www.flowns.org/api/fns?domain=".concat(name)
        let viewURL = "https://www.flowns.org/api/data?domain=".concat(name)
        let rawMetadata: {String:String?} = {}
        for key in nft!.getAllTexts().keys {
            rawMetadata.insert(key: key,nft!.getAllTexts()[key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: name,
            description: nil,
            external_domain_view_url: viewURL,
            token_uri: nil,
            media: [NFTMedia(uri: URI, mimetype: "image")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x81e95660ab5308e1/contract/TFCItems
    

    // Same method signature as getNFTIDs.cdc for backwards-compatability.
    pub fun getNFTIDs(ownerAddress: Address): {String: [UInt64]} {
        let owner = getAccount(ownerAddress)
        let ids: {String: [UInt64]} = {}
    
    
        if let col = owner.getCapability(CNN_NFT.CollectionPublicPath)
            .borrow<&{CNN_NFT.CNN_NFTCollectionPublic}>() {
                ids["CNN"] = col.getIDs()
            }
        if let col = owner.getCapability(Gaia.CollectionPublicPath)
            .borrow<&{Gaia.CollectionPublic}>() {
                ids["Gaia"] = col.getIDs()
            }
        if let col = owner.getCapability(Beam.CollectionPublicPath)
            .borrow<&{Beam.BeamCollectionPublic}>() {
                ids["Beam"] = col.getIDs()
            }
        if let col = owner.getCapability(Crave.CollectionPublicPath)
            .borrow<&{Crave.CraveCollectionPublic}>() {
                ids["Crave"] = col.getIDs()
            }
        if let col = owner.getCapability(CricketMoments.CollectionPublicPath)
            .borrow<&{CricketMoments.CricketMomentsCollectionPublic}>() {
                ids["CricketMoments"] = col.getIDs()
            }
        if let col = owner.getCapability(/public/EternalShardCollection)
            .borrow<&{Shard.ShardCollectionPublic}>() {
                ids["EternalShard"] = col.getIDs()
            }
        if let col = owner.getCapability(Vouchers.CollectionPublicPath)
            .borrow<&{Vouchers.CollectionPublic}>() {
                ids["Vouchers"] = col.getIDs()
            }
        if let col = owner.getCapability(KOTD.CollectionPublicPath)
            .borrow<&{KOTD.NiftoryCollectibleCollectionPublic}>() {
                ids["KOTD"] = col.getIDs()
            }
        if let col = owner.getCapability(KlktnNFT.CollectionPublicPath)
            .borrow<&{KlktnNFT.KlktnNFTCollectionPublic}>() {
                ids["KlktnNFT"] = col.getIDs()
            }
        if let col = owner.getCapability(KlktnNFT2.CollectionPublicPath)
            .borrow<&{KlktnNFT2.KlktnNFTCollectionPublic}>() {
                ids["KlktnNFT2"] = col.getIDs()
            }
        if let col = owner.getCapability(Mynft.CollectionPublicPath)
            .borrow<&{Mynft.MynftCollectionPublic}>() {
                ids["Mynft"] = col.getIDs()
            }
        if let col = owner.getCapability(RaceDay_NFT.CollectionPublicPath)
            .borrow<&{RaceDay_NFT.RaceDay_NFTCollectionPublic}>() {
                ids["RaceDay_NFT"] = col.getIDs()
            }
        if let col = owner.getCapability(RareRooms_NFT.CollectionPublicPath)
            .borrow<&{RareRooms_NFT.RareRooms_NFTCollectionPublic}>() {
                ids["RareRooms_NFT"] = col.getIDs()
            }
        if let col = owner.getCapability(SportsIconCollectible.CollectionPublicPath)
            .borrow<&{SportsIconCollectible.CollectibleCollectionPublic}>() {
                ids["SportsIconCollectible"] = col.getIDs()
            }
        if let col = owner.getCapability(StarlyCard.CollectionPublicPath)
            .borrow<&{StarlyCard.StarlyCardCollectionPublic}>() {
                ids["StarlyCard"] = col.getIDs()
            }
        if let col = owner.getCapability(CaaPass.CollectionPublicPath)
            .borrow<&{CaaPass.CollectionPublic}>() {
                ids["ThingFund"] = col.getIDs()
            }
        if let col = owner.getCapability(TuneGO.CollectionPublicPath)
            .borrow<&{TuneGO.TuneGOCollectionPublic}>() {
                ids["TuneGO"] = col.getIDs()
            }
        if let col = owner.getCapability(MatrixWorldFlowFestNFT.CollectionPublicPath)
            .borrow<&{MatrixWorldFlowFestNFT.MatrixWorldFlowFestNFTCollectionPublic}>() {
                ids["MatrixWorldFlowFestNFT"] = col.getIDs()
            }
        if let col = owner.getCapability(Domains.CollectionPublicPath)
            .borrow<&{Domains.CollectionPublic}>() {
                ids["Domains"] = col.getIDs()
            }
        if let col = owner.getCapability(/public/EternalMomentCollection)
            .borrow<&{Eternal.MomentCollectionPublic}>() {
                ids["EternalMoment"] = col.getIDs()
            }
        return ids
    }
}