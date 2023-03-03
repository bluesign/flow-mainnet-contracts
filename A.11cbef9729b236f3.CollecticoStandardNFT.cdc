import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448

/*
    Collectico interface for Basic NFTs (M of N)
    (c) CollecticoLabs.com
 */
pub contract interface CollecticoStandardNFT {

    // Interface that the Items have to conform to
    pub resource interface IItem {
        // The unique ID that each Item has
        pub let id: UInt64
    }

    // Requirement that all conforming smart contracts have
    // to define a resource called Item that conforms to IItem
    pub resource Item: IItem, MetadataViews.Resolver {
        pub let id: UInt64
    }

}
 