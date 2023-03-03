/*
    Description: Central Smart Contract for  Magnetiq

    This smart contract contains the core functionality for 
     Magnetiq, created by Hcode

    The contract manages the data associated with all the magnets and brands
    that are used as templates for the Tokens NFTs

    When a new Magnet wants to be added to the records, an Admin creates
    a new Magnet struct that is stored in the smart contract.

    Then an Admin can create new Brands. Brands consist of a public struct that 
    contains public information about a brand, and a private resource used
    to mint new tokens based off of magnets that have been linked to the Brand.

    The admin resource has the power to do all of the important actions
    in the smart contract. When admins want to call functions in a brand,
    they call their borrowBrand function to get a reference 
    to a brand in the contract. Then, they can call functions on the brand using that reference.
    
    When tokens are minted, they are initialized with a TokensData struct and
    are returned by the minter.

    The contract also defines a Collection resource. This is an object that 
    every Magnetiq NFT owner will store in their account
    to manage their NFT collection.

    The main Magnetiq account will also have its own Tokens collections
    it can use to hold its own tokens that have not yet been sent to a user.

    Note: All state changing functions will panic if an invalid argument is
    provided or one of its pre-conditions or post conditions aren't met.
    Functions that don't modify state will simply return 0 or nil 
    and those cases need to be handled by the caller.
*/

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MagnetiqLocking from 0x5257f1455ed366fe

