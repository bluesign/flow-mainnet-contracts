// SPDX-License-Identifier: MIT

// This contracts contains Metadata structs for Everbloom
import MetadataViews from 0x1d7e57aa55817448

pub contract EverbloomMetadata {
	pub struct Perk {
	    pub let perkID: UInt32
    	pub let type: String
    	pub let title: String
    	pub let description: String
    	pub let url: String?
    	pub let isValid: Bool?

    	init(perkID: UInt32, type: String, title: String, description: String, url: String?, isValid: Bool?){
    	    self.perkID = perkID
    		self.type = type
    		self.title = title
    		self.description = description
    		self.url = url
    		self.isValid = isValid
    	}
    }

    pub struct PerkData {
    	pub let type: String
    	pub let title: String
    	pub let description: String
    	pub let url: String?

    	init(type: String, title: String, description: String, url: String?){
    		self.type = type
    		self.title = title
    		self.description = description
    		self.url = url
    	}
    }

    pub struct PerksView {
        access(self) let perks: [Perk]

        pub init(_ perks: [Perk]) {
            self.perks = perks
        }

        pub fun getPerks(): [Perk] {
            return self.perks
        }
    }

    pub struct EverbloomMetadataView {
    	pub let name: String?
    	pub let description: String?
    	pub let image: MetadataViews.HTTPFile?
    	pub let thumbnail: MetadataViews.HTTPFile?
    	pub let video: MetadataViews.HTTPFile?
    	pub let signature: MetadataViews.HTTPFile?
    	pub let previewUrl: String?
    	pub let creatorName: String?
    	pub let creatorUrl: String?
    	pub let creatorDescription: String?
    	pub let creatorAddress: String?
    	pub let externalPostId: String
    	pub let externalPrintId: String
    	pub let rarity: String?
    	pub let serialNumber: UInt32
    	pub let totalPrintMinted: UInt32?

    	init(
    	    name: String?,
    	    description: String?,
    	    image: MetadataViews.HTTPFile?,
            thumbnail: MetadataViews.HTTPFile?,
            video: MetadataViews.HTTPFile?,
            signature: MetadataViews.HTTPFile?,
            previewUrl: String?,
            creatorName: String?,
            creatorUrl: String?,
            creatorDescription: String?,
            creatorAddress: String?,
            externalPostId: String,
            externalPrintId: String,
            rarity: String?,
            serialNumber: UInt32,
            totalPrintMinted: UInt32?
    	) {
    		self.name = name
    		self.description = description
    		self.image = image
    		self.thumbnail = thumbnail
    		self.video = video
    		self.signature = signature
    		self.previewUrl = previewUrl
    		self.creatorName = creatorName
    		self.creatorUrl = creatorUrl
    		self.creatorDescription = creatorDescription
    		self.creatorAddress = creatorAddress
    		self.externalPostId = externalPostId
    		self.externalPrintId = externalPrintId
    		self.rarity = rarity
    		self.serialNumber = serialNumber
    		self.totalPrintMinted = totalPrintMinted
    	}
    }
}
