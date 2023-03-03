import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448

pub contract MindtrixViews {

    pub struct MindtrixDisplay {
        pub let name: String
        pub let description: String
        pub let thumbnail: {MetadataViews.File}
        pub let metadata: {String : String}

        init(
            name: String,
            description: String,
            thumbnail: {MetadataViews.File},
            metadata: {String : String}
        ) {
                self.name = name
                self.description = description
                self.thumbnail = thumbnail
                self.metadata = metadata
            }
        }

    pub struct Serials {

        pub let dic: {String: String}
        pub let arr: [String]
        pub let str: String


        init(data: {String: String}) {
            let arr =  [
                data["essenceRealmSerial"] ?? "0",
                data["essenceTypeSerial"] ?? "0",
                data["showSerial"] ?? "0",
                data["episodeSerial"] ?? "0",
                data["audioEssenceSerial"] ?? "0",
                data["nftEditionSerial"] ?? "0"
            ]
            let str = (
                data["essenceRealmSerial"] ?? "0")
                .concat(data["essenceTypeSerial"] ?? "0")
                .concat(data["showSerial"] ?? "0")
                .concat(data["episodeSerial"] ?? "0")
                .concat(data["audioEssenceSerial"] ?? "0")
                .concat(data["nftEditionSerial"] ?? "0")

            self.dic = data
            self.arr = arr
            self.str = str
        }
    }

    // AudioEssence is optional and only exists when an NFT is a VoiceSerial.audio.
    pub struct AudioEssence  {
        // e.g. startTime = "96.0" = 00:01:36
        pub let startTime: String
        // e.g. endTime = "365.0" = 00:06:05
        pub let endTime: String
        // e.g. fullEpisodeDuration = "1864.0" = 00:31:04
        pub let fullEpisodeDuration: String

        init(startTime: String, endTime: String, fullEpisodeDuration: String) {
            self.startTime = startTime
            self.endTime = endTime
            self.fullEpisodeDuration = fullEpisodeDuration
        }
    }

        // verify the conditions that a user should pass during minting
    pub struct interface IVerifier {
        // access(account) fun verify(_ params: {String: AnyStruct})
        pub fun verify(_ params: {String: AnyStruct})
    }

    pub struct FT {
        pub let path: PublicPath
        pub let price: UFix64

        init(path: PublicPath, price: UFix64) {
            self.path = path
            self.price = price
        }
    }

    pub struct Prices {
        pub var ftDic: {String: FT}

        init(ftDic: {String: FT}){
            self.ftDic = ftDic
        }
    }

    pub struct NFTIdentifier {
        pub let uuid: UInt64
        // UInt64 from getSerialNumber()
        pub let serial: UInt64
        // owner of the token at that time
        pub let holder: Address
        // The time this identifier is created, could be a claimTime, transferTime
        pub let createdTime: UFix64

        init(uuid: UInt64, serial: UInt64, holder: Address) {
            self.uuid = uuid
            self.serial = serial
            self.holder = holder
            self.createdTime = getCurrentBlock().timestamp
        }
    }

    pub struct EssenceIdentifier {
        pub let uuid: UInt64
        // UInt64 from getSerialNumber()
        pub let serials: [String]
        // owner of the token at that time
        pub let holder: Address

        pub let showGuid: String

        pub let episodeGuid: String
        // The time this identifier is created, could be a claimTime, transferTime
        pub let createdTime: UFix64

        init(uuid: UInt64, serials: [String], holder: Address, showGuid: String, episodeGuid: String, createdTime: UFix64) {
            self.uuid = uuid
            self.serials = serials
            self.showGuid = showGuid
            self.episodeGuid = episodeGuid
            self.holder = holder
            self.createdTime = getCurrentBlock().timestamp
        }
    }

    pub resource interface IPack {
        pub let id: UInt64
        pub var isOpen: Bool 
        pub let templateId: UInt64
    }

    pub struct interface IPackTemplate {
        pub let templateId: UInt64 
        pub let strMetadata: {String: String}
        pub let intMetadata: {String: UInt64}
        pub let totalSupply: UInt64
        access(account) fun verifyMintingConditions(recipientAddress: Address, recipientMintQuantityPerTransaction: UInt64): Bool
    }

    pub resource interface IPackAdminCreator {
        pub fun createPackTemplate(strMetadata: {String: String}, intMetadata: {String: UInt64}, totalSupply: UInt64, verifiers: {String: {MindtrixViews.IVerifier}}) : UInt64
        pub fun createPack(packTemplate: {MindtrixViews.IPackTemplate}, adminRef: Capability<&{MindtrixViews.IPackAdminOpener}>, owner: Address, royalties: [MetadataViews.Royalty]) : @NonFungibleToken.NFT
    }

    pub resource interface IPackAdminOpener {
        pub fun openPack(userPack: &{MindtrixViews.IPack}, packID: UInt64, owner: Address, royalties: [MetadataViews.Royalty]): @[NonFungibleToken.NFT] 
    }

    pub struct interface IComponent {
        pub let id: UInt64
        pub let name: String
    }
}
 