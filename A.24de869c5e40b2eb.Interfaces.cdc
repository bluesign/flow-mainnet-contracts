
import NonFungibleToken, MetadataViews from 0x1d7e57aa55817448

pub contract interface Interfaces {

    // ARTIFACTAdminOpener is a interface resource used to
    // to open pack from a user wallet
    // 
    pub resource interface ARTIFACTAdminOpener {
        pub fun openPack(userPack: &{IPack}, packID: UInt64, owner: Address, royalties: [MetadataViews.Royalty], packOption: {IPackOption}?): @[NonFungibleToken.NFT] 
    }
    
    // Resource interface to pack  
    // 
    pub resource interface IPack {
        pub let id: UInt64
        pub var isOpen: Bool 
        pub let templateId: UInt64   
    }

    // Struct interface to pack template 
    // 
    pub struct interface IPackTemplate {
        pub let templateId: UInt64 
        pub let metadata: {String: String}
        pub let totalSupply: UInt64
    }

    pub struct interface IHashMetadata {
        pub let hash: String
        pub let start: UInt64
        pub let end: UInt64
    }

    pub struct interface IPackOption {
        pub let options: [String]
        pub let hash: {IHashMetadata}
    }
}
