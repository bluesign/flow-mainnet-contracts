// AUTO-GENERATED CONTRACT
import AADigital from 0x39eeb4ee6f30fc3f
import DooverseItems from 0x66ad29c7d7465437
import Evolution from 0xf4264ac8f3256818
import Flunks from 0x807c3d470888cc48
import MetaPanda from 0xf2af175e411dfff8
import MetadataViews from 0x1d7e57aa55817448
import Moments from 0xd4ad4740ee426334
import MotoGPCard from 0xa49cc0ee46c54bfb
import NFTContract from 0x1e075b24abe6eca6
import NonFungibleToken from 0x1d7e57aa55817448
import PartyMansionDrinksContract from 0x34f2bf4a80bb0f69
import QRLNFT from 0xa4e9020ad21eb30b
import RCRDSHPNFT from 0x6c3ff40b90b928ab
import Seussibles from 0x321d8fcde05f6e8c
import TheFabricantS2ItemNFT from 0x7752ea736384322f
import TicalUniverse from 0xfef48806337aabf1
import TrartContractNFT from 0x6f01a4b0046c1f87
import UFC_NFT from 0x329feb3ab062d289
import VnMiss from 0x7c11edb826692404

/*
    A wrapper contract around the script provided by the Alchemy GitHub respository.
    Allows for on-chain storage of NFT Metadata, allowing consumers to query upon.
    This contract will be periodically updated based on new onboarding PRs and deployed.
    Any consumers calling the public methods below will retrieve the latest and greatest data.
*/
pub contract AlchemyMetadataWrapperMainnetShard4 {
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
                    case "CNN": continue
                    case "Gaia": continue
                    case "TopShot": continue
                    case "MatrixWorldFlowFestNFT": continue
                    case "StarlyCard": continue
                    case "EternalShard": continue
                    case "Mynft": continue
                    case "Vouchers": continue
                    case "MusicBlock": continue
                    case "NyatheesOVO": continue
                    case "RaceDay_NFT": continue
                    case "Andbox_NFT": continue
                    case "FantastecNFT": continue
                    case "Everbloom": continue
                    case "Domains": continue
                    case "EternalMoment": continue
                    case "ThingFund": continue
                    case "TFCItems": continue
                    case "Gooberz": continue
                    case "MintStoreItem": continue
                    case "BiscuitsNGroovy": continue
                    case "GeniaceNFT": continue
                    case "Xtingles": continue
                    case "Beam": continue
                    case "KOTD": continue
                    case "KlktnNFT": continue
                    case "KlktnNFT2": continue
                    case "RareRooms_NFT": continue
                    case "Crave": continue
                    case "CricketMoments": continue
                    case "SportsIconCollectible": continue
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
                    case "TuneGO": continue
                    case "TicalUniverse": d = self.getTicalUniverse(owner: owner, id: id)
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
                    case "NFTContract": d = self.getNFTContract(owner: owner, id: id)
                    case "Swaychain": continue
                    case "Maxar": continue
                    case "TheFabricantS2ItemNFT": d = self.getTheFabricantS2ItemNFT(owner: owner, id: id)
                    case "VnMiss": d = self.getVnMiss(owner: owner, id: id)
                    case "AvatarArt": d = self.getAvatarArt(owner: owner, id: id)
                    case "Dooverse": d = self.getDooverseNFT(owner: owner, id: id)
                    case "TrartContractNFT": d = self.getTrartContractNFT(owner: owner, id: id)
                    case "SturdyItems": continue
                    case "PartyMansionDrinksContract": d = self.getPartyMansionDrinksContractNFT(owner: owner, id: id)
                    case "CryptoPiggo": continue
                    case "Evolution": d = self.getEvolutionNFT(owner: owner, id: id)
                    case "Moments": d = self.getMomentsNFT(owner: owner, id: id)
                    case "MotoGPCard": d = self.getMotoGPCardNFT(owner: owner, id: id)
                    case "UFC_NFT": d = self.getUFCNFT(owner: owner, id: id)
                    case "Flovatar": continue
                    case "FlovatarComponent": continue
                    case "ByteNextMedalNFT": continue
                    case "RCRDSHPNFT": d = self.getRCRDSHPNFT(owner: owner, id: id)
                    case "Seussibles": d = self.getSeussibles(owner: owner, id: id)
                    case "MetaPanda": d = self.getMetaPanda(owner: owner, id: id)
                    case "Flunks": d = self.getFlunks(owner: owner, id: id)
                    default:
                        panic("adapter for NFT not found: ".concat(key))
                }
    
                NFTs.append(d)
            }
        }
    
        return NFTs
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
    
    
    pub fun getTicalUniverse(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "TicalUniverse",
            address: 0xfef48806337aabf1,
            storage_path: "TicalUniverse.CollectionStoragePath",
            public_path: "TicalUniverse.CollectionPublicPath",
            public_collection_name: "TicalUniverse.TicalUniverseCollectionPublic",
            external_domain: "tunegonft.com"
        )
    
        let col = owner.getCapability(TicalUniverse.CollectionPublicPath)
            .borrow<&{TicalUniverse.TicalUniverseCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCollectible(id: id)
        if nft == nil { return nil }
    
        let data = nft!.data
        let itemMetadata = TicalUniverse.getItemMetadata(itemId: data.itemId)!
        let editionNumber = data.serialNumber!
        let editionCount = TicalUniverse.getNumberCollectiblesInEdition(setId: data.setId, itemId: data.itemId)!
    
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
            media: [ NFTMedia(uri: itemMetadata["Asset"]!, mimetype: "video/mp4") ],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x2d2750f240198f91/contract/MatrixWorldFlowFestNFT
    
    
    pub fun getNFTContract(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData (
            name: "NFTContract",
            address: 0x1e075b24abe6eca6,
            storage_path: "NFTContract.CollectionStoragePath",
            public_path: "NFTContract.CollectionPublicPath",
            public_collection_name: "NFTContract.CollectionPublic",
            external_domain: "https://nowwhere.io/"
        )
    
        let col = owner.getCapability(NFTContract.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>()
        if col == nil { return nil }
    
        let nftData = col!.borrowNFT(id:id)
        var nftMetaData : {String:String} = {}
    
        let nft = NFTContract.getNFTDataById(nftId: id)!
        if nft == nil { return nil }
    
        let templateData = NFTContract.getTemplateById(templateId: nft!.templateID)
        let immutableData = templateData.getImmutableData()
    
        var templateDescription : {String:AnyStruct} = {}
        templateDescription = templateData.getImmutableData() as! {String: AnyStruct}
        var extras : {String:AnyStruct} = {}
        extras = templateDescription["extras"]! as! {String: AnyStruct}
        var description:String?= nil;
        if(extras["Description"] != nil){
            description = extras["Description"]! as? String
        }
    
        return NFTData (
            contract: contract,
            id: nftData.id,
            uuid: nftData.uuid,
            title: immutableData["title"]! as? String,
            description: description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: immutableData["contectValue"]! as? String, mimetype: "image")],
            metadata: {
                "editionNumber": nft!.mintNumber.toString(),
                "editionCount": templateData.issuedSupply.toString(),
                "artist": templateDescription["artist"]! as? String,
                "mintType": templateDescription["mintType"]! as? String,
                "contectType" :  templateDescription["contectType"]! as? String,
                "artistEmail" :  templateDescription["artistEmail"]! as? String,
                "contectValue" :  templateDescription["contectValue"]! as? String,
                "nftType" :  templateDescription["nftType"]! as? String,
                "rarity" :  templateDescription["rarity"]! as? String,
                "mintType" :  templateDescription["mintType"]! as? String
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xa4e9020ad21eb30b/contract/SwaychainNFT
    
    
    pub fun getQRLNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "QRL",
            address: 0xa4e9020ad21eb30b,
            storage_path: "QRLNFT.CollectionStoragePath",
            public_path: "QRLNFT.CollectionPublicPath",
            public_collection_name: "QRLNFT.QRLNFTCollectionPublic",
            external_domain: "https://swaychain.com/"
        )
    
        let col = owner.getCapability(QRLNFT.CollectionPublicPath)
            .borrow<&{QRLNFT.QRLNFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowQRLNFT(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nft!.name,
            description: nft!.description,
            external_domain_view_url: nft!.thumbnail,
            token_uri: nil,
            media: [NFTMedia(uri: nft!.thumbnail, mimetype: "image")],
            metadata: {
                "name": nft!.name,
                // "message": nft!.title,
                "description": nft!.description,
                "thumbnail": nft!.thumbnail
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xa4e9020ad21eb30b/contract/MaxarNFT
    
    
    pub fun getTheFabricantS2ItemNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "TheFabricantS2ItemNFT",
            address: 0x7752ea736384322f,
            storage_path: "TheFabricantS2ItemNFT.CollectionStoragePath",
            public_path: "TheFabricantS2ItemNFT.CollectionPublicPath",
            public_collection_name: "TheFabricantS2ItemNFT.ItemCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(TheFabricantS2ItemNFT.CollectionPublicPath)
            .borrow<&{TheFabricantS2ItemNFT.ItemCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowItem(id: id)!
        if nft == nil { return nil }
    
        let itemDataID = nft.item.itemDataID
        let itemData = TheFabricantS2ItemNFT.getItemData(id: itemDataID)
        let itemMetadata = itemData.getMetadata()
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nft!.name,
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: itemMetadata["itemVideo"]!.metadataValue, mimetype: "video"),
                    NFTMedia(uri: itemMetadata["itemImage"]!.metadataValue, mimetype: "image")],
            metadata: {
                "name": nft!.name,
                "primaryColor": itemMetadata["primaryColor"]!.metadataValue,
                "secondaryColor": itemMetadata["secondaryColor"]!.metadataValue,
                "coCreator": itemData.coCreator.toString(),
                "season": itemMetadata["season"]!.metadataValue
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x7c11edb826692404/contract/VnMiss
    
    
    pub fun getVnMiss(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "VnMiss",
            address: 0x7c11edb826692404,
            storage_path: "VnMiss.CollectionStoragePath",
            public_path: "VnMiss.CollectionPublicPath",
            public_collection_name: "VnMiss.VnMissCollectionPublic",
            external_domain: "https://hoahauhoanvuvietnam.avatarart.io"
        )
    
        let col = owner.getCapability(VnMiss.CollectionPublicPath)
            .borrow<&{VnMiss.VnMissCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowVnMiss(id: id)
        if nft == nil { return nil }
    
        let displayView = nft!.resolveView(Type<MetadataViews.Display>())!
        let display = displayView as! MetadataViews.Display
    
        let levelAsString = fun (level: UInt8): String {
             switch level {
                case VnMiss.Level.Bronze.rawValue:
                    return "Bronze"
    
                case VnMiss.Level.Silver.rawValue:
                    return "Silver"
    
                case VnMiss.Level.Diamond.rawValue:
                    return "Diamond"
            }
            return "Unknown"
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: display.name,
            description: display.description,
            external_domain_view_url: "https://avatarart.io/nfts/A.7c11edb826692404.VnMiss.NFT.".concat(nft!.id.toString()),
            token_uri: nil,
            media: [NFTMedia(uri: display.thumbnail.uri(), mimetype: "image")],
            metadata: {
                "name": display.name,
                "level": levelAsString(nft!.level),
                "editionNumber": nft!.id.toString(),
                "editionCount": "14200",
                "royaltyAddress": "0xe7da9bede73c8cc2",
                "royaltyPercentage": "5.0"
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x39eeb4ee6f30fc3f/contract/AADigital
    
    
    pub fun getAvatarArt(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "AADigital",
            address: 0x39eeb4ee6f30fc3f,
            storage_path: "AADigital.CollectionStoragePath",
            public_path: "AADigital.CollectionPublicPath",
            public_collection_name: "AADigital.AADigitalCollectionPublic",
            external_domain: "https://avatarart.io"
        )
    
        let col = owner.getCapability(AADigital.CollectionPublicPath)
            .borrow<&{AADigital.AADigitalCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowAADigital(id: id)
        if nft == nil { return nil }
    
        let displayView = nft!.resolveView(Type<MetadataViews.Display>())!
        let display = displayView as! MetadataViews.Display
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: display.name,
            description: display.description,
            external_domain_view_url: "https://avatarart.io/nfts/A.39eeb4ee6f30fc3f.AADigital.NFT.".concat(nft!.id.toString()),
            token_uri: nil,
            media: [NFTMedia(uri: "https://api.avatarart.io/upload".concat(display.thumbnail.uri()), mimetype: "image")],
            metadata: {
                "editionNumber": "1",
                "editionCount": AADigital.totalSupply.toString(),
                "royaltyAddress": "0xe7da9bede73c8cc2",
                "royaltyPercentage": "5.0"
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x66ad29c7d7465437/contract/DooverseItems
    
    
    pub fun getDooverseNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "DooverseItems",
            address: 0x66ad29c7d7465437,
            storage_path: "DooverseItems.CollectionStoragePath",
            public_path: "DooverseItems.CollectionPublicPath",
            public_collection_name: "DooverseItems.DooverseItemsCollectionPublic",
            external_domain: "https://dooverse.io/"
        )
    
        let col = owner.getCapability(DooverseItems.CollectionPublicPath)
            .borrow<&{DooverseItems.DooverseItemsCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowDooverseItem(id: id)
        if nft == nil { return nil }
    
        let metadata = nft!.getMetadata()
        let rawMetadata: {String : String?} = {}
        for key in metadata.keys {
            rawMetadata[key] = metadata[key]
        }
    
        if (!metadata.containsKey("editionNumber")) {
            rawMetadata.insert(key: "editionNumber", nft!.id.toString())
        }
        if (!metadata.containsKey("editionCount")) {
            rawMetadata.insert(key: "editionCount", DooverseItems.totalSupply.toString())
        }
        if (!metadata.containsKey("royaltyAddress")) {
            rawMetadata.insert(key: "royaltyAddress", "0x6b43b691ea37ee22")
        }
        if (!metadata.containsKey("royaltyPercentage")) {
            rawMetadata.insert(key: "royaltyPercentage", "5")
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "Dooverse Items NFT",
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x6f01a4b0046c1f87/contract/TrartContractNFT
    
    
    pub fun getTrartContractNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "TrartContractNFT",
            address: 0x6f01a4b0046c1f87,
            storage_path: "/storage/TrartContractNFTCollection",
            public_path: "/public/TrartContractNFTCollection",
            public_collection_name: "TrartContractNFT.ICardCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(TrartContractNFT.CollectionPublicPath)
            .borrow<&{TrartContractNFT.ICardCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCard(id: id)
        if nft == nil { return nil }
    
        let metadata = TrartContractNFT.getMetadataForCardID(cardID: nft!.id)!.data
        let rawMetadata: {String:String?} = {
            "editionNumber": metadata["SERIES ID"]??"",
            "editionCount": metadata["TOTAL ISSUANCE"]??"",
            "royaltyAddress": "0x416e01b78d5b45ff",
            "royaltyPercentage": "2.5"
        }
        for key in metadata.keys {
            rawMetadata.insert(key: key, metadata[key])
        }
    
        var nftTitle: String? = metadata["NAME"]
        if nftTitle == nil && metadata["CARD NUMBER"] != nil {
           nftTitle = (metadata["CARD SERIES"]!=nil?metadata["CARD SERIES"]!.concat(" - "):"").concat(metadata["CARD NUMBER"]!)
        }
    
        let ipfsScheme = "ipfs://"
        let httpsScheme = "https://"
    
        var ipfsURL: String? = nil
        let metadataUrl: String = metadata["URI"]?? metadata["URL"]?? ""
    
        if metadataUrl.length > ipfsScheme.length && self.stringStartsWith(string: metadataUrl, prefix: ipfsScheme) {
            ipfsURL = "https://trartgateway.mypinata.cloud/ipfs/".concat(metadataUrl.slice(from: ipfsScheme.length, upTo: metadataUrl.length));
        } else if metadataUrl.length > httpsScheme.length &&self.stringStartsWith(string: metadataUrl, prefix: httpsScheme) {
            ipfsURL = metadataUrl
        }
    
        let mediaArray:[NFTMedia] = ipfsURL!=nil?[NFTMedia(uri: ipfsURL, mimetype: "image")]:[]
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.id,
            title: nftTitle,
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: mediaArray,
            metadata: rawMetadata,
        )
    }
    
    
    // https://flow-view-source.com/mainnet/account/0x427ceada271aa0b1/contract/SturdyItems
    
    
    pub fun getPartyMansionDrinksContractNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "PartyMansionDrinksContract",
            address: 0x34f2bf4a80bb0f69,
            storage_path: "PartyMansionDrinksContract.CollectionStoragePath",
            public_path: "PartyMansionDrinksContract.CollectionPublicPath",
            public_collection_name: "PartyMansionDrinksContract.DrinkCollectionPublic",
            external_domain: "https://partymansion.io"
        )
    
        let col = owner.getCapability(PartyMansionDrinksContract.CollectionPublicPath)
            .borrow<&{PartyMansionDrinksContract.DrinkCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowDrink(id: id)
        if nft == nil { return nil }
    
        let rawMetadata: {String : String?} = {}
    
        rawMetadata.insert(key: "id", nft!.id.toString())
        rawMetadata.insert(key: "name", nft!.data.title)
        rawMetadata.insert(key: "originalOwner", nft!.originalOwner.toString())
        rawMetadata.insert(key: "description", nft!.description())
        rawMetadata.insert(key: "imageCID", nft!.imageCID())
        rawMetadata.insert(key: "drinkID", nft!.data.drinkID.toString())
        rawMetadata.insert(key: "collectionID", nft!.data.collectionID.toString())
        rawMetadata.insert(key: "rarity", nft!.data.rarity.toString())
        rawMetadata.insert(key: "drinkID", nft!.data.drinkID.toString())
    
        for d in nft!.data.metadata.keys {
            if nft!.data.metadata[d]!.getType() == Type<String>() {
                let s = nft!.data.metadata[d]! as! String
                rawMetadata.insert(key: d, s)
            }
        }
    
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "PartyMansionDrinksContract",
            description: nft!.description(),
            external_domain_view_url: nil,
            token_uri: nil,
            media: [
                NFTMedia(uri: "ipfs://".concat(nft!.imageCID()), mimetype: "image")
            ],
            metadata: rawMetadata
        )
    }
    
    
    // https://flow-view-source.com/mainnet/account/0xd3df824bf81910a4/contract/CryptoPiggo
    
    
    pub fun getEvolutionNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Evolution",
            address: 0xf4264ac8f3256818,
            storage_path: "/storage/f4264ac8f3256818_Evolution_Collection",
            public_path: "/public/f4264ac8f3256818_Evolution_Collection",
            public_collection_name: "Evolution.EvolutionCollectionPublic",
            external_domain: "https://www.evolution-collect.com/"
        )
    
        let col = owner.getCapability(/public/f4264ac8f3256818_Evolution_Collection)
            .borrow<&{Evolution.EvolutionCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCollectible(id: id)
        if nft == nil { return nil }
    
        let metadata = Evolution.getItemMetadata(itemId: nft!.data.itemId)!
        let rawMetadata: {String : String?} = {}
        for key in metadata.keys {
            rawMetadata[key] = metadata[key]
        }
    
        if (!metadata.containsKey("name")) {
            rawMetadata.insert(key: "name", metadata["Title"]!.concat(" #").concat(nft!.data.serialNumber.toString()))
        }
        if (!metadata.containsKey("image")) {
            rawMetadata.insert(key: "image", "https://storage.viv3.com/0xf4264ac8f3256818/mv/".concat(nft!.data.itemId.toString()))
        }
        if (!metadata.containsKey("contentType")) {
            rawMetadata.insert(key: "contentType", "video")
        }
    
        let external_domain_view_url = "https://storage.viv3.com/0xf4264ac8f3256818/mv/".concat(nft!.data.itemId.toString())
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "Evolution",
            description: nil,
            external_domain_view_url: nil ,
            token_uri: nil,
            media: [
                NFTMedia(uri: external_domain_view_url, mimetype: "video")
            ],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xd4ad4740ee426334/contract/Moments
    
    
    pub fun getMomentsNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Jambb Moments",
            address: 0xd4ad4740ee426334,
            storage_path: "Moments.CollectionStoragePath",
            public_path: "Moments.CollectionPublicPath",
            public_collection_name: "Moments.CollectionPublic",
            external_domain: "https://www.jambb.com/"
        )
    
        let col = owner.getCapability(Moments.CollectionPublicPath)
            .borrow<&{Moments.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowMoment(id: id)
        if nft == nil { return nil }
    
        let metadata = nft!.getMetadata()
        let rawMetadata: {String : String?} = {}
        for key in metadata.contentCredits.keys {
            rawMetadata[key] = metadata.contentCredits[key]
        }
    
            rawMetadata.insert(key: "id", metadata.id.toString())
            rawMetadata.insert(key: "serialNumber", metadata.serialNumber.toString())
            rawMetadata.insert(key: "contentID", metadata.contentID.toString())
            rawMetadata.insert(key: "contentCreator", metadata.contentCreator.toString())
            rawMetadata.insert(key: "contentName", metadata.contentName)
            rawMetadata.insert(key: "contentDescription", metadata.contentDescription)
            rawMetadata.insert(key: "previewImage", metadata.previewImage)
            rawMetadata.insert(key: "videoURI", metadata.videoURI)
            rawMetadata.insert(key: "videoHash", metadata.videoHash)
            rawMetadata.insert(key: "seriesID", metadata.seriesID.toString())
            rawMetadata.insert(key: "seriesName", metadata.seriesName)
            rawMetadata.insert(key: "seriesArt", metadata.seriesArt)
            rawMetadata.insert(key: "seriesDescription", metadata.seriesDescription)
            rawMetadata.insert(key: "setID", metadata.setID.toString())
            rawMetadata.insert(key: "setName", metadata.setName)
            rawMetadata.insert(key: "setArt", metadata.setArt)
            rawMetadata.insert(key: "setDescription", metadata.setDescription)
            if metadata.retired {
                rawMetadata.insert(key: "retired", "true")
            } else {
                rawMetadata.insert(key: "retired", "false")
            }
            rawMetadata.insert(key: "contentEditionID", metadata.contentEditionID.toString())
            rawMetadata.insert(key: "rarity", metadata.rarity)
            rawMetadata.insert(key: "run", metadata.run.toString())
    
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "Jambb Moments",
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [
                NFTMedia(uri: metadata.previewImage, mimetype: "image") ,
                NFTMedia(uri: metadata.videoURI, mimetype: "video")
            ],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xa49cc0ee46c54bfb/contract/MotoGPCard
    
    
    pub fun getMotoGPCardNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "MotoGPCard",
            address: 0xa49cc0ee46c54bfb,
            storage_path: "/storage/motogpCardCollection",
            public_path: "/public/motogpCardCollection",
            public_collection_name: "MotoGPCard.ICardCollectionPublic",
            external_domain: "https://motogp-ignition.com/"
        )
    
        let col = owner.getCapability(/public/motogpCardCollection)
            .borrow<&{MotoGPCard.ICardCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCard(id: id)
        if nft == nil { return nil }
    
        let metadata = nft!.getCardMetadata()!
        let rawMetadata: {String : String?} = {}
    
        for key in metadata.data.keys {
            rawMetadata[key] = metadata.data[key]
        }
    
        rawMetadata.insert(key: "cardID", metadata.cardID.toString())
    
        rawMetadata.insert(key: "name", metadata.name)
    
        rawMetadata.insert(key: "description", metadata.description)
    
        rawMetadata.insert(key: "imageUrl", metadata.imageUrl)
    
         let address=owner.address!
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "MotoGPCard",
            description: metadata.description,
            external_domain_view_url: "https://motogp-ignition.com/nft/card/".concat(id.toString()).concat("?owner=").concat(address.toString()),
            token_uri: nil,
            media: [NFTMedia(uri:metadata.imageUrl, mimetype: "image")],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x329feb3ab062d289/contract/UFC_NFT
    
    
    pub fun getUFCNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "UFC_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "UFC_NFT.CollectionStoragePath",
            public_path: "UFC_NFT.CollectionPublicPath",
            public_collection_name: "UFC_NFT.UFC_NFTCollectionPublic",
            external_domain: "https://www.ufcstrike.com"
        )
    
        let col = owner.getCapability(UFC_NFT.CollectionPublicPath)
            .borrow<&{UFC_NFT.UFC_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowUFC_NFT(id: id)
        if nft == nil { return nil }
    
        var metadata = UFC_NFT.getSetMetadata(setId: nft!.setId)!
        let rawMetadata: {String : String?} = {}
        for key in metadata.keys {
            rawMetadata[key] = metadata[key]
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "UFC_NFT",
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: metadata["image"]!, mimetype: "video" )],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x921ea449dffec68a/contract/Flovatar
    
    
    pub fun getRCRDSHPNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "RCRDSHPNFT",
            address: 0x6c3ff40b90b928ab,
            storage_path: "RCRDSHPNFT.collectionStoragePath",
            public_path: "RCRDSHPNFT.collectionPublicPath",
            public_collection_name: "RCRDSHPNFT.RCRDSHPNFTCollectionPublic",
            external_domain: "https://app.rcrdshp.com/"
        )
    
        let col = owner.getCapability(RCRDSHPNFT.collectionPublicPath)
            .borrow<&{RCRDSHPNFT.RCRDSHPNFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowRCRDSHPNFT(id: id)
        if nft == nil { return nil }
    
        let displayView = nft!.resolveView(Type<MetadataViews.Display>())!
        let display = displayView as! MetadataViews.Display
        let httpFile = display.thumbnail as! MetadataViews.HTTPFile
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: display.name,
            description: display.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: httpFile.uri(), mimetype: "image")],
            metadata: {}
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x321d8fcde05f6e8c/contract/Seussibles
    
    
    pub fun getSeussibles(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Seussibles",
            address: 0x321d8fcde05f6e8c,
            storage_path: "Seussibles.CollectionStoragePath",
            public_path: "Seussibles.PublicCollectionPath",
            public_collection_name: "",
            external_domain: "https://seussibles.com/"
        )
    
        let col = owner.getCapability<&AnyResource{MetadataViews.ResolverCollection}>(Seussibles.PublicCollectionPath)
            .borrow<>()
        if col == nil { return nil }
    
        let nftResolver = col!.borrowViewResolver(id: id)
        if nftResolver == nil { return nil }
    
        let displayView = nftResolver!.resolveView(Type<MetadataViews.Display>())!
        let display = displayView as! MetadataViews.Display
        let httpFile = display.thumbnail as! MetadataViews.HTTPFile
    
        return NFTData(
            contract: contract,
            id: id,
            uuid: nil,
            title: display.name,
            description: display.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: httpFile.uri(), mimetype: "image")],
            metadata: {}
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xf2af175e411dfff8/contract/MetaPanda
    
    
    pub fun getMetaPanda(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "MetaPanda",
            address: 0xf2af175e411dfff8,
            storage_path: "MetaPanda.CollectionStoragePath",
            public_path: "MetaPanda.CollectionPublicPath",
            public_collection_name: "",
            external_domain: "https://metapandaclub.com/"
        )
    
        let col = owner.getCapability<&AnyResource{MetadataViews.ResolverCollection}>(MetaPanda.CollectionPublicPath)
            .borrow<>()
        if col == nil { return nil }
    
        let nftResolver = col!.borrowViewResolver(id: id)
        if nftResolver == nil { return nil }
    
        let displayView = nftResolver!.resolveView(Type<MetadataViews.Display>())!
        let display = displayView as! MetadataViews.Display
        let httpFile = display.thumbnail as! MetadataViews.HTTPFile
    
        return NFTData(
            contract: contract,
            id: id,
            uuid: nil,
            title: display.name,
            description: display.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: httpFile.uri(), mimetype: "image")],
            metadata: {}
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x807c3d470888cc48/contract/Flunks
    
    
    pub fun getFlunks(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Flunks",
            address: 0x807c3d470888cc48,
            storage_path: "Flunks.CollectionStoragePath",
            public_path: "Flunks.CollectionPublicPath",
            public_collection_name: "Flunks.FlunksCollectionPublic",
            external_domain: "https://flunks.io/"
        )
    
        let col = owner.getCapability(Flunks.CollectionPublicPath)
            .borrow<&{Flunks.FlunksCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowFlunks(id: id)
        if nft == nil { return nil }
    
        let displayView = nft!.resolveView(Type<MetadataViews.Display>())!
        let display = displayView as! MetadataViews.Display
        let httpFile = display.thumbnail as! MetadataViews.HTTPFile
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: display.name,
            description: display.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: httpFile.uri(), mimetype: "image")],
            metadata: {}
        )
    }

    // Same method signature as getNFTIDs.cdc for backwards-compatability.
    pub fun getNFTIDs(ownerAddress: Address): {String: [UInt64]} {
        let owner = getAccount(ownerAddress)
        let ids: {String: [UInt64]} = {}
    
    
        if let col = owner.getCapability(NFTContract.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["NFTContract"] = col.getIDs()
        }
    
        if let col = owner.getCapability(QRLNFT.CollectionPublicPath)
        .borrow<&{QRLNFT.QRLNFTCollectionPublic}>() {
            ids["QRL"] = col.getIDs()
        }
    
        if let col = owner.getCapability(TheFabricantS2ItemNFT.CollectionPublicPath)
        .borrow<&{TheFabricantS2ItemNFT.ItemCollectionPublic}>() {
            ids["TheFabricantS2ItemNFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(VnMiss.CollectionPublicPath)
        .borrow<&{VnMiss.VnMissCollectionPublic}>() {
            ids["VnMiss"] = col.getIDs()
        }
    
        if let col = owner.getCapability(AADigital.CollectionPublicPath)
        .borrow<&{AADigital.AADigitalCollectionPublic}>() {
            ids["AvatarArt"] = col.getIDs()
        }
        if let col = owner.getCapability(DooverseItems.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["Dooverse"] = col.getIDs()
        }
        if let col = owner.getCapability(/public/motogpCardCollection)
        .borrow<&{MotoGPCard.ICardCollectionPublic}>() {
            ids["MotoGPCard"] = col.getIDs()
        }
        if let col = owner.getCapability(PartyMansionDrinksContract.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["PartyMansionDrinksContract"] = col.getIDs()
        }
        if let col = owner.getCapability(TrartContractNFT.CollectionPublicPath)
        .borrow<&{TrartContractNFT.ICardCollectionPublic}>() {
            ids["TrartContractNFT"] = col.getIDs()
        }
        if let col = owner.getCapability(TicalUniverse.CollectionPublicPath)
        .borrow<&{TicalUniverse.TicalUniverseCollectionPublic}>() {
            ids["TicalUniverse"] = col.getIDs()
        }
        if let col = owner.getCapability(/public/f4264ac8f3256818_Evolution_Collection)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["Evolution"] = col.getIDs()
        }
        if let col = owner.getCapability(Moments.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["Moments"] = col.getIDs()
        }
    
        if let col = owner.getCapability(UFC_NFT.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["UFC_NFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(RCRDSHPNFT.collectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["RCRDSHPNFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(Seussibles.PublicCollectionPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["Seussibles"] = col.getIDs()
        }
    
        if let col = owner.getCapability(MetaPanda.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["MetaPanda"] = col.getIDs()
        }
    
        if let col = owner.getCapability(Flunks.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>() {
            ids["Flunks"] = col.getIDs()
        }
    
        return ids
    }
}