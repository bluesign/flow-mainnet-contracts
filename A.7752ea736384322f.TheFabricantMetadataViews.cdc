import FungibleToken from 0xf233dcee88fe0abe

pub contract TheFabricantMetadataViews {
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
}