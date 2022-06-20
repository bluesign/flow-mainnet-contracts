// AUTO-GENERATED CONTRACT
import AllDay from 0xe4cf4bdc1751c65d
import Andbox_NFT from 0x329feb3ab062d289
import BarterYardClubWerewolf from 0x28abb9f291cadaf2
import BarterYardPackNFT from 0xa95b021cf8a30d80
import Canes_Vault_NFT from 0x329feb3ab062d289
import Costacos_NFT from 0x329feb3ab062d289
import DayNFT from 0x1600b04bf033fb99
import DieselNFT from 0x497153c597783bc3
import GooberXContract from 0x34f2bf4a80bb0f69
import HaikuNFT from 0xf61e40c19db2a9e2
import MetadataViews from 0x1d7e57aa55817448
import MiamiNFT from 0x429a19abea586a3e
import MintStoreItem from 0x20187093790b9aef
import NonFungibleToken from 0x1d7e57aa55817448
import PackNFT from 0xe4cf4bdc1751c65d
import TFCItems from 0x81e95660ab5308e1
import TheFabricantMysteryBox_FF1 from 0xa0cbe021821c0965
import ZeedzINO from 0x62b3063fbe672fc8

/*
    A wrapper contract around the script provided by the Alchemy GitHub respository.
    Allows for on-chain storage of NFT Metadata, allowing consumers to query upon.
    This contract will be periodically updated based on new onboarding PRs and deployed.
    Any consumers calling the public methods below will retrieve the latest and greatest data.
*/
pub contract AlchemyMetadataWrapperMainnetShard2 {
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
                    case "Andbox_NFT": d = self.getAndbox_NFT(owner: owner, id: id)
                    case "FantastecNFT": continue
                    case "Everbloom": continue
                    case "Domains": continue
                    case "EternalMoment": continue
                    case "ThingFund": continue
                    case "TFCItems": d = self.getTFCItems(owner: owner, id: id)
                    case "Gooberz": d = self.getGooberz(owner: owner, id: id)
                    case "MintStoreItem": d = self.getMintStoreItem(owner: owner, id: id)
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
                    case "TheFabricantMysteryBox_FF1": d = self.getTheFabricantMysteryBox_FF1(owner: owner, id: id)
                    case "DieselNFT": d = self.getDieselNFT(owner: owner, id: id)
                    case "MiamiNFT": d = self.getMiamiNFT(owner: owner, id: id)
                    case "Bitku": d = self.getBitku(owner: owner, id: id)
                    case "FlowFans": continue
                    case "AllDay": d = self.getAllDay(owner: owner, id: id)
                    case "PackNFT": d = self.getAllDayPackNFT(owner: owner, id: id)
                    case "ItemNFT": continue
                    case "TheFabricantS1ItemNFT": continue
                    case "ZeedzINO" : d = self.getZeedzINO(owner: owner, id: id)
                    case "Kicks" : continue
                    case "BarterYardPack": d = self.getBarterYardPack(owner: owner, id: id)
                    case "BarterYardClubWerewolf": d = self.getBarterYardClubWerewolf(owner: owner, id: id)
                    case "DayNFT" : d = self.getDayNFT(owner: owner, id: id)
                    case "Costacos_NFT": d = self.getCostacosNFT(owner: owner, id: id)
                    case "Canes_Vault_NFT": d = self.getCanesVaultNFT(owner: owner, id: id)
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
    
    
    pub fun getAndbox_NFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Andbox_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "Andbox_NFT.CollectionStoragePath",
            public_path: "Andbox_NFT.CollectionPublicPath",
            public_collection_name: "Andbox_NFT.Andbox_NFTCollectionPublic",
            external_domain: "https://andbox.shops.nftbridge.com/"
        )
    
        let col = owner.getCapability(Andbox_NFT.CollectionPublicPath)
            .borrow<&{Andbox_NFT.Andbox_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowAndbox_NFT(id: id)
        if nft == nil { return nil }
    
        let setMeta = Andbox_NFT.getSetMetadata(setId: nft!.setId)!
        let seriesMeta = Andbox_NFT.getSeriesMetadata(
            seriesId: Andbox_NFT.getSetSeriesId(setId: nft!.setId)!
        )
    
        let seriesId = Andbox_NFT.getSetSeriesId(setId: nft!.setId)!
        let nftEditions = Andbox_NFT.getSetMaxEditions(setId: nft!.setId)!
        let externalTokenViewUrl = "https://andbox.shops.nftbridge.com/tokens/".concat(nft!.id.toString())
    
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
            media: [NFTMedia(uri: setMeta!["image"], mimetype: mimeType),
                NFTMedia(uri: setMeta!["preview"], mimetype: "image")],
            metadata: {
                "editionNumber": nft!.editionNum.toString(),
                "editionCount": nftEditions!.toString(),
                "set_id": nft!.setId.toString(),
                "series_id": seriesId!.toString()
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x329feb3ab062d289/contract/RareRooms_NFT
    
    
    pub fun getTFCItems(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "TFCItems",
            address: 0x81e95660ab5308e1,
            storage_path: "/storage/TFCItemsCollection",
            public_path: "/public/TFCItemsCollection",
            public_collection_name: "TFCItem.TFCItemsCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(TFCItems.CollectionPublicPath)!
        .borrow<&{TFCItems.TFCItemsCollectionPublic}>()
    
        if col == nil { return nil }
    
        let nft = col!.borrowTFCItem(id: id)
        if nft == nil { return nil }
    
        let metadata = nft!.getMetadata()
        let rawMetadata: {String:String?} = {}
        for key in metadata!.keys {
            rawMetadata.insert(key: key, metadata![key])
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: metadata["Title"]!,
            description: nil,
            external_domain_view_url: "thefootballclub.com",
            token_uri: nil,
            media: [NFTMedia(uri: metadata["URL"]!, mimetype: "image")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x34f2bf4a80bb0f69/contract/GooberXContract
    
    
    pub fun getGooberz(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "GooberXContract",
            address: 0x34f2bf4a80bb0f69,
            storage_path: "GooberXContract.CollectionStoragePath",
            public_path: "GooberXContract.CollectionPublicPath",
            public_collection_name: "GooberXContract.GooberCollectionPublic",
            external_domain: "partymansion.io"
        )
    
        let col = owner.getCapability(GooberXContract.CollectionPublicPath)
            .borrow<&{GooberXContract.GooberCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowGoober(id: id)
        if nft == nil { return nil }
    
        let title = "Goober #".concat(nft!.id.toString())
        let description = "Goober living in the party mansion"
        let external_domain_view_url = "https://partymansion.io/gooberz/".concat(nft!.id.toString())
    
        let rawMetadata: {String:String?} = {}
    
        for key in nft!.data!.metadata!.keys {
            if nft!.data!.metadata![key]!.getType().isSubtype(of: Type<Number>()) {
                rawMetadata.insert(key: key, (nft!.data!.metadata![key]! as! Number).toString())
            } else if nft!.data!.metadata![key]!.getType().isSubtype(of: Type<String>()) {
                rawMetadata.insert(key: key, (nft!.data!.metadata![key]! as! String))
            }
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: title,
            description: description,
            external_domain_view_url: external_domain_view_url,
            token_uri: nil,
            media: [NFTMedia(uri: nft!.data!.uri, mimetype: "image")],
            metadata: rawMetadata,
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x20187093790b9aef/contract/MintStoreItem
    // https://flow-view-source.com/testnet/account/0x985d410b577fd4a1/contract/MintStoreItem
    
    
    pub fun getMintStoreItem(owner: PublicAccount, id: UInt64): NFTData? {
    
    
        let col = owner.getCapability(MintStoreItem.CollectionPublicPath)
            .borrow<&{MintStoreItem.MintStoreItemCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowMintStoreItem(id: id)
        if nft == nil { return nil }
    
        let editionData = MintStoreItem.EditionData(editionID: nft!.data.editionID)!
        let description = editionData!.metadata["description"]!;
        let merchantName = MintStoreItem.getMerchant(merchantID:nft!.data.merchantID)!
    
         var external_domain = ""
         switch merchantName {
            case "Bulls":
                external_domain =  "https://bulls.mint.store"
                break;
            case "Charlotte Hornets":
                external_domain =  "https://hornets.mint.store"
                break;
            default:
                external_domain =  ""
         }
    
         if editionData!.metadata["nftType"]! == "Type C" {
             external_domain =  "https://misa.art/collections/nft"
         }
    
    
        let contract = NFTContractData(
            name: merchantName,
            address: 0x985d410b577fd4a1,
            storage_path: "MintStoreItem.CollectionStoragePath",
            public_path: "MintStoreItem.CollectionPublicPath",
            public_collection_name: "MintStoreItem.MintStoreItemCollectionPublic",
            external_domain: external_domain
        )
    
    
        let rawMetadata: {String: String?} = {
            "merchantID": nft!.data.merchantID.toString(),
            "merchantName": merchantName,
            "editionID": editionData!.editionID.toString(),
            "numberOfItemsMinted": editionData!.numberOfItemsMinted.toString(),
            "printingLimit": editionData!.printingLimit!.toString(),
            "editionNumber": nft!.data.editionNumber.toString(),
            "description": editionData!.metadata["description"]!,
            "name":editionData!.metadata["name"]!,
            "nftType":editionData!.metadata["nftType"]!,
            "editionCount": editionData!.printingLimit!.toString(),
            "royaltyAddress": editionData!.metadata["royaltyAddress"],
            "royaltyPercentage": editionData!.metadata["royaltyPercentage"]
        }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: editionData.name,
            description: description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: editionData!.metadata["mediaURL"], mimetype: editionData!.metadata["mimetype"])],
            metadata: rawMetadata
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x7859c48816bfea3c/contract/BnGNFT
    
    
    pub fun getTheFabricantMysteryBox_FF1(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "TheFabricantMysteryBox_FF1",
            address: 0xa0cbe021821c0965,
            storage_path: "/storage/FabricantCollection001",
            public_path: "/public/FabricantCollection001",
            public_collection_name: "TheFabricantMysteryBox_FF1.FabricantCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(/public/FabricantCollection001)
            .borrow<&{TheFabricantMysteryBox_FF1.FabricantCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowFabricant(id: id)!
        if nft == nil { return nil }
    
        let dataID = nft.fabricant.fabricantDataID
        let fabricantData = TheFabricantMysteryBox_FF1.getFabricantData(id: dataID)
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nil,
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: fabricantData.mainImage, mimetype: "image")],
            metadata: {},
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x497153c597783bc3/contract/DieselNFT
    
    
    pub fun getDieselNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "DieselNFT",
            address: 0x497153c597783bc3,
            storage_path: "/storage/DieselCollection001",
            public_path: "/public/DieselCollection001",
            public_collection_name: "DieselNFT.DieselCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(/public/DieselCollection001)
            .borrow<&{DieselNFT.DieselCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowDiesel(id: id)!
        if nft == nil { return nil }
    
        let dataID = nft.diesel.dieselDataID
        let dieselData = DieselNFT.getDieselData(id: dataID)
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: dieselData.name,
            description: dieselData.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: dieselData.mainVideo, mimetype: "video")],
            metadata: {},
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x429a19abea586a3e/contract/MiamiNFT
    
    
    pub fun getMiamiNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "MiamiNFT",
            address: 0x429a19abea586a3e,
            storage_path: "/storage/MiamiCollection001",
            public_path: "/public/MiamiCollection001",
            public_collection_name: "MiamiNFT.MiamiCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(/public/MiamiCollection001)
            .borrow<&{MiamiNFT.MiamiCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowMiami(id: id)!
        if nft == nil { return nil }
    
        let dataID = nft.miami.miamiDataID
        let miamiData = MiamiNFT.getMiamiData(id: dataID)
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: miamiData.name,
            description: miamiData.description,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [NFTMedia(uri: miamiData.mainVideo, mimetype: "video")],
            metadata: {
                "creator": miamiData.creator.toString(),
                "season": miamiData.season
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xf61e40c19db2a9e2/contract/HaikuNFT
    
    
    pub fun getBitku(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Bitku",
            address: 0xf61e40c19db2a9e2,
            storage_path: "/storage/BitkuCollection",
            public_path: "/public/BitkuCollection",
            public_collection_name: "HaikuNFT.HaikuCollectionPublic",
            external_domain: "bitku.art"
        )
    
        let col = owner.getCapability(HaikuNFT.HaikuCollectionPublicPath)
            .borrow<&{HaikuNFT.HaikuCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowHaiku(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nil,
            description: nft!.text,
            external_domain_view_url: "https://bitku.art/#".concat(owner.address.toString()).concat("/").concat(nft!.id.toString()),
            token_uri: nil,
            media: [],
            metadata: {
                "text": nft!.text
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x99fed1e8da4c3431/contract/FlowChinaBadge
    
    
    pub fun getAllDay(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "AllDay",
            address: 0xe4cf4bdc1751c65d,
            storage_path: "AllDay.CollectionStoragePath",
            public_path: "AllDay.CollectionPublicPath",
            public_collection_name: "AllDay.MomentNFTCollectionPublic",
            external_domain: "https://nflallday.com/"
        )
    
        let col = owner.getCapability(AllDay.CollectionPublicPath)
            .borrow<&{AllDay.MomentNFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowMomentNFT(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: "Moment".concat(nft!.id.toString()).concat("-Edition").concat(nft!.editionID.toString()).concat("-SerialNumber").concat(nft!.serialNumber.toString()),
            description: nil,
            external_domain_view_url: nil,
            token_uri: nil,
            media: [],
            metadata: {},
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xe4cf4bdc1751c65d/contract/PackNFT
    
    
    pub fun getAllDayPackNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "PackNFT",
            address: 0xe4cf4bdc1751c65d,
            storage_path: "PackNFT.CollectionStoragePath",
            public_path: "PackNFT.CollectionPublicPath",
            public_collection_name: "NonFungibleToken.CollectionPublic",
            external_domain: "https://nflallday.com/"
        )
    
        let col = owner.getCapability(PackNFT.CollectionPublicPath)
            .borrow<&{NonFungibleToken.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowNFT(id: id)
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
            metadata: {},
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xfc91de5e6566cc7c/contract/ItemNFT
    
    
    pub fun getZeedzINO(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "ZeedzINO",
            address: 0x62b3063fbe672fc8,
            storage_path: "/storage/ZeedzINOCollection",
            public_path: "/public/ZeedzINOCollection",
            public_collection_name: "ZeedzINO.ZeedzCollectionPublic",
            external_domain: ""
        )
    
        let col = owner.getCapability(/public/ZeedzINOCollection)
            .borrow<&{ZeedzINO.ZeedzCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowZeedle(id: id)
        if nft == nil { return nil }
    
        return NFTData(
            contract: contract,
            id: nft!.id,
            uuid: nft!.uuid,
            title: nft!.name,
            description: nft!.description,
            external_domain_view_url: "https:/www.zeedz.io",
            token_uri: nil,
            media: [NFTMedia(uri: "https://zeedz.mypinata.cloud/ipfs/".concat(nft!.imageURI), mimetype: "image")],
            metadata: {
                "typeID": nft!.typeID.toString(),
                "evoultionStage": nft!.evolutionStage.toString(),
                "serialNumber": nft!.serialNumber,
                "editionNumber": nft!.edition.toString(),
                "editionCount": nft!.editionCap.toString(),
                "rarity": nft!.rarity,
                "carbonOffset": nft!.carbonOffset.toString()
            },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0xf3cc54f4d91c2f6c/contract/Kicks
    
    
    pub fun getBarterYardPack(owner: PublicAccount, id: UInt64): NFTData? {
      let contract = NFTContractData(
            name: "BarterYardPack",
            address: 0xa95b021cf8a30d80,
            storage_path: "BarterYardPackNFT.CollectionStoragePath",
            public_path: "BarterYardPackNFT.CollectionPublicPath",
            public_collection_name: "BarterYardPackNFT.BarterYardPackNFTCollectionPublic",
            external_domain: "https://barteryard.club"
        )
    
      let collection = owner.getCapability(BarterYardPackNFT.CollectionPublicPath)
            .borrow<&{ BarterYardPackNFT.BarterYardPackNFTCollectionPublic }>()!
      if collection == nil { return nil }
    
      let nft = collection.borrowBarterYardPackNFT(id: id)!
          // Get the basic display information for this NFT
      let view = nft.resolveView(Type<MetadataViews.Display>())!
      let display = view as! MetadataViews.Display
      let ipfsFile = display.thumbnail as! MetadataViews.IPFSFile
      let packPartView = nft.resolveView(Type<BarterYardPackNFT.PackMetadataDisplay>())!
      let packMetadata = packPartView as! BarterYardPackNFT.PackMetadataDisplay
      let edition = packMetadata.edition
      return NFTData(
        contract: contract,
        id: id,
        uuid: nft.uuid,
        title: display.name.concat(" #").concat(edition.toString()),
        description: display.description,
        external_domain_view_url: "https://barteryard.club/nft/".concat(id.toString()),
        token_uri: nil,
        media: [NFTMedia(uri: "https://ipfs.io/ipfs/".concat(ipfsFile.cid), mimetype: "image")],
        metadata: {
          "pack": display.name
        },
      )
    }
    // https://flow-view-source.com/mainnet/account/0x28abb9f291cadaf2/contract/BarterYardClubWerewolf
    
    
    pub fun getBarterYardClubWerewolf(owner: PublicAccount, id: UInt64): NFTData? {
      let contract = NFTContractData(
            name: "BarterYardClubWerewolf",
            address: 0x28abb9f291cadaf2,
            storage_path: "BarterYardClubWerewolf.CollectionStoragePath",
            public_path: "BarterYardClubWerewolf.CollectionPublicPath",
            public_collection_name: "BarterYardClubWerewolf.CollectionPublic",
            external_domain: "https://app.barteryard.club"
        )
        let collection = owner.getCapability<&{MetadataViews.ResolverCollection}>(BarterYardClubWerewolf.CollectionPublicPath).borrow()
            ?? panic("Could not borrow a reference to the collection")
        let nft = collection.borrowViewResolver(id: id)
        let view = nft.resolveView(Type<BarterYardClubWerewolf.CompleteDisplay>())!
        let display = view as! BarterYardClubWerewolf.CompleteDisplay
    
        let background = display.getAttributes()[0].value
        let fur = display.getAttributes()[1].value
        let body = display.getAttributes()[2].value
        let eyes = display.getAttributes()[4].value
        let glasses = display.getAttributes()[5].value
        let headgear = display.getAttributes()[6].value
        let item = display.getAttributes()[7].value
        let mouth = display.getAttributes()[3].value
    
        return NFTData(
          contract: contract,
          id: id,
          uuid: nil,
          title: display.name,
          description: display.description,
          external_domain_view_url: "https://barteryard.club/nft/".concat(id.toString()),
          token_uri: nil,
          media: [NFTMedia(uri: "https://ipfs.io/ipfs/".concat(display.thumbnail.cid).concat("/").concat(display.thumbnail.path!), mimetype: "image")],
          metadata: {
            "Background": background,
            "Fur": fur,
            "Body": body,
            "Eyes": eyes,
            "Glasses": glasses,
            "Headgear": headgear,
            "Item": item,
            "Mouth": mouth
          },
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x1600b04bf033fb99/contract/DayNFT
    
    
    pub fun getDayNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "DayNFT",
            address: 0x1600b04bf033fb99,
            storage_path: "DayNFT.CollectionStoragePath",
            public_path: "DayNFT.CollectionPublicPath",
            public_collection_name: "DayNFT.CollectionPublic",
            external_domain: "https://day-nft.io"
        )
    
        let col = owner.getCapability(DayNFT.CollectionPublicPath)
            .borrow<&{DayNFT.CollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowDayNFT(id: id)!
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
                "message": nft!.title,
                "description": nft!.description,
                "thumbnail": nft!.thumbnail,
                "date": nft!.dateStr,
                "editionNumber": "1",
                "editionCount": "1",
                "royaltyAddress": "0x1600b04bf033fb99",
                "royaltyPercentage": "5.0"
            }
        )
    }
    
    // https://flow-view-source.com/mainnet/account/0x329feb3ab062d289/contract/Costacos_NFT
    
    
    pub fun getCostacosNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Costacos_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "Costacos_NFT.CollectionStoragePath",
            public_path: "Costacos_NFT.CollectionPublicPath",
            public_collection_name: "Costacos_NFT.Costacos_NFT",
            external_domain: "https://costacoscollection.com/",
        )
    
        let col = owner.getCapability(Costacos_NFT.CollectionPublicPath)
            .borrow<&{Costacos_NFT.Costacos_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCostacos_NFT(id: id)
        if nft == nil { return nil }
    
        let setMeta = Costacos_NFT.getSetMetadata(setId: nft!.setId)!
        let seriesMeta = Costacos_NFT.getSeriesMetadata(
            seriesId: Costacos_NFT.getSetSeriesId(setId: nft!.setId)!
        )
        let seriesId = Costacos_NFT.getSetSeriesId(setId: nft!.setId)!
        let nftEditions = Costacos_NFT.getSetMaxEditions(setId: nft!.setId)!
        let externalTokenViewUrl = "https://shop.costacoscollection.com/tokens/".concat(nft!.id.toString())
    
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
    
    // https://flow-view-source.com/mainnet/account/0x329feb3ab062d289/contract/Canes_Vault_NFT
    
    
    pub fun getCanesVaultNFT(owner: PublicAccount, id: UInt64): NFTData? {
        let contract = NFTContractData(
            name: "Canes_Vault_NFT",
            address: 0x329feb3ab062d289,
            storage_path: "Canes_Vault_NFT.CollectionStoragePath",
            public_path: "Canes_Vault_NFT.CollectionPublicPath",
            public_collection_name: "Canes_Vault_NFT.Canes_Vault_NFT",
            external_domain: "https://www.canesvault.com/",
        )
    
        let col = owner.getCapability(Canes_Vault_NFT.CollectionPublicPath)
            .borrow<&{Canes_Vault_NFT.Canes_Vault_NFTCollectionPublic}>()
        if col == nil { return nil }
    
        let nft = col!.borrowCanes_Vault_NFT(id: id)
        if nft == nil { return nil }
    
        let setMeta = Canes_Vault_NFT.getSetMetadata(setId: nft!.setId)!
        let seriesMeta = Canes_Vault_NFT.getSeriesMetadata(
            seriesId: Canes_Vault_NFT.getSetSeriesId(setId: nft!.setId)!
        )
        let seriesId = Canes_Vault_NFT.getSetSeriesId(setId: nft!.setId)!
        let nftEditions = Canes_Vault_NFT.getSetMaxEditions(setId: nft!.setId)!
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
    
    // https://flow-view-source.com/mainnet/account/0x329feb3ab062d289/contract/AmericanAirlines_NFT
    

    // Same method signature as getNFTIDs.cdc for backwards-compatability.
    pub fun getNFTIDs(ownerAddress: Address): {String: [UInt64]} {
        let owner = getAccount(ownerAddress)
        let ids: {String: [UInt64]} = {}
    
    
        if let col = owner.getCapability(TFCItems.CollectionPublicPath)
            .borrow<&{TFCItems.TFCItemsCollectionPublic}>(){
                ids["TFCItems"] = col.getIDs()
            }
        if let col = owner.getCapability(GooberXContract.CollectionPublicPath)
            .borrow<&{GooberXContract.GooberCollectionPublic}>() {
                ids["Gooberz"] = col.getIDs()
            }
    
        if let col = owner.getCapability(MintStoreItem.CollectionPublicPath)
            .borrow<&{MintStoreItem.MintStoreItemCollectionPublic}>() {
                let mintStoreIDs = col.getIDs();
                for tokenID in mintStoreIDs {
    
                    let nft = col!.borrowMintStoreItem(id: tokenID)
                    let merchantName = MintStoreItem.getMerchant(merchantID:nft!.data.merchantID)!
                    let merchKey = "MintStoreItem.".concat(merchantName);
                    if ids[merchKey] == nil {
                        ids[merchKey] = [tokenID]
                    } else {
                        ids[merchKey]!.append(tokenID)
                    }
                }
        }
    
        if let col = owner.getCapability(TheFabricantMysteryBox_FF1.CollectionPublicPath)
        .borrow<&{TheFabricantMysteryBox_FF1.FabricantCollectionPublic}>() {
            ids["TheFabricantMysteryBox_FF1"] = col.getIDs()
        }
    
        if let col = owner.getCapability(DieselNFT.CollectionPublicPath)
        .borrow<&{DieselNFT.DieselCollectionPublic}>() {
            ids["DieselNFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(MiamiNFT.CollectionPublicPath)
        .borrow<&{MiamiNFT.MiamiCollectionPublic}>() {
            ids["MiamiNFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(HaikuNFT.HaikuCollectionPublicPath)
        .borrow<&{HaikuNFT.HaikuCollectionPublic}>() {
            ids["Bitku"] = col.getIDs()
        }
    
        if let col = owner.getCapability(AllDay.CollectionPublicPath)
            .borrow<&{AllDay.MomentNFTCollectionPublic}>() {
                ids["AllDay"] = col.getIDs()
        }
    
        if let col = owner.getCapability(PackNFT.CollectionPublicPath)
            .borrow<&{NonFungibleToken.CollectionPublic}>() {
                ids["PackNFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(Andbox_NFT.CollectionPublicPath)
            .borrow<&{Andbox_NFT.Andbox_NFTCollectionPublic}>() {
            ids["Andbox_NFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(ZeedzINO.CollectionPublicPath)
        .borrow<&{ZeedzINO.ZeedzCollectionPublic}>() {
            ids["ZeedzINO"] = col.getIDs()
        }
    
        if let col = owner.getCapability(BarterYardPackNFT.CollectionPublicPath)
        .borrow<&{ BarterYardPackNFT.BarterYardPackNFTCollectionPublic }>() {
            ids["BarterYardPack"] = col.getIDs()
        }
    
        if let col = owner.getCapability(BarterYardClubWerewolf.CollectionPublicPath)
        .borrow<& BarterYardClubWerewolf.Collection{NonFungibleToken.CollectionPublic}>() {
            ids["BarterYardClubWerewolf"] = col.getIDs()
        }
    
        if let col = owner.getCapability(DayNFT.CollectionPublicPath)
            .borrow<&{DayNFT.CollectionPublic}>() {
                ids["DayNFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(Costacos_NFT.CollectionPublicPath)
        .borrow<&{Costacos_NFT.Costacos_NFTCollectionPublic}>() {
            ids["Costacos_NFT"] = col.getIDs()
        }
    
        if let col = owner.getCapability(Canes_Vault_NFT.CollectionPublicPath)
        .borrow<&{Canes_Vault_NFT.Canes_Vault_NFTCollectionPublic}>() {
            ids["Canes_Vault_NFT"] = col.getIDs()
        }
    
        return ids
    }
}