pub contract Magnetiq: NonFungibleToken {
    // -----------------------------------------------------------------------
    // Magnetiq deployment variables
    // -----------------------------------------------------------------------

    // The network the contract is deployed on
    pub fun Network() : String { return self.currentNetwork}

    // The address to which royalties should be deposited
    pub fun RoyaltyAddress() : Address { return self.royalityReceiver }
    

    // -----------------------------------------------------------------------
    // Magnetiq contract Events
    // -----------------------------------------------------------------------

    // Emitted when the Magnetiq contract is created
    pub event ContractInitialized()

    // Emitted when a new Magnet struct is created
    pub event MagnetCreated(id: String, metadata: {String:String})
    

    // Events for Brand-Related actions
    //
    // Emitted when a new Brand is created
    pub event BrandCreated(brandID: String)
    // Emitted when a new Magnet is added to a Brand
    pub event MagnetAddedToBrand(brandID: String, magnetID: String)
    // Emitted when a Magnet is retired from a Brand and cannot be used to mint
    pub event MagnetRetiredFromBrand(brandID: String, magnetID: String, numTokens: UInt32)
    // Emitted when a Brand is locked, meaning Magnets cannot be added
    pub event BrandLocked(brandID: String)
    // Emitted when a Tokens is minted from a Brand
    pub event TokensMinted(tokenID: UInt64, tokenType:String , magnetiqID: String, brandID: String, serialNumber: UInt32)

    // Events for Collection-related actions
    //
    // Emitted when a token is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)
    // Emitted when a token is deposited into a Collection
    pub event Deposit(id: UInt64, to: Address?)

    // Emitted when a Tokens is destroyed
    pub event TokensDestroyed(id: UInt64)

    // Emitted when a Memento is created
    pub event MementoCreated(mementoID:String, magnetID:String)

    // Emitted when a token mark claimed
    pub event TokenClaimed(tokenID:UInt64)

    // Emitted when magnet metadata updated
    pub event MagnetMetadataUpdated(id:String, metadata:{String:String})

    // Emitted when memento metadata updated
    pub event MementoMetadataUpdated(id:String, metadata:{String:String})

    // -----------------------------------------------------------------------
    // Magnetiq contract-level fields.
    // These contain actual values that are stored in the smart contract.
    // -----------------------------------------------------------------------

    // variable for network
    pub var currentNetwork: String 

    // variable for roya;ity reciever address
    pub var royalityReceiver: Address

    // variable for royality percentage
    pub var royalityPercentage: UFix64

    // Series that this Brand belongs to.
    // Series is a concept that indicates a group of Brands through time.
    // Many Brands can exist at a time, but only one series.
    pub var currentSeries: UInt32

    // Variable size dictionary of Magnet structs
    access(self) var magnetData: {String: Magnet}

    // Variable size dictionary of Memento structs
    access(self) var mementoData: {String:Memento}
    access(self) var magnetiqTokenExtraInfo: {UInt64:{String:AnyStruct}}

    // Variable size dictionary of BrandData structs
    access(self) var brandData: {String: BrandData}

    // Variable size dictionary of Brand resources
    access(self) var brands: @{String: Brand}

    // Dictionary of sellers allowed to sell non-sellable NFT
    access(self) var allowedSellersForNonSellableNFT:[Address?]


    // The total number of Magnetiq Tokens NFTs that have been created
    // Because NFTs can be destroyed, it doesn't necessarily mean that this
    // reflects the total number of NFTs in existence, just the number that
    // have been minted to date. Also used as global token IDs for minting.
    pub var totalSupply: UInt64
    

    // -----------------------------------------------------------------------
    // Magnetiq contract-level Composite Type definitions
    // -----------------------------------------------------------------------
    // These are just *definitions* for Types that this contract
    // and other accounts can use. These definitions do not contain
    // actual stored values, but an instance (or object) of one of these Types
    // can be created by this contract that contains stored values.
    // -----------------------------------------------------------------------

    // Magnet is a Struct that holds metadata associated 
    // with a specific  magnet
    //
    // Tokens NFTs will all reference a single magnet as the owner of
    // its metadata. The magnets are publicly accessible, so anyone can
    // read the metadata associated with a specific magnet ID
    //
    pub struct Magnet {

        // The unique ID for the Magnet
        pub let magnetID: String

        // Array of memento ids that are a part of this Magnet.
        // When a memento is added to the mangnet, its ID gets appended here.
        access(contract) var mementos: [String]

        // Stores all the metadata about the magnet as a string mapping
        // This is not the long term way NFT metadata will be stored. It's a temporary
        // construct while we figure out a better way to do metadata.
        //
        pub var metadata: {String: String}

        // Mapping of memento IDs that indicates the number of tokens 
        // that have been minted for specific Memento in this Magnet.
        access(contract) var numberMintedPerMemento: {String: UInt32}

        init(metadata: {String: String}, magnetID:String) {
            pre {
                metadata.length != 0: "New Magnet metadata cannot be empty"
            }
            self.magnetID = magnetID
            self.metadata = metadata
            self.numberMintedPerMemento = {}
            self.mementos = []
        }

        pub fun updateMementoList(mementoID: String)  {
             self.mementos.append(mementoID)
             Magnetiq.magnetData[self.magnetID] = self
        }

        pub fun updateMementoCount(mementoID: String, count: UInt32)  {
            self.numberMintedPerMemento[mementoID] = count
            Magnetiq.magnetData[self.magnetID] = self
        }
        pub fun updateMetadata(new_metadata:{String:String}){
            self.metadata = new_metadata
        }
    }

    pub struct Memento{
        pub let mementoID:String
        pub let magnetID: String
        pub var metadata: {String:String}
        

        init(mementoID:String, magnetID:String,metadata:{String:String}){
            self.mementoID = mementoID
            self.magnetID = magnetID
            self.metadata = metadata
        }
        
        pub fun updateMementoMetadata(new_metadata:{String:String}){
            self.metadata = new_metadata
        }

        
    }

    // A Brand is a grouping of Magnets that have occured in the real world
    // that make up a related group of collectibles, like brands of baseball
    // or Magic cards. A Magnet can exist in multiple different brands.
    // 
    // BrandData is a struct that is stored in a field of the contract.
    // Anyone can query the constant informationbrands
    // about a brand by calling various getters located 
    // at the end of the contract. Only the admin has the ability 
    // to modify any data in the private Brand resource.
    //
    pub struct BrandData {

        // Unique ID for the Brand
        pub let brandID: String

        // Name of the Brand
        pub let name: String


        init(name: String, brandID:String) {
            pre {
                name.length > 0: "New Brand name cannot be empty"
            }
            self.brandID = brandID
            self.name = name
        }
    }

    // Brand is a resource type that contains the functions to add and remove
    // Magnets from a brand and mint Tokens.
    //
    // It is stored in a private field in the contract so that
    // the admin resource can call its methods.
    //
    // The admin can add Magnets to a Brand so that the brand can mint Tokens
    // that reference that magnetdata.
    // The Tokens that are minted by a Brand will be listed as belonging to
    // the Brand that minted it, as well as the Magnet it references.
    // 
    // Admin can also retire Magnets from the Brand, meaning that the retired
    // Magnet can no longer have Tokens minted from it.
    //
    // If the admin locks the Brand, no more Magnets can be added to it, but 
    // Tokens can still be minted.
    //
    // If retireAll() and lock() are called back-to-back, 
    // the Brand is closed off forever and nothing more can be done with it.
    pub resource Brand {

        // Unique ID for the brand
        pub let brandID: String

        // Array of magnets that are a part of this brand.
        // When a magnet is added to the brand, its ID gets appended here.
        // The ID does not get removed from this array when a Magnet is retired.
        access(contract) var magnets: [String]

        // Map of Magnet IDs that Indicates if a Magnet in this Brand can be minted.
        // When a Magnet is added to a Brand, it is mapped to false (not retired).
        // When a Magnet is retired, this is brand to true and cannot be changed.
        access(contract) var retired: {String: Bool}

        // Indicates if the Brand is currently locked.
        // When a Brand is created, it is unlocked 
        // and Magnets are allowed to be added to it.
        // When a brand is locked, Magnets cannot be added.
        // A Brand can never be changed from locked to unlocked,
        // the decision to lock a Brand it is final.
        // If a Brand is locked, Magnets cannot be added, but
        // Tokens can still be minted from Magnets
        // that exist in the Brand.
        pub var locked: Bool

        // Mapping of Magnet IDs that indicates the number of Tokens 
        // that have been minted for specific Magnets in this Brand.
        // When a Tokens is minted, this value is stored in the Tokens to
        // show its place in the Brand, eg. 13 of 60.
        access(contract) var numberMintedPerMagnet: {String: UInt32}

        init(name: String, brandID:String) {
            self.brandID = brandID
            self.magnets = []
            self.retired = {}
            self.locked = false
            self.numberMintedPerMagnet = {}

            // Create a new BrandData for this Brand and store it in contract storage
            Magnetiq.brandData[self.brandID] = BrandData(name: name, brandID:brandID)
        }

        // addMagnet adds a magnet to the brand
        //
        // Parameters: magnetID: The ID of the Magnet that is being added
        //
        // Pre-Conditions:
        // The Magnet needs to be an existing magnet
        // The Brand needs to be not locked
        // The Magnet can't have already been added to the Brand
        //
        pub fun addMagnet(magnetID: String) {
            pre {
                Magnetiq.magnetData[magnetID] != nil: "Cannot add the Magnet to Brand: Magnet doesn't exist."
                !self.locked: "Cannot add the magnet to the Brand after the brand has been locked."
                self.numberMintedPerMagnet[magnetID] == nil: "The magnet has already beed added to the brand."
            }

            // Add the Magnet to the array of Magnets
            self.magnets.append(magnetID)

            // Open the Magnet up for minting
            self.retired[magnetID] = false

            // Initialize the Tokens count to zero
            self.numberMintedPerMagnet[magnetID] = 0

            emit MagnetAddedToBrand(brandID: self.brandID, magnetID: magnetID)
        }

        // addMagnets adds multiple Magnets to the Brand
        //
        // Parameters: magnetIDs: The IDs of the Magnets that are being added
        //                      as an array
        //
        pub fun addMagnets(magnetIDs: [String]) {
            for magnet in magnetIDs {
                self.addMagnet(magnetID: magnet)
            }
        }

        // retireMagnet retires a Magnet from the Brand so that it can't mint new Tokens
        //
        // Parameters: magnetID: The ID of the Magnet that is being retired
        //
        // Pre-Conditions:
        // The Magnet is part of the Brand and not retired (available for minting).
        // 
        pub fun retireMagnet(magnetID: String) {
            pre {
                self.retired[magnetID] != nil: "Cannot retire the Magnet: Magnet doesn't exist in this brand!"
            }

            if !self.retired[magnetID]! {
                self.retired[magnetID] = true

                emit MagnetRetiredFromBrand(brandID: self.brandID, magnetID: magnetID, numTokens: self.numberMintedPerMagnet[magnetID]!)
            }
        }

        // retireAll retires all the magnets in the Brand
        // Afterwards, none of the retired Magnets will be able to mint new Tokens
        //
        pub fun retireAll() {
            for magnet in self.magnets {
                self.retireMagnet(magnetID: magnet)
            }
        }

        // lock() locks the Brand so that no more Magnets can be added to it
        //
        // Pre-Conditions:
        // The Brand should not be locked
        pub fun lock() {
            if !self.locked {
                self.locked = true
                emit BrandLocked(brandID: self.brandID)
            }
        }

        // mintToken mints a new Tokens and returns the newly minted Tokens
        // 
        // Parameters: magnetID: The ID of the Magnet that the Tokens references
        //
        // Pre-Conditions:
        // The Magnet must exist in the Brand and be allowed to mint new Tokens
        //
        // Returns: The NFT that was minted
        // 
        pub fun mintToken(magnetiqID: String, tokenType:String): @NFT {
            
            var numInMagnetMemento: UInt32? = 0
            
            
            if tokenType == "magnet" {
                let magnet = Magnetiq.magnetData[magnetiqID] 
                if magnet == nil { 
                    panic("Cannot mint the token: This magnet doesn't exist.")
                }
                if self.retired[magnetiqID]! {
                    panic("Cannot mint the token from this magnet: This magnet has been retired.")
                }

                numInMagnetMemento = self.numberMintedPerMagnet[magnetiqID]!
                self.numberMintedPerMagnet[magnetiqID] = numInMagnetMemento! + UInt32(1)
            }
            else{
               let memento = Magnetiq.mementoData[magnetiqID] 
                    if memento == nil { 
                    panic("Cannot mint the token: This memento doesn't exist.")
                }
                var magnet_id = memento?.magnetID!
                let magnet = Magnetiq.magnetData[magnet_id]
                if magnet != nil {
                    numInMagnetMemento = magnet?.numberMintedPerMemento![magnetiqID] ?? 0
                    magnet?.updateMementoCount(mementoID:magnetiqID, count:numInMagnetMemento! + UInt32(1)) 
                }
            }


            // Gets the number of Tokens that have been minted for this Magnet
            // to use as this Tokens's serial number

            // Mint the new token
            let newTokens: @NFT <- create NFT(serialNumber: numInMagnetMemento! + UInt32(1),
                                              magnetiqID: magnetiqID,
                                              brandID: self.brandID,
                                              tokenType:tokenType
                                              )

            
            if tokenType == "memento" {
                 Magnetiq.magnetiqTokenExtraInfo[newTokens.id] = {}
            }
            

            return <-newTokens
        }

        // batchMintTokens mints an arbitrary quantity of Tokens 
        // and returns them as a Collection
        //
        // Parameters: magnetID: the ID of the Magnet that the Tokens are minted for
        //             quantity: The quantity of Tokens to be minted
        //
        // Returns: Collection object that contains all the Tokens that were minted
        //
        pub fun batchMintTokens(magnetiqID: String, quantity: UInt64,tokenType:String): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintToken(magnetiqID: magnetiqID,tokenType:tokenType))
                i = i + UInt64(1)
            }

            return <-newCollection
        }

        pub fun getMagnets(): [String] {
            return self.magnets
        }

        pub fun getRetired(): {String: Bool} {
            return self.retired
        }

        pub fun getNumMintedPerMagnet(): {String: UInt32} {
            return self.numberMintedPerMagnet
        }
    }

    // Struct that contains all of the important data about a brand
    // Can be easily queried by instantiating the `QueryBrandData` object
    // with the desired brand ID
    // let brandData = Magnetiq.QueryBrandData(brandID: 12)
    //
    pub struct QueryBrandData {
        pub let brandID: String
        pub let name: String
        access(self) var magnets: [String]
        access(self) var retired: {String: Bool}
        pub var locked: Bool
        access(self) var numberMintedPerMagnet: {String: UInt32}

        init(brandID: String) {
            pre {
                Magnetiq.brands[brandID] != nil: "The brand with the provided ID does not exist"
            }

            let brand = (&Magnetiq.brands[brandID] as &Brand?)!
            let brandData = Magnetiq.brandData[brandID]!

            self.brandID = brandID
            self.name = brandData.name
            self.magnets = brand.magnets
            self.retired = brand.retired
            self.locked = brand.locked
            self.numberMintedPerMagnet = brand.numberMintedPerMagnet
        }

        pub fun getMagnets(): [String] {
            return self.magnets
        }

        pub fun getRetired(): {String: Bool} {
            return self.retired
        }

        pub fun getNumberMintedPerMagnet(): {String: UInt32} {
            return self.numberMintedPerMagnet
        }
    }

    pub struct TokensData {

        // The ID of the Brand that the Tokens comes from
        pub let brandID: String

        // The ID of the Magnet that the Tokens references
        pub let magnetiqID: String

        // The place in the edition that this Tokens was minted
        // Otherwise know as the serial number
        pub let serialNumber: UInt32
        pub let tokenType: String


        init(brandID: String, magnetiqID: String, serialNumber: UInt32, tokenType:String) {
            self.brandID = brandID
            self.magnetiqID = magnetiqID
            self.serialNumber = serialNumber
            self.tokenType = tokenType
        }
    }

    // This is an implementation of a custom metadata view for Magnetiq.
    // This view contains the magnet metadata.
    // there will be 
    pub struct MagnetiqTokenMetadataView {

        pub let name: String?
        pub let tokenType: String?
        pub let brandName: String?
        pub let serialNumber: UInt32
        pub let magnetID: String
        pub let mementoID: String?
        pub let brandID: String
        pub let numTokensInEdition: UInt32?
        pub let is_claimed: AnyStruct?
        pub let is_sellable: AnyStruct?
        pub let is_claimable: AnyStruct?
        pub let is_visible: AnyStruct?


        init(
            name: String?,
            tokenType: String?,
            brandName: String?,
            serialNumber: UInt32,
            magnetID: String,
            mementoID: String?,
            brandID: String,
            numTokensInEdition: UInt32?,
            is_claimed: AnyStruct?,
            is_sellable: AnyStruct?,
            is_claimable: AnyStruct?,
            is_visible: AnyStruct?
        ) {
            self.name = name
            self.tokenType = tokenType
            self.brandName = brandName
            self.serialNumber = serialNumber
            self.magnetID = magnetID
            self.brandID = brandID
            self.numTokensInEdition = numTokensInEdition
            self.mementoID = mementoID
            self.is_claimed= is_claimed
            self.is_claimable = is_claimable
            self.is_sellable = is_sellable
            self.is_visible = is_visible
        }
    }

    // This is an implementation of a custom metadata view for Magnetiq.
    // This view contains the magnet metadata.
    // there will be 
    pub struct MagnetTokenMetadataView {

        pub let name: String?
        pub let brandName: String?
        pub let serialNumber: UInt32
        pub let magnetID: String
        pub let brandID: String
        pub let numTokensInEdition: UInt32?
        pub let is_sellable: AnyStruct?

        init(
            name: String?,
            brandName: String?,
            serialNumber: UInt32,
            magnetID: String,
            brandID: String,
            numTokensInEdition: UInt32?,
            is_sellable: AnyStruct?
        ) {
            self.name = name
            self.brandName = brandName
            self.serialNumber = serialNumber
            self.magnetID = magnetID
            self.brandID = brandID
            self.numTokensInEdition = numTokensInEdition
            self.is_sellable = is_sellable
        }
    }

    // This is an implementation of a custom metadata view for Magnetiq.
    // This view contains the magnet metadata.
    // there will be 
    pub struct MementoTokenMetadataView {

        pub let name: String?
        pub let brandName: String?
        pub let serialNumber: UInt32
        pub let magnetID: String
        pub let mementoID: String
        pub let brandID: String
        pub let numTokensInEdition: UInt32?
        pub let is_claimed: AnyStruct?
        pub let is_sellable: AnyStruct?
        pub let is_claimable: AnyStruct?
        pub let is_visible: AnyStruct?


        init(
            name: String?,
            brandName: String?,
            serialNumber: UInt32,
            magnetID: String,
            mementoID: String,
            brandID: String,
            numTokensInEdition: UInt32?,
            is_claimed: AnyStruct?,
            is_sellable: AnyStruct?,
            is_claimable: AnyStruct?,
            is_visible: AnyStruct?
        ) {
            self.name = name
            self.brandName = brandName
            self.serialNumber = serialNumber
            self.magnetID = magnetID
            self.mementoID = mementoID
            self.brandID = brandID
            self.numTokensInEdition = numTokensInEdition
            self.is_claimed = is_claimed
            self.is_sellable = is_sellable
            self.is_claimable = is_claimable
            self.is_visible = is_visible
        }
    }


    // The resource that represents the Tokens NFTs
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        // Global unique token ID
        pub let id: UInt64
        
        // Struct of Tokens metadata
        pub let data: TokensData

        init(serialNumber: UInt32, magnetiqID: String, brandID: String, tokenType:String ) {
            // Increment the global Tokens IDs
            Magnetiq.totalSupply = Magnetiq.totalSupply + UInt64(1)

            self.id = Magnetiq.totalSupply

            // Brand the metadata struct
            self.data = TokensData(brandID: brandID, magnetiqID: magnetiqID, serialNumber: serialNumber,tokenType:tokenType )

            emit TokensMinted(tokenID: self.id, tokenType:tokenType, magnetiqID: magnetiqID, brandID: self.data.brandID, serialNumber: self.data.serialNumber)
        }

        // If the Tokens is destroyed, emit an event to indicate 
        // to outside ovbservers that it has been destroyed
        destroy() {
            emit TokensDestroyed(id: self.id)
        }

        pub fun name(): String {
            let fullName: String = Magnetiq.getMagnetMetaDataByField(magnetiqID: self.data.magnetiqID, field: "name") ?? ""
            let tokType: String = self.data.tokenType
            return fullName
                .concat(" (")
                .concat(tokType)
                .concat(")")
        }


        access(self) fun buildDescString(): String {
            let brandName: String = Magnetiq.getBrandName(brandID: self.data.brandID) ?? ""
            let serialNumber: String = self.data.serialNumber.toString()
            return "A "
                .concat(self.data.tokenType)
                .concat(" from brand")
                .concat(brandName)
                .concat(" with serial number ")
                .concat(serialNumber)
        }

        pub fun description(): String {
            var desc: String = ""
            if self.data.tokenType == "magnet"{
                desc = Magnetiq.getMagnetMetaDataByField(magnetiqID: self.data.magnetiqID, field: "description") ?? ""
            }
            else{
                desc = Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "description") ?? ""
            }
            return desc.length > 0 ? desc : self.buildDescString()
        }

        // All supported metadata views for the Token including the Core NFT Views
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MagnetiqTokenMetadataView>(), // keep the common view, and dont add individual magnet/memento view
                Type<MagnetTokenMetadataView>(),
                Type<MementoTokenMetadataView>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Medias>()
            ]
        }

       

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.description(),
                        thumbnail: MetadataViews.HTTPFile(url: self.thumbnail())
                    )

                // metadata view for magnet tokens
                case Type<MagnetTokenMetadataView>():
                    return MagnetTokenMetadataView(
                        name: Magnetiq.getMagnetMetaDataByField(magnetiqID: self.data.magnetiqID, field: "name"),
                        brandName: Magnetiq.getBrandName(brandID: self.data.brandID),
                        serialNumber: self.data.serialNumber,
                        magnetID: self.data.magnetiqID,
                        brandID: self.data.brandID,
                        numTokensInEdition: Magnetiq.getNumTokensInEdition(brandID: self.data.brandID, magnetiqID: self.data.magnetiqID, tokenType:self.data.tokenType),
                        is_sellable: Magnetiq.getMagnetMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_sellable")
                    )
                
                // metadata view for memento tokens
                case Type<MementoTokenMetadataView>():
                    return MementoTokenMetadataView(
                        name: Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "name"),
                        brandName: Magnetiq.getBrandName(brandID: self.data.brandID),
                        serialNumber: self.data.serialNumber,
                        magnetID: Magnetiq.mementoData[self.data.magnetiqID]?.magnetID!,
                        mementoID: self.data.magnetiqID,
                        brandID: self.data.brandID,
                        numTokensInEdition: Magnetiq.getNumTokensInEdition(brandID: self.data.brandID, magnetiqID: self.data.magnetiqID, tokenType:self.data.tokenType),
                        is_claimed: Magnetiq.magnetiqTokenExtraInfo[self.id]!["claimed"] ?? "",
                        is_sellable: Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_sellable"),
                        is_claimable: Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_claimable"),
                        is_visible: Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_visible")
                    )
                
                // generic metadata view for  magnetiq token
                case Type<MagnetiqTokenMetadataView>():
                        var magnetID:String = ""
                        var mementoID: String = ""
                        var is_claimed:AnyStruct? = nil
                        var is_sellable: AnyStruct? = nil
                        var is_claimable: AnyStruct? = nil
                        var is_visible: AnyStruct? = nil
                        if self.data.tokenType == "magnet" {
                            magnetID = self.data.magnetiqID
                        }
                        else {
                            mementoID = self.data.magnetiqID
                            magnetID = Magnetiq.mementoData[self.data.magnetiqID]?.magnetID!
                            is_sellable = Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_sellable")
                            is_claimable = Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_claimable")
                            is_visible = Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "is_visible")
                            is_claimed=  Magnetiq.magnetiqTokenExtraInfo[self.id]!["claimed"] ?? ""
                        }
                        return MagnetiqTokenMetadataView(
                        name: Magnetiq.getMementoMetaDataByField(magnetiqID: self.data.magnetiqID, field: "name"),
                        tokenType: self.data.tokenType,
                        brandName: Magnetiq.getBrandName(brandID: self.data.brandID),
                        serialNumber: self.data.serialNumber,
                        magnetID: magnetID,
                        mementoID: mementoID,
                        brandID: self.data.brandID,
                        numTokensInEdition: Magnetiq.getNumTokensInEdition(brandID: self.data.brandID, magnetiqID: self.data.magnetiqID, tokenType:self.data.tokenType),
                        is_claimed: is_claimed,
                        is_sellable: is_sellable,
                        is_claimable: is_claimable,
                        is_visible: is_visible
                    )
                    
                case Type<MetadataViews.Editions>():
                    let name = self.getEditionName()
                    let max = Magnetiq.getNumTokensInEdition(brandID: self.data.brandID, magnetiqID: self.data.magnetiqID,tokenType:self.data.tokenType) ?? 0
                    let editionInfo = MetadataViews.Edition(name: name, number: UInt64(self.data.serialNumber), max: max > 0 ? UInt64(max) : nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        UInt64(self.data.serialNumber)
                    )
                case Type<MetadataViews.Royalties>():
                    let royaltyReceiver: Capability<&{FungibleToken.Receiver}> =
                        getAccount(Magnetiq.RoyaltyAddress()).getCapability<&AnyResource{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath())
                    return MetadataViews.Royalties(
                        royalties: [
                            MetadataViews.Royalty(
                                receiver: royaltyReceiver,
                                cut: Magnetiq.royalityPercentage,
                                description: "Magnetiq marketplace royalty"
                            )
                        ]
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(self.getTokensURL())
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: /storage/MagnetiqTokensCollection,
                        publicPath: /public/MagnetiqTokensCollection,
                        providerPath: /private/MagnetiqTokensCollection,
                        publicCollection: Type<&Magnetiq.Collection{Magnetiq.TokenCollectionPublic}>(),
                        publicLinkedType: Type<&Magnetiq.Collection{Magnetiq.TokenCollectionPublic,NonFungibleToken.Receiver,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Magnetiq.Collection{NonFungibleToken.Provider,Magnetiq.TokenCollectionPublic,NonFungibleToken.Receiver,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-Magnetiq.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://uploads-ssl.webflow.com/6350da127b016e31ff9c689e/6356deea1c98ed1f7541dc93_Group%20670-p-500.png"
                        ),
                        mediaType: "image/png"
                    )
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://uploads-ssl.webflow.com/6350da127b016e31ff9c689e/6356deea1c98ed1f7541dc93_Group%20670-p-500.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Magnetiq",
                        description: " Magnetiq is your chance to own, sell, and trade official digital collectibles of the  and W's greatest magnets and magneters",
                        externalURL: MetadataViews.ExternalURL("https://www.magnetiq.xyz/"),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/magnetiq_xyz"),
                            "discord": MetadataViews.ExternalURL("https://discord.com/invite/Magnetiq"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/magnetiq_xyz")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    // sports radar team id
                    let excludedNames: [String] = ["TeamAtTokensID"]
                    // non magnet specific traits
                    let traitDictionary: {String: AnyStruct} = {
                        "BrandName": Magnetiq.getBrandName(brandID: self.data.brandID),
                        "SerialNumber": self.data.serialNumber
                    }
                    // add magnet specific data
                    let fullDictionary = self.mapMagnetData(dict: traitDictionary)
                    return MetadataViews.dictToTraits(dict: fullDictionary, excludedNames: excludedNames)
                case Type<MetadataViews.Medias>():
                    return MetadataViews.Medias(
                        items: [
                            MetadataViews.Media(
                                file: MetadataViews.HTTPFile(
                                    url: self.mediumimage()
                                ),
                                mediaType: "image/jpeg"
                            ),
                            MetadataViews.Media(
                                file: MetadataViews.HTTPFile(
                                    url: self.video()
                                ),
                                mediaType: "video/mp4"
                            )
                        ]
                    )
            }

            return nil
        }   

        // Functions used for computing MetadataViews 

        // mapMagnetData helps build our trait map from magnet metadata
        // Returns: The trait map with all non-empty fields from magnet data added
        pub fun mapMagnetData(dict: {String: AnyStruct}) : {String: AnyStruct} {
            if self.data.tokenType == "magnet"{
                let magnetMetadata = Magnetiq.getMagnetMetaData(magnetID: self.data.magnetiqID) ?? {}
                for name in magnetMetadata.keys {
                    let value = magnetMetadata[name] ?? ""
                    if value != "" {
                        dict.insert(key: name, value)
                    }
                }
                return dict
                }
            return {}
        }

        // getTokensURL 
        // Returns: The computed external url of the token
        pub fun getTokensURL(): String {
            return "https://Magnetiq.com/token/".concat(self.id.toString())
        }
        // getEditionName Tokens's edition name is a combination of the Tokens's brandName and magnetID
        // `brandName: #magnetID`
        pub fun getEditionName() : String {
            if self.data.tokenType != "magnet"{
                return ""
            } 
            let brandName: String = Magnetiq.getBrandName(brandID: self.data.brandID) ?? ""
            let editionName = brandName.concat(": #").concat(self.data.magnetiqID)
            return editionName
        }

        pub fun assetPath(): String {
            if self.data.tokenType == "magnet" {
                let magnet = (&Magnetiq.magnetData[self.data.magnetiqID] as &Magnet?)!
                if magnet==nil {
                return "https://magnetiq-static.s3.amazonaws.com/media/public/Achievement_1stMagnet_Owned_dJROjdG.jpg"
                }

                let image_url:String =  magnet.metadata["image_url"]!
                return image_url
            }
            else {
                let memento = (&Magnetiq.mementoData[self.data.magnetiqID] as &Memento?)!
                if memento==nil {
                return "https://magnetiq-static.s3.amazonaws.com/media/public/Achievement_1stMagnet_Owned_dJROjdG.jpg"
                }

                let image_url:String =  memento.metadata["image_url"]!
                return image_url    
            }
            
            //return "https://magnetiq-static.s3.amazonaws.com/media/public/Achievement_1stMagnet_Owned_dJROjdG.jpg" //"https://assets.Magnetiq.com/media/".concat(self.id.toString())
        }

        // returns a url to display an medium sized image
        pub fun mediumimage(): String {
            let url = self.assetPath().concat("?width=512")
            return self.appendOptionalParams(url: url, firstDelim: "&")
        }

        // a url to display a thumbnail associated with the token
        pub fun thumbnail(): String {
            let url = self.assetPath().concat("?width=256")
            return self.appendOptionalParams(url: url, firstDelim: "&")
        }

        // a url to display a video associated with the token
        pub fun video(): String {
            let url = self.assetPath().concat("/video")
            return self.appendOptionalParams(url: url, firstDelim: "?")
        }

        // appends and optional network param needed to resolve the media
        pub fun appendOptionalParams(url: String, firstDelim: String): String {
            if (Magnetiq.Network() == "testnet") {
                return url.concat(firstDelim).concat("env=testnet")
            }
            return url
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to perform important functions to modify the 
    // various aspects of the Magnets, Brands, and Tokens
    //
    pub resource Admin {

        // createMagnet creates a new Magnet struct 
        // and stores it in the Magnets dictionary in the Magnetiq smart contract
        //
        // Parameters: metadata: A dictionary mapping metadata titles to their data
        //                       example: {"Magneter Name": "Kevin Durant", "Height": "7 feet"}
        //                               (because we all know Kevin Durant is not 6'9")
        //
        // Returns: the ID of the new Magnet object
        //
        pub fun createMagnet(metadata: {String: String}, magnetID:String): String {
            pre {
                    Magnetiq.magnetData[magnetID] == nil: "Magnet already exists"
                }
       
            // Create the new Magnet
            var newMagnet = Magnet(metadata: metadata, magnetID:magnetID)
            // Store it in the contract storage
            Magnetiq.magnetData[magnetID] = newMagnet
            // add refernce to magnetid in brand
            emit MagnetCreated(id: newMagnet.magnetID, metadata: metadata)
            return magnetID
        }

        pub fun createAndAddMagnet(metadata: {String: String}, magnetID:String, brandID:String): String {
            pre {
                    Magnetiq.brands[brandID] != nil : "The Brand doesn't exist"
            }
            let magnetID = self.createMagnet(metadata:metadata, magnetID:magnetID)
            let brand = (&Magnetiq.brands[brandID] as &Brand?)!
            brand.addMagnet(magnetID:magnetID)
            return magnetID
        }

        pub fun updateMagnetMetadata(magnetID:String, new_metadata:{String:String}){
            pre {
                    Magnetiq.magnetData[magnetID] != nil: "Magnet doesn't exist"
                }
            var magnet = Magnetiq.magnetData[magnetID]!
            magnet.updateMetadata(new_metadata: new_metadata)
            Magnetiq.magnetData[magnetID] = magnet
            emit MagnetMetadataUpdated(id:magnetID , metadata: new_metadata)
        }

        pub fun updateMementoMetadata(mementoID:String, new_metadata:{String:String}){
            pre {
                    Magnetiq.mementoData[mementoID] != nil: "Memento doesn't exist"
                }
            var memento = Magnetiq.mementoData[mementoID]!
            memento.updateMementoMetadata(new_metadata: new_metadata)
            Magnetiq.mementoData[mementoID] = memento
            emit MementoMetadataUpdated(id:mementoID , metadata: new_metadata)
        }

        //createMemento creates a new momnto linked with a magnet and stores in mementoData struct
        pub fun createMemento(mementoID:String, magnetID:String,metadata:{String:String}): String
        {
            pre{
                Magnetiq.magnetData[magnetID]!=nil: "Cannot create Memento: Magnet Doesn't exist"
            }
            // Create the new Memento
            var newMemento = Memento(mementoID:mementoID, magnetID:magnetID, metadata:metadata)
            // Store it in the contract storage
            Magnetiq.mementoData[mementoID] = newMemento
            emit MementoCreated(mementoID:mementoID, magnetID:magnetID)

            // update magent with this mementoid
            let magnet =  Magnetiq.magnetData[magnetID]!
            magnet.updateMementoList(mementoID:mementoID)

            return mementoID
        }



        // createBrand creates a new Brand resource and stores it
        // in the brands mapping in the Magnetiq contract
        //
        // Parameters: name: The name of the Brand
        //
        // Returns: The ID of the created brand
        pub fun createBrand(name: String, brandID:String): String {
            pre {
                    Magnetiq.brands[brandID] == nil: "Brand with this id already exists"
            }

            // Create the new Brand
            var newBrand <- create Brand(name: name, brandID:brandID)

            emit BrandCreated(brandID: brandID)

            // Store it in the brands mapping field
            Magnetiq.brands[brandID] <-! newBrand

            return brandID
        }

        // borrowBrand returns a reference to a brand in the Magnetiq
        // contract so that the admin can call methods on it
        //
        // Parameters: brandID: The ID of the Brand that you want to
        // get a reference to
        //
        // Returns: A reference to the Brand with all of the fields
        // and methods exposed
        //
        pub fun borrowBrand(brandID: String): &Brand {
            pre {
                Magnetiq.brands[brandID] != nil: "Cannot borrow Brand: The Brand doesn't exist"
            }
            
            // Get a reference to the Brand and return it
            // use `&` to indicate the reference to the object and type
            return (&Magnetiq.brands[brandID] as &Brand?)!
        }


        // createNewAdmin creates a new Admin resource
        //
        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }

        pub fun markTokenClaimed(tokenID:UInt64){
            pre{
                Magnetiq.magnetiqTokenExtraInfo[tokenID] !=nil : "Token does not exist"
            }
            Magnetiq.magnetiqTokenExtraInfo[tokenID]!.insert(key: "claimed",true) 
            emit TokenClaimed(tokenID:tokenID)
        }

        pub fun setRoyalityReceiverAndPercentage(royaltyReceiver:Address, royalityPercentage: UFix64){
            Magnetiq.royalityReceiver = royaltyReceiver
            Magnetiq.royalityPercentage = royalityPercentage
        }

        pub fun setNetwork(networkName: String){
            Magnetiq.currentNetwork = networkName
        }

        pub fun allowAddressToSellNonSellableNFT(addresses: [Address]){
            for addr in addresses{
            Magnetiq.allowedSellersForNonSellableNFT.append(addr)
            }
        }

        // function to add custom field at magnetiqToken level
        pub fun addFieldsOnMagnetiqToken(tokenID:UInt64,fields:{String:AnyStruct}){
            if let tokenField = Magnetiq.magnetiqTokenExtraInfo[tokenID] {
                for name in fields.keys {
                        let value = fields[name] ?? nil
                        if value != nil {
                            tokenField.insert(key: name, value)
                        }
                    }
                Magnetiq.magnetiqTokenExtraInfo[tokenID] = tokenField
            }
            else {
            panic("Magnetiq Token doesn't exist")
            }
        }

        pub fun removeFieldsOnMagnetiqToken(tokenID:UInt64, fields:[String]){
            if let tokenField = Magnetiq.magnetiqTokenExtraInfo[tokenID] {
                for name in fields {
                    tokenField.remove(key: name)
                    }
                Magnetiq.magnetiqTokenExtraInfo[tokenID] = tokenField
            }
            else{
            panic("Magnetiq Token doesn't exist")
            }
        }
        pub fun resetAllowedSellersForNonSellableNFT(){
            Magnetiq.allowedSellersForNonSellableNFT=[Magnetiq.account.address]
        }
    }
    // This is the interface that users can cast their Tokens Collection as
    // to allow others to deposit Tokens into their Collection. It also allows for reading
    // the IDs of Tokens in the Collection.
    pub resource interface TokenCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowToken(id: UInt64): &Magnetiq.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Token reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection is a resource that every user who owns NFTs 
    // will store in their account to manage their NFTS
    //
    pub resource Collection: TokenCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection { 
        // Dictionary of Token (Magnet/Memeto) conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes an Token from the Collection and moves it to the caller
        //
        // Parameters: withdrawID: The ID of the NFT 
        // that is to be removed from the Collection
        //
        // returns: @NonFungibleToken.NFT the token that was withdrawn
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {

            // Borrow nft and check if locked
            let nft = self.borrowNFT(id: withdrawID)
            if MagnetiqLocking.isLocked(nftRef: nft) {
                panic("Cannot withdraw: Token is locked")
            }
            if let magnetiq_nft = self.borrowToken(id: withdrawID){
                let token_data = magnetiq_nft.data
                let token_type=token_data.tokenType
                let magnetiq_id = token_data.magnetiqID
                var is_sellable: String? = ""
                if token_type == "magnet" {
                   is_sellable = Magnetiq.getMagnetMetaDataByField(magnetiqID: magnetiq_id, field: "is_sellable")
                }
                else if token_type == "memento" {
                    is_sellable = Magnetiq.getMementoMetaDataByField(magnetiqID: magnetiq_id, field: "is_sellable")
                }

                if is_sellable?.toLower() == "false" && !Magnetiq.allowedSellersForNonSellableNFT.contains(self.owner?.address) {
                    panic("Token is not sellable")
                }
            }

            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: Token does not exist in the collection")

            emit Withdraw(id: token.id, from: self.owner?.address)
            
            // Return the withdrawn token
            return <-token
        }

        // batchWithdraw withdraws multiple tokens and returns them as a Collection
        //
        // Parameters: ids: An array of IDs to withdraw
        //
        // Returns: @NonFungibleToken.Collection: A collection that contains
        //                                        the withdrawn Token
        //
        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()
            
            // Iterate through the ids and withdraw them from the Collection
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            
            // Return the withdrawn Token
            return <-batchCollection
        }

        // deposit takes a Token and adds it to the Collections dictionary
        //
        // Paramters: token: the NFT to be deposited in the collection
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            
            // Cast the deposited token as a Magnetiq NFT to make sure
            // it is the correct type
            let token <- token as! @Magnetiq.NFT

            // Get the token's ID
            let id = token.id

            // Add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            // Only emit a deposit event if the Collection 
            // is in an account's storage
            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }

            // Destroy the empty old token that was "removed"
            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // lock takes a token id and a duration in seconds and locks
        // the token for that duration
        pub fun lock(id: UInt64, duration: UFix64) {
            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: id) 
                ?? panic("Cannot lock: Token does not exist in the collection")

            // pass the token to the locking contract
            // store it again after it comes back
            let oldToken <- self.ownedNFTs[id] <- MagnetiqLocking.lockNFT(nft: <- token, duration: duration)

            destroy oldToken
        }

        // batchLock takes an array of token ids and a duration in seconds
        // it iterates through the ids and locks each for the specified duration
        pub fun batchLock(ids: [UInt64], duration: UFix64) {
            // Iterate through the ids and lock them
            for id in ids {
                self.lock(id: id, duration: duration)
            }
        }

        // unlock takes a token id and attempts to unlock it
        // MagnetiqLocking.unlockNFT contains business logic around unlock eligibility
        pub fun unlock(id: UInt64) {
            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: id) 
                ?? panic("Cannot lock: Token does not exist in the collection")

            // Pass the token to the MagnetiqLocking contract then get it back
            // Store it back to the ownedNFTs dictionary
            let oldToken <- self.ownedNFTs[id] <- MagnetiqLocking.unlockNFT(nft: <- token)

            destroy oldToken
        }

        // batchUnlock takes an array of token ids
        // it iterates through the ids and unlocks each if they are eligible
        pub fun batchUnlock(ids: [UInt64]) {
            // Iterate through the ids and unlocks them
            for id in ids {
                self.unlock(id: id)
            }
        }

        // getIDs returns an array of the IDs that are in the Collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT Returns a borrowed reference to a Token in the Collection
        // so that the caller can read its ID
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        //
        // Note: This only allows the caller to read the ID of the NFT,
        // not any Magnetiq specific data. Please use borrowToken to 
        // read Token data.
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowToken returns a borrowed reference to a Token
        // so that the caller can read data and call methods from it.
        // They can use this to read its brandID, magnetID, serialNumber,
        // or any of the brandData or Magnet data associated with it by
        // getting the brandID or magnetID and reading those fields from
        // the smart contract.
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        pub fun borrowToken(id: UInt64): &Magnetiq.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Magnetiq.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! 
            let magnetiqNFT = nft as! &Magnetiq.NFT
            return magnetiqNFT as &AnyResource{MetadataViews.Resolver}
        }

        // If a transaction destroys the Collection object,
        // All the NFTs contained within are also destroyed!
        // Much like when Damian Lillard destroys the hopes and
        // dreams of the entire city of Houston.
        //
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // Magnetiq contract-level function definitions
    // -----------------------------------------------------------------------

    // createEmptyCollection creates a new, empty Collection object so that
    // a user can store it in their account storage.
    // Once they have a Collection in their storage, they are able to receive
    // Tokens in transactions.
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <-create Magnetiq.Collection()
    }

    // getAllMagnets returns all the magnets in Magnetiq
    //
    // Returns: An array of all the magnets that have been created
    pub fun getAllMagnets(): [Magnetiq.Magnet] {
        return Magnetiq.magnetData.values
    }

    // getAllMementos returns all the mementos in Magnetiq
    //
    // Returns: An array of all the mementos that have been created
    pub fun getAllMementos(): [Magnetiq.Memento] {
        return Magnetiq.mementoData.values
    }

    // getMagnetMetaData returns all the metadata associated with a specific Magnet
    // 
    // Parameters: magnetID: The id of the Magnet that is being searched
    //
    // Returns: The metadata as a String to String mapping optional
    pub fun getMagnetMetaData(magnetID: String): {String: String}? {
        return self.magnetData[magnetID]?.metadata
    }

    // getMagnetMetaDataByField returns the metadata associated with a 
    //                        specific field of the metadata
    //                        Ex: field: "Team" will return something
    //                        like "Memphis Grizzlies"
    // 
    // Parameters: magnetID: The id of the Magnet that is being searched
    //             field: The field to search for
    //
    // Returns: The metadata field as a String Optional
    pub fun getMagnetMetaDataByField(magnetiqID: String, field: String): String? {
        // Don't force a revert if the magnetID or field is invalid
        if let magnet = Magnetiq.magnetData[magnetiqID] {
            return magnet.metadata[field]
        } else {
            return nil
        }
    }

    // getMementoMetaData returns all the metadata associated with a specific Memento
    // 
    // Parameters: mementoID: The id of the Magnet that is being searched
    //
    // Returns: The metadata as a String to String mapping optional
    pub fun getMementoMetaData(magnetiqID: String): {String: String}? {
        return self.mementoData[magnetiqID]?.metadata
    }

    pub fun getMementoMetaDataByField(magnetiqID: String, field: String): String? {
        // Don't force a revert if the magnetID or field is invalid
        if let memento = Magnetiq.mementoData[magnetiqID]{
                return memento.metadata[field]
        }
        return nil
    }

    // getBrandData returns the data that the specified Brand
    //            is associated with.
    // 
    // Parameters: brandID: The id of the Brand that is being searched
    //
    // Returns: The QueryBrandData struct that has all the important information about the brand
    pub fun getBrandData(brandID: String): QueryBrandData? {
        if Magnetiq.brands[brandID] == nil {
            return nil
        } else {
            return QueryBrandData(brandID: brandID)
        }
    }

    // getBrandName returns the name that the specified Brand
    //            is associated with.
    // 
    // Parameters: brandID: The id of the Brand that is being searched
    //
    // Returns: The name of the Brand
    pub fun getBrandName(brandID: String): String? {
        // Don't force a revert if the brandID is invalid
        return Magnetiq.brandData[brandID]?.name
    }

    // getBrandIDsByName returns the IDs that the specified Brand name
    //                 is associated with.
    // 
    // Parameters: brandName: The name of the Brand that is being searched
    //
    // Returns: An array of the IDs of the Brand if it exists, or nil if doesn't
    pub fun getBrandIDsByName(brandName: String): [String]? {
        var brandIDs: [String] = []

        // Iterate through all the brandData and search for the name
        for brandData in Magnetiq.brandData.values {
            if brandName == brandData.name {
                // If the name is found, return the ID
                brandIDs.append(brandData.brandID)
            }
        }

        // If the name isn't found, return nil
        // Don't force a revert if the brandName is invalid
        if brandIDs.length == 0 {
            return nil
        } else {
            return brandIDs
        }
    }

    // getMagnetsInBrand returns the list of Magnet IDs that are in the Brand
    // 
    // Parameters: brandID: The id of the Brand that is being searched
    //
    // Returns: An array of Magnet IDs
    pub fun getMagnetsInBrand(brandID: String): [String]? {
        // Don't force a revert if the brandID is invalid
        return Magnetiq.brands[brandID]?.magnets
    }

    // getMementoInMagnet returns the list of Memento IDs that are in the Magnet
    // 
    // Parameters: magnetID: The id of the Brand that is being searched
    //
    // Returns: An array of Memento IDs
    pub fun getMementoInMagnet(magnetID: String): [String]? {
        // Don't force a revert if the magnetID is invalid
        return Magnetiq.magnetData[magnetID]?.mementos
    }

    // function to check if a memento is claimed or not
    pub fun isMementoTokenClaimed(tokenID:UInt64): AnyStruct? {
        if let is_claimed = Magnetiq.magnetiqTokenExtraInfo[tokenID]!["claimed"] {
            return is_claimed
        }
        return nil
    }

    pub fun getMagnetiqTokenExtraData(tokenID:UInt64): {String:AnyStruct}?{
        return Magnetiq.magnetiqTokenExtraInfo[tokenID]
    }

    // isBrandLocked returns a boolean that indicates if a Brand
    //             is locked. If it's locked, 
    //             new Magnets can no longer be added to it,
    //             but Tokens can still be minted from Magnets the brand contains.
    // 
    // Parameters: brandID: The id of the Brand that is being searched
    //
    // Returns: Boolean indicating if the Brand is locked or not
    pub fun isBrandLocked(brandID: String): Bool? {
        // Don't force a revert if the brandID is invalid
        return Magnetiq.brands[brandID]?.locked
    }

    // getNumTokensInEdition return the number of Tokens that have been 
    //                        minted from a certain edition.
    //
    // Parameters: brandID: The id of the Brand that is being searched
    //             magnetID: The id of the Magnet that is being searched
    //
    // Returns: The total number of Tokens 
    //          that have been minted from an edition
    pub fun getNumTokensInEdition(brandID: String, magnetiqID: String,tokenType:String): UInt32? {
        if tokenType == "magnet" {
            if let branddata = self.getBrandData(brandID: brandID) {
                // Read the numMintedPerMagnet
                let amount = branddata.getNumberMintedPerMagnet()[magnetiqID]
                return amount
            } else {
                // If the brand wasn't found return nil
                return nil
            }
        }
        // For memento type 
        else {
            if let magnet = Magnetiq.magnetData[magnetiqID] {
                // Read the numMintedPerMemento
                let amount = magnet.numberMintedPerMemento[magnetiqID]
                return amount
            }
            else {
                return nil
            }
        }
        
    }

    // function which returns allowed sellers list
    pub fun getAllowedSellersForNonSellableNFT():[Address?]{
        return self.allowedSellersForNonSellableNFT
    }

    // -----------------------------------------------------------------------
    // Magnetiq initialization function
    // -----------------------------------------------------------------------
    //
    init() {
        // Initialize contract fields
        self.currentSeries = 0 // depricated and will be removed
        self.magnetData = {} //  all magnets and their data with key as magnetID
        self.mementoData = {} //  all mementos and their data with key as mementoID
        self.brandData = {} // all brands data(struct) with key as brandID
        self.brands <- {} // all brands(resources) dict with key as brandID
        
        // all token ids as key with dictionary as value representing other info of NFT 
        // e.g : claimed = true/false
        self.magnetiqTokenExtraInfo = {}
        self.totalSupply = 0 //total supply of all magnets/memento, used to assign new id to NFT
        self.currentNetwork = "mainnet" //  current network for contract
        self.royalityReceiver = 0x593fb684e04120f5 // address to receive royality
        self.royalityPercentage = 0.05 // percentage of royality go to royalityReceiver
        self.allowedSellersForNonSellableNFT = [self.account.address] // allowing admin to sell non sellable NFT

        // Put a new Collection in storage
        self.account.save<@Collection>(<- create Collection(), to: /storage/MagnetiqTokensCollection)

        // Create a public capability for the Collection
        self.account.link<&{TokenCollectionPublic}>(/public/MagnetiqTokensCollection, target: /storage/MagnetiqTokensCollection)

        // Put the Minter in storage
        self.account.save<@Admin>(<- create Admin(), to: /storage/MagnetiqAdmin)

        emit ContractInitialized()
    }
}
 