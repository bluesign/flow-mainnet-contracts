import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import CoCreatable from 0x7752ea736384322f

pub contract TheFabricantMetadataViews {

// -----------------------------------------------------------------------
// TheFabricantNFT Contract Views
// -----------------------------------------------------------------------
// These are the standard views for TF NFTs that they should implement

// NOTE: TODO: There is a metadata view for original recipient
// currently in discussion: https://github.com/onflow/flow-nft/issues/119
pub struct TFNFTIdentifierV1 {
   pub let uuid: UInt64
   pub let id: UInt64
   pub let name: String
   pub let collection : String
   pub let editions: MetadataViews.Editions
   pub let address: Address
   pub let originalRecipient: Address

    
    init(
        uuid: UInt64,
        id: UInt64,
        name: String,
        collection : String,
        editions: MetadataViews.Editions,
        address: Address,
        originalRecipient: Address
    ) {
    self.uuid = uuid
    self.id = id
    self.name = name
    self.collection = collection
    self.editions = editions
    self.address = address
    self.originalRecipient = originalRecipient
    }
}

pub struct TFNFTSimpleView {
    pub let uuid: UInt64
    pub let id: UInt64
    pub let name: String
    pub let description: String
    pub let collection : String
    pub let collectionId: String
    pub let metadata: {String: AnyStruct}?
    pub let media: MetadataViews.Medias
    pub let images: {String: String}
    pub let videos: {String: String}
    pub let externalURL: MetadataViews.ExternalURL
    pub let rarity: MetadataViews.Rarity?
    pub let traits: MetadataViews.Traits?
    pub let characteristics: {String: {CoCreatable.Characteristic}}?
    pub let coCreatable: Bool
    pub let coCreator: Address
    pub let isRevealed: Bool?
    pub let editions: MetadataViews.Editions
    pub let originalRecipient: Address
    pub let royalties: MetadataViews.Royalties
    pub let royaltiesTFMarketplace: TheFabricantMetadataViews.Royalties
    pub let revealableTraits: {String: Bool}?
    pub let address: Address

     
    init(
        uuid: UInt64,
        id: UInt64,
        name: String,
        description: String,
        collection : String,
        collectionId: String,
        metadata: {String: AnyStruct}?,
        media: MetadataViews.Medias,
        images: {String: String},
        videos: {String: String},
        externalURL: MetadataViews.ExternalURL,
        rarity: MetadataViews.Rarity?,
        traits: MetadataViews.Traits?,
        characteristics: {String: {CoCreatable.Characteristic}}?,
        coCreatable: Bool,
        coCreator: Address,
        isRevealed: Bool?,
        editions: MetadataViews.Editions,
        originalRecipient: Address,
        royalties: MetadataViews.Royalties,
        royaltiesTFMarketplace: TheFabricantMetadataViews.Royalties,
        revealableTraits: {String: Bool}?,
        address: Address,
    ) {
        self.uuid = uuid
        self.id = id
        self.name = name
        self.description = description
        self.collection = collection
        self.collectionId = collectionId
        self.metadata = metadata
        self.media = media
        self.images = images
        self.videos = videos
        self.externalURL = externalURL
        self.rarity = rarity
        self.traits = traits
        self.characteristics = characteristics
        self.coCreatable = coCreatable
        self.coCreator = coCreator
        self.isRevealed = isRevealed
        self.editions = editions
        self.originalRecipient = originalRecipient
        self.royalties = royalties
        self.royaltiesTFMarketplace = royaltiesTFMarketplace
        self.revealableTraits = revealableTraits
        self.address = address
    }
}


// -----------------------------------------------------------------------
// AccessPass Contract Views
// -----------------------------------------------------------------------

    pub struct AccessPassMetadataViewV2 {
        pub let id: UInt64

        pub let season: String

        pub let campaignName: String

        pub let promotionName: String

        // The id of the NFT within the promotion
        pub let edition: UInt64

        pub let variant: String

        pub let description: String

        pub let file: String

        pub let dateReceived: UFix64

        // Points to a promotion
        pub let promotionId: UInt64

        pub let promotionHost: Address

        pub let originalRecipient: Address

        pub let accessUnits: UInt8

        pub let initialAccessUnits: UInt8

        pub let metadataId: UInt64?

        pub let metadata: {String: String}?

        pub let extraMetadata: {String: String}?

        pub let royalties: [MetadataViews.Royalty]

        pub let royaltiesTFMarketplace: [TheFabricantMetadataViews.Royalty]

        pub let owner: Address

        init(
            id: UInt64,
            season: String,
            campaignName: String,
            promotionName: String,
            edition: UInt64,
            variant: String, 
            description: String,
            file: String,
            dateReceived: UFix64, 
            promotionId: UInt64,
            promotionHost: Address,
            originalRecipient: Address, 
            accessUnits: UInt8,
            initialAccessUnits: UInt8,
            metadataId: UInt64?,
            metadata: {String: String}?,
            extraMetadata: {String: String}?,
            royalties: [MetadataViews.Royalty],
            royaltiesTFMarketplace: [TheFabricantMetadataViews.Royalty],
            owner: Address,
        ) {
            self.id = id
            self.season = season
            self.campaignName = campaignName
            self.promotionName = promotionName
            self.edition = edition
            self.variant = variant
            self.description = description
            self.file = file
            self.dateReceived = dateReceived
            self.promotionId = promotionId
            self.promotionHost = promotionHost
            self.metadataId = metadataId
            self.metadata = metadata
            self.originalRecipient = originalRecipient
            self.accessUnits = accessUnits
            self.initialAccessUnits = initialAccessUnits
            self.extraMetadata = extraMetadata
            self.royalties = royalties
            self.royaltiesTFMarketplace = royaltiesTFMarketplace
            self.owner = owner
        }
    }

    pub struct IdentifierV2 {
        pub let id: UInt64
        pub let season: String
        pub let campaignName: String
        pub let promotionName: String
        pub let promotionId: UInt64
        pub let edition: UInt64
        pub let variant: String
        pub let address: Address
        pub let dateReceived: UFix64
        pub let originalRecipient: Address
        pub let accessUnits: UInt8
        pub let initialAccessUnits: UInt8
        pub let metadataId: UInt64?

        init(
            season: String,
            campaignName: String,
            promotionName: String,
            promotionId: UInt64,
            edition: UInt64,
            variant: String,
            id: UInt64, 
            address: Address,
            dateReceived: UFix64,
            originalRecipient: Address,
            accessUnits: UInt8,
            initialAccessUnits: UInt8,
            metadataId: UInt64?
            
            ) {
            self.season = season
            self.campaignName = campaignName
            self.promotionName = promotionName
            self.promotionId = promotionId
            self.edition = edition
            self.variant = variant
            self.id = id
            self.address = address
            self.dateReceived = dateReceived
            self.originalRecipient = originalRecipient
            self.accessUnits = accessUnits
            self.initialAccessUnits = initialAccessUnits
            self.metadataId = metadataId
        }
    }

    pub struct PromotionMetadataViewV2 {

        pub var active: Bool
        pub let id: UInt64
        pub let season: String
        pub let campaignName: String 
        pub let promotionName: String?
        pub var isAccessListUsed: Bool 
        pub var onlyUseAccessList: Bool
        pub var isOpenAccess: Bool
        pub let typeRestrictions: [Type]?
        pub var promotionAccessIds: [UInt64]?
        pub var nftsUsedForClaim: {UInt64: TheFabricantMetadataViews.IdentifierV2}
        pub var addressesClaimed: {Address: [TheFabricantMetadataViews.IdentifierV2]}
        pub let dateCreated: UFix64
        pub let description: String
        pub let maxMintsPerAddress: Int?
        pub let host: Address
        pub let image: String?      
        pub let accessPassMetadatas: {UInt64: {String: String}}?
        pub let publicMinterPaths: [String]
        pub let totalSupply: UInt64
        pub let url: String?
        pub let spentAccessUnits: {UInt64: [TheFabricantMetadataViews.SpentAccessUnitView]}

        // Options
        pub let capacity: UInt64?
        pub let startTime: UFix64?
        pub let endTime: UFix64?

        pub let isOpen: Bool

        init (
            active: Bool,
            id: UInt64,
            season: String,
            campaignName: String,
            promotionName: String?,
            isAccessListUsed: Bool, 
            onlyUseAccessList: Bool,
            isOpenAccess: Bool,
            typeRestrictions: [Type]?,
            promotionAccessIds: [UInt64]?,
            nftsUsedForClaim: {UInt64: TheFabricantMetadataViews.IdentifierV2},
            addressesClaimed: {Address: [TheFabricantMetadataViews.IdentifierV2]},
            dateCreated: UFix64,
            description: String,
            maxMintsPerAddress: Int?,
            host: Address,
            image: String?,
            accessPassMetadatas: {UInt64: {String: String}}?,
            publicMinterPaths: [String],
            totalSupply: UInt64,
            url: String?,
            spentAccessUnits: {UInt64: [TheFabricantMetadataViews.SpentAccessUnitView]},
            capacity: UInt64?,
            startTime: UFix64?,
            endTime: UFix64?,
            isOpen: Bool
        ) {
            self.active = active
            self.id = id
            self.season = season
            self.campaignName = campaignName
            self.promotionName = promotionName
            self.isAccessListUsed = isAccessListUsed
            self.onlyUseAccessList = onlyUseAccessList
            self.isOpenAccess = isOpenAccess
            self.typeRestrictions = typeRestrictions
            self.promotionAccessIds = promotionAccessIds
            self.nftsUsedForClaim = nftsUsedForClaim
            self.addressesClaimed = addressesClaimed
            self.dateCreated = dateCreated
            self.description = description
            self.maxMintsPerAddress = maxMintsPerAddress
            self.host = host
            self.image = image
            self.accessPassMetadatas = accessPassMetadatas
            self.publicMinterPaths = publicMinterPaths
            self.totalSupply = totalSupply
            self.url = url
            self.spentAccessUnits = spentAccessUnits
            self.capacity = capacity
            self.startTime = startTime
            self.endTime = endTime
            self.isOpen = isOpen
        }
    }

    pub struct PromotionAccessPassHoldersV2 {
        pub let id: UInt64
        pub let host: Address
        pub let currentHolders: {UInt64: TheFabricantMetadataViews.IdentifierV2}
    
        init(
            id: UInt64, 
            host: Address, 
            currentHolders: {UInt64: TheFabricantMetadataViews.IdentifierV2} 
            ) {
                self.id = id 
                self.host = host 
                self.currentHolders = currentHolders
            }
    }

    pub struct PromotionAccessPassClaimsV2 {
        pub let id: UInt64
        pub let host: Address
        pub let claims: {Address: [IdentifierV2]}
        init(
            id: UInt64, 
            host: Address, 
            claimed: {Address: [TheFabricantMetadataViews.IdentifierV2]}
            ) {
            self.id = id 
            self.host = host 
            self.claims = claimed
        }
    }

    pub struct PromotionAccessList {
        pub let id: UInt64
        pub let host: Address
        pub let accessList: [Address]?
        pub var isAccessListUsed: Bool 
        pub var onlyUseAccessList: Bool
        init(
            id: UInt64, 
            host: Address, 
            accessList: [Address]?,
            isAccessListUsed: Bool, 
            onlyUseAccessList: Bool
            ) {
            self.id = id 
            self.host = host 
            self.accessList = accessList
            self.isAccessListUsed = isAccessListUsed
            self.onlyUseAccessList = onlyUseAccessList
        }
    }

    pub struct SpentAccessUnitView {
        pub let spender: Address 
        pub let season: String
        pub let campaignName: String
        pub let promotionName: String
        pub let promotionId: UInt64
        pub let variant: String?
        pub let accessPassId: UInt64
        pub let accessPassSerial: UInt64
        pub let accessTokenId: UInt64

        init(
            spender: Address, 
            season: String,
            campaignName: String,
            promotionName: String,
            promotionId: UInt64,
            variant: String?,
            accessPassId: UInt64,
            accessPassSerial: UInt64,
            accessTokenId: UInt64
        ) {
            self.spender = spender
            self.season = season
            self.promotionId = promotionId
            self.promotionName = promotionName
            self.campaignName = campaignName
            self.variant = variant
            self.accessPassId = accessPassId
            self.accessPassSerial = accessPassSerial
            self.accessTokenId = accessTokenId
        }
    }

    pub struct PublicMinterView {
        pub let id: UInt64
        pub let season: String
        pub let campaignName: String
        pub let promotionName: String
        pub let promotionId: UInt64
        pub let variant: String
        pub let nftFile: String
        pub let nftMetadataId: UInt64?
        pub let nftNumberOfAccessUnits: UInt8
        pub var numberOfMints: UInt64

        init(
            id: UInt64, 
            season: String,
            campaignName: String,
            promotionName: String,
            promotionId: UInt64, 
            nftFile: String, 
            nftMetadataId: UInt64?, 
            nftNumberOfAccessUnits: UInt8,  
            variant: String,  
            numberOfMints: UInt64, 
        ) {
            self.id = id
            self.season = season
            self.campaignName = campaignName
            self.promotionName = promotionName
            self.promotionId = promotionId
            self.nftFile = nftFile
            self.nftMetadataId = nftMetadataId
            self.nftNumberOfAccessUnits = nftNumberOfAccessUnits
            self.variant = variant
            self.numberOfMints = numberOfMints
        }
    }

    pub struct Royalty{

		pub let receiver:Capability<&{FungibleToken.Receiver}> 
        pub let initialCut: UFix64
		pub let cut: UFix64
        pub let description: String

		/// @param wallet : The wallet to send royalty too
		init(
            receiver:Capability<&{FungibleToken.Receiver}>, 
            initialCut: UFix64, 
            cut: UFix64, 
            description: String
            ){
			self.receiver = receiver
            self.initialCut = initialCut
			self.cut = cut
            self.description = description
		}
	}

    pub struct Royalties {

        /// Array that tracks the individual royalties
        access(self) let cutInfos: [Royalty]

        pub init(_ cutInfos: [Royalty]) {
            // Validate that sum of all cut multipliers should not be greater than 1.0
            var totalCut = 0.0
            for royalty in cutInfos {
                totalCut = totalCut + royalty.cut
            }
            assert(totalCut <= 1.0, message: "Sum of cutInfos multipliers should not be greater than 1.0")
            // Assign the cutInfos
            self.cutInfos = cutInfos
        }

        /// Return the cutInfos list
        pub fun getRoyalties(): [Royalty] {
            return self.cutInfos
        }
    }

     // -----------------------------------------------------------------------
    // OLD IMPLEMENTATIONS
    // -----------------------------------------------------------------------

    pub struct AccessPassMetadataView {
        pub let id: UInt64

        // The id of the NFT within the promotion
        pub let serial: UInt64

        pub let campaignName: String

        pub let variant: String

        pub let description: String

        pub let file: String

        pub let dateReceived: UFix64

        // Points to a promotion
        pub let promotionId: UInt64

        pub let promotionHost: Address

        pub let metadataId: UInt64?

        pub let metadata: {String: String}?

        pub let originalRecipient: Address

        pub let accessUnits: UInt8

        pub let initialAccessUnits: UInt8

        pub let extraMetadata: {String: String}?

        pub let owner: Address

        init(
            id: UInt64,
            serial: UInt64,
            campaignName: String,
            variant: String, 
            description: String,
            file: String,
            dateReceived: UFix64, 
            promotionId: UInt64,
            promotionHost: Address,
            metadataId: UInt64?,
            metadata: {String: String}?,
            originalRecipient: Address, 
            accessUnits: UInt8,
            initialAccessUnits: UInt8,
            extraMetadata: {String: String}?,
            owner: Address,
        ) {
            self.id = id
            self.serial = serial
            self.campaignName = campaignName
            self.variant = variant
            self.description = description
            self.file = file
            self.dateReceived = dateReceived
            self.promotionId = promotionId
            self.promotionHost = promotionHost
            self.metadataId = metadataId
            self.metadata = metadata
            self.originalRecipient = originalRecipient
            self.accessUnits = accessUnits
            self.initialAccessUnits = initialAccessUnits
            self.extraMetadata = extraMetadata
            self.owner = owner
        }
    }

    pub struct Identifier {
        pub let season: String
        pub let campaignName: String
        pub let promotionName: String
        pub let promotionId: UInt64
        pub let variant: String
        pub let id: UInt64
        pub let serial: UInt64
        pub let address: Address
        pub let dateReceived: UFix64
        pub let originalRecipient: Address
        pub let accessUnits: UInt8
        pub let initialAccessUnits: UInt8
        pub let metadataId: UInt64?

        init(
            season: String,
            campaignName: String,
            promotionName: String,
            promotionId: UInt64,
            variant: String,
            id: UInt64, 
            serial: UInt64, 
            address: Address,
            dateReceived: UFix64,
            originalRecipient: Address,
            accessUnits: UInt8,
            initialAccessUnits: UInt8,
            metadataId: UInt64?
            
            ) {
            self.season = season
            self.campaignName = campaignName
            self.promotionName = promotionName
            self.promotionId = promotionId
            self.variant = variant
            self.id = id
            self.serial = serial
            self.address = address
            self.dateReceived = dateReceived
            self.originalRecipient = originalRecipient
            self.accessUnits = accessUnits
            self.initialAccessUnits = initialAccessUnits
            self.metadataId = metadataId
        }
    }

    pub struct PromotionMetadataView {

        pub var active: Bool
        pub let id: UInt64
        pub let season: String
        pub let campaignName: String 
        pub let promotionName: String?
        pub var isAccessListUsed: Bool 
        pub var onlyUseAccessList: Bool
        pub var isOpenAccess: Bool
        pub let typeRestrictions: [Type]?
        pub var promotionAccessIds: [UInt64]?
        pub var nftsUsedForClaim: {UInt64: TheFabricantMetadataViews.Identifier}
        pub var addressesClaimed: {Address: [TheFabricantMetadataViews.Identifier]}
        pub let dateCreated: UFix64
        pub let description: String
        pub let maxMintsPerAddress: Int?
        pub let host: Address
        pub let image: String?      
        pub let accessPassMetadatas: {UInt64: {String: String}}?
        pub let publicMinterPaths: [String]
        pub let totalSupply: UInt64
        pub let url: String?
        pub let spentAccessUnits: {UInt64: [TheFabricantMetadataViews.SpentAccessUnitView]}

        // Options
        pub let capacity: UInt64?
        pub let startTime: UFix64?
        pub let endTime: UFix64?

        pub let isOpen: Bool

        init (
            active: Bool,
            id: UInt64,
            season: String,
            campaignName: String,
            promotionName: String?,
            isAccessListUsed: Bool, 
            onlyUseAccessList: Bool,
            isOpenAccess: Bool,
            typeRestrictions: [Type]?,
            promotionAccessIds: [UInt64]?,
            nftsUsedForClaim: {UInt64: TheFabricantMetadataViews.Identifier},
            addressesClaimed: {Address: [TheFabricantMetadataViews.Identifier]},
            dateCreated: UFix64,
            description: String,
            maxMintsPerAddress: Int?,
            host: Address,
            image: String?,
            accessPassMetadatas: {UInt64: {String: String}}?,
            publicMinterPaths: [String],
            totalSupply: UInt64,
            url: String?,
            spentAccessUnits: {UInt64: [TheFabricantMetadataViews.SpentAccessUnitView]},
            capacity: UInt64?,
            startTime: UFix64?,
            endTime: UFix64?,
            isOpen: Bool
        ) {
            self.active = active
            self.id = id
            self.season = season
            self.campaignName = campaignName
            self.promotionName = promotionName
            self.isAccessListUsed = isAccessListUsed
            self.onlyUseAccessList = onlyUseAccessList
            self.isOpenAccess = isOpenAccess
            self.typeRestrictions = typeRestrictions
            self.promotionAccessIds = promotionAccessIds
            self.nftsUsedForClaim = nftsUsedForClaim
            self.addressesClaimed = addressesClaimed
            self.dateCreated = dateCreated
            self.description = description
            self.maxMintsPerAddress = maxMintsPerAddress
            self.host = host
            self.image = image
            self.accessPassMetadatas = accessPassMetadatas
            self.publicMinterPaths = publicMinterPaths
            self.totalSupply = totalSupply
            self.url = url
            self.spentAccessUnits = spentAccessUnits
            self.capacity = capacity
            self.startTime = startTime
            self.endTime = endTime
            self.isOpen = isOpen
        }
    }

    pub struct PromotionAccessPassHolders {
        pub let id: UInt64
        pub let host: Address
        pub let currentHolders: {UInt64: TheFabricantMetadataViews.Identifier}
    
        init(
            id: UInt64, 
            host: Address, 
            currentHolders: {UInt64: TheFabricantMetadataViews.Identifier} 
            ) {
                self.id = id 
                self.host = host 
                self.currentHolders = currentHolders
            }
    }

    pub struct PromotionAccessPassClaims {
        pub let id: UInt64
        pub let host: Address
        pub let claims: {Address: [Identifier]}
        init(
            id: UInt64, 
            host: Address, 
            claimed: {Address: [TheFabricantMetadataViews.Identifier]}
            ) {
            self.id = id 
            self.host = host 
            self.claims = claimed
        }
    }
}
 