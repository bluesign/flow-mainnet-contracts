// A CoCreatable contract is one where the user combines characteristics
// to create an NFT. The contract should employ a set of dictionaries
// at the top that provide the set from which the user can select the 
// characteristics

import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448

pub contract interface CoCreatable {

    // The contract should have a dictionary of id to characteristic:
    // eg access(contract) var garmentDatas: {UInt64: Characteristic}
    // Dict not defined in the interface to provide flexibility to the contract

    // {concat of combined characteristics: nftId}
    // eg {materialDataId_garmentDataId_primaryColour_secondary_colour: 1}
    access(contract) var dataAllocations: {String: UInt64}

    pub fun getDataAllocations(): {String: UInt64}

    pub resource interface CoCreatableNFT {
        pub fun getCharacteristics(): {String: {Characteristic}}?
    }

    pub struct interface Characteristic {
        pub var id: UInt64

        // Used to inform the BE in case the struct changes
        pub var version: UFix64

        // This is the name that will be used for the Trait, so 
        // will be displayed on external MPs etc. Should be capitalised
        // and spaced eg "Shoe Shape Name"
        pub var traitName: String
        // eg characteristicType = garment
        pub var characteristicType: String
        pub var characteristicDescription: String

        // designerName, desc and address are nil if the Characteristic
        // doesnt have one eg a primaryColor
        pub var designerName: String?
        pub var designerDescription: String?
        pub var designerAddress: Address?
        // Value is the name of the selected characteristic
        // For example, for a garment, this might be "Adventurer Top"
        pub var value: AnyStruct
        pub var rarity: MetadataViews.Rarity?

        access(contract) fun updateCharacteristic(key: String, value: AnyStruct)

        //Helper function that converts the characteristics to traits
        pub fun convertToTraits(): [MetadataViews.Trait]

        // Helper function that can return the media associated with this characteristic.
        // Not all characteristics will have media. For example, this would return the png associated with a garment
        pub fun getMedia(): AnyStruct?
    }

}
 