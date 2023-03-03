/**

    TrmAssetV2_1.cdc

    Description: Contract definitions for initializing Asset Collections, Asset NFT Resource and Asset Minter

    Asset contract is used for defining the Asset NFT, Asset Collection, 
    Asset Collection Public Interface and Asset Minter

    ## `NFT` resource

    The core resource type that represents an Asset NFT in the smart contract.

    ## `Collection` Resource

    The resource that stores a user's Asset NFT collection.
    It includes a few functions to allow the owner to easily
    move tokens in and out of the collection.

    ## `Receiver` resource interfaces

    This interface is used for depositing Asset NFTs to the Asset Collectio.
    It also exposes few functions to fetch data about Asset

    To send an NFT to another user, a user would simply withdraw the NFT
    from their Collection, then call the deposit function on another user's
    Collection to complete the transfer.

    ## `Minter` Resource

    Minter resource is used for minting Asset NFTs

*/

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x61fc4b873e58733b

pub contract TrmAssetV2_1: NonFungibleToken {
    // -----------------------------------------------------------------------
    // Asset contract Event definitions
    // -----------------------------------------------------------------------

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64
    // Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()
    // Emitted when an Asset is minted
    pub event AssetMinted(id: UInt64, kID: String, serialNumber: UInt64, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetType: String, assetMetadata: {String: String}, owner: Address?)
    // Emitted when a batch of Assets are minted successfully
    pub event AssetBatchMinted(startId: UInt64, endId: UInt64, kID: String, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetType: String, assetMetadata: {String: String}, totalSerialNumbers: UInt64, owner: Address?)
    // Emitted when an Asset is updated
    pub event AssetUpdated(id: UInt64, assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?, owner: Address?)
    // Emitted when a batch of Assets are updated successfully
    pub event AssetBatchUpdated(ids: [UInt64], kID: String, assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?, owner: Address?)
    // Emitted when an Asset is destroyed
    pub event AssetDestroyed(id: UInt64)
    // Emitted when an Asset metadata entry is updated
    pub event AssetMetadataEntryAdded(id: UInt64, key: String, value: String)
    // Emitted when an Asset metadata entry is updated
    pub event AssetMetadataEntryBatchAdded(ids: [UInt64], kID: String, key: String, value: String)
    // Emitted when an Asset metadata entry is updated
    pub event AssetMetadataEntryUpdated(id: UInt64, key: String, value: String)
    // Emitted when an Asset metadata entry is updated
    pub event AssetMetadataEntryBatchUpdated(ids: [UInt64], kID: String, key: String, value: String)
    // Emitted when an Asset metadata entry is updated
    pub event AssetMetadataEntryRemoved(id: UInt64, key: String)
    // Emitted when an Asset metadata entry is updated
    pub event AssetMetadataEntryBatchRemoved(ids: [UInt64], kID: String, key: String)
    // Event that is emitted when a token is withdrawn, indicating the owner of the collection that it was withdrawn from. If the collection is not in an account's storage, `from` will be `nil`.
    pub event Withdraw(id: UInt64, from: Address?)
    // Event that emitted when a token is deposited to a collection. It indicates the owner of the collection that it was deposited to.
    pub event Deposit(id: UInt64, to: Address?)
    // Event that is emitted when an invitee is added to the Invitee List
    pub event Invite(id: UInt64, invitee: Address)
    // Event that is emitted when an invitee is removed to the Invitee List
    pub event Disinvite(id: UInt64, invitee: Address)

    /// Paths where Storage and capabilities are stored
    pub let collectionStoragePath: StoragePath
    pub let collectionPublicPath: PublicPath
    pub let collectionPrivatePath: PrivatePath
    pub let minterStoragePath: StoragePath
    pub let adminStoragePath: StoragePath

    pub enum AssetType: UInt8 {
        pub case private
        pub case public
    }

    pub fun assetTypeToString(_ assetType: AssetType): String {
        switch assetType {
            case AssetType.private:
                return "private"
            case AssetType.public:
                return "public"
            default:
                return ""
        }
    }

    pub fun stringToAssetType(_ assetTypeStr: String): AssetType {
        switch assetTypeStr {
            case "private":
                return AssetType.private
            case "public":
                return AssetType.public
            default:
                return panic("Asset Type must be \"private\" or \"public\"")
        }
    }

    // AssetData
    //
    // Struct for storing metadata for Asset
    pub struct AssetData {
        pub let kID: String
        pub let serialNumber: UInt64
        pub var assetName: String
        pub var assetDescription: String
        pub let assetURL: String
        pub var assetThumbnailURL: String
        pub var assetType: AssetType
        pub var assetMetadata: {String: String}
        pub var invitees: [Address]

        access(contract) fun setAssetName(assetName: String) {
            self.assetName = assetName
        }

        access(contract) fun setAssetDescription(assetDescription: String) {
            self.assetDescription = assetDescription
        }

        access(contract) fun setAssetThumbnailURL(assetThumbnailURL: String) {
            self.assetThumbnailURL = assetThumbnailURL
        }

        access(contract) fun setAssetType(assetType: String) {
            self.assetType = TrmAssetV2_1.stringToAssetType(assetType)
        }

        access(contract) fun setAssetMetadata(assetMetadata: {String: String}) {
            self.assetMetadata = assetMetadata
        }

        access(contract) fun addAssetMetadataEntry(key: String, value: String) {
            self.assetMetadata[key] = value
        }

        access(contract) fun setAssetMetadataEntry(key: String, value: String) {
            pre {
                self.assetMetadata.containsKey(key):
                    "No entry matching this key in metadata!"
            }
            self.assetMetadata[key] = value
        }

        access(contract) fun removeAssetMetadataEntry(key: String) {
            pre {
                self.assetMetadata.containsKey(key):
                    "No entry matching this key in metadata!"
            }
            self.assetMetadata.remove(key: key)
        }

        access(contract) fun invite(invitee: Address) {
            if !self.invitees.contains(invitee) {
                self.invitees.append(invitee)
            }
        }

        access(contract) fun disinvite(invitee: Address) {
            if let inviteeIndex = self.invitees.firstIndex(of: invitee) {
                self.invitees.remove(at: inviteeIndex)
            }
        }

        access(contract) fun inviteeExists(invitee: Address): Bool {
            return self.invitees.contains(invitee)
        }

        access(contract) fun removeInvitees() {
            self.invitees = []
        }

        init(kID: String, serialNumber: UInt64, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetType: String, assetMetadata: {String: String}) {
            pre {
                serialNumber >= 0: "Serial Number cannot be less than 0"

                kID.length > 0: "KID is invalid"
            }

            self.kID = kID
            self.serialNumber = serialNumber
            self.assetName = assetName
            self.assetDescription = assetDescription
            self.assetURL = assetURL
            self.assetThumbnailURL = assetThumbnailURL
            self.assetType = TrmAssetV2_1.stringToAssetType(assetType)
            self.assetMetadata = assetMetadata
            self.invitees = []
        }
    }

    //  NFT
    //
    // The main Asset NFT resource that can be bought and sold by users
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let data: AssetData

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.data.assetName,
                        description: self.data.assetDescription,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.data.assetThumbnailURL
                        )
                    )
            }

            return nil
        }

        access(contract) fun updateAsset(assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?) {
            if (assetName != nil) {
                self.data.setAssetName(assetName: assetName!)
            }
            if (assetDescription != nil) {
                self.data.setAssetDescription(assetDescription: assetDescription!)
            }
            if (assetThumbnailURL != nil) {
                self.data.setAssetThumbnailURL(assetThumbnailURL: assetThumbnailURL!)
            }
            if (assetType != nil) {
                self.data.setAssetType(assetType: assetType!)
            }
            if (assetMetadata != nil) {
                self.data.setAssetMetadata(assetMetadata: assetMetadata!)
            }
        }

        access(contract) fun addAssetMetadataEntry(key: String, value: String) {
            self.data.addAssetMetadataEntry(key: key, value: value)

            emit AssetMetadataEntryAdded(id: self.id, key: key, value: value)
        }

        access(contract) fun setAssetMetadataEntry(key: String, value: String) {
            pre {
                self.data.assetMetadata.containsKey(key):
                    "No entry matching this key in metadata!"
            }
            self.data.setAssetMetadataEntry(key: key, value: value)

            emit AssetMetadataEntryUpdated(id: self.id, key: key, value: value)
        }

        access(contract) fun removeAssetMetadataEntry(key: String) {
            pre {
                self.data.assetMetadata.containsKey(key):
                    "No entry matching this key in metadata!"
            }
            self.data.removeAssetMetadataEntry(key: key)

            emit AssetMetadataEntryRemoved(id: self.id, key: key)
        }

        access(contract) fun invite(invitee: Address) {
            if !self.data.invitees.contains(invitee) {
                self.data.invite(invitee: invitee)
                emit Invite(id: self.id, invitee: invitee)
            }
        }

        access(contract) fun disinvite(invitee: Address) {
            if let inviteeIndex = self.data.invitees.firstIndex(of: invitee) {
                self.data.disinvite(invitee: invitee)
                emit Disinvite(id: self.id, invitee: invitee)
            }
        }

        access(contract) fun inviteeExists(invitee: Address): Bool {
            return self.data.inviteeExists(invitee: invitee)
        }

        access(contract) fun removeInvitees() {
            self.data.removeInvitees()
        }

        init(id: UInt64, kID: String, serialNumber: UInt64, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetType: String, assetMetadata: {String: String}) {
            self.id = id
            self.data = AssetData(kID: kID, serialNumber: serialNumber, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata)
        }

        // If the Asset NFT is destroyed, emit an event to indicate to outside observers that it has been destroyed
        destroy() {
            emit AssetDestroyed(id: self.id)
        }
    }

    // CollectionPublic
    //
    // Public interface for Asset Collection
    // This exposes functions for depositing NFTs
    // and also for returning some info for a specific
    // Asset NFT id
    pub resource interface CollectionPublic {
        access(contract) fun withdrawAsset(id: UInt64): @NonFungibleToken.NFT
        access(contract) fun depositAsset(token: @NonFungibleToken.NFT)
        access(contract) fun updateAsset(id: UInt64, assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?)
        access(contract) fun batchUpdateAsset(ids: [UInt64], kID: String, assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?)
        access(contract) fun addAssetMetadataEntry(id: UInt64, key: String, value: String)
        access(contract) fun batchAddAssetMetadataEntry(ids: [UInt64], kID: String, key: String, value: String)
        access(contract) fun setAssetMetadataEntry(id: UInt64, key: String, value: String)
        access(contract) fun batchSetAssetMetadataEntry(ids: [UInt64], kID: String, key: String, value: String)
        access(contract) fun removeAssetMetadataEntry(id: UInt64, key: String)
        access(contract) fun batchRemoveAssetMetadataEntry(ids: [UInt64], kID: String, key: String)
        access(contract) fun invite(id: UInt64, invitee: Address)
        access(contract) fun disinvite(id: UInt64, invitee: Address)
        access(contract) fun destroyToken(id: UInt64)

        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowAsset(id: UInt64): &NFT
        pub fun idExists(id: UInt64): Bool
        pub fun getKID(id: UInt64): String
        pub fun getSerialNumber(id: UInt64): UInt64
        pub fun getAssetName(id: UInt64): String
        pub fun getAssetDescription(id: UInt64): String
        pub fun getAssetURL(id: UInt64): String
        pub fun getAssetThumbnailURL(id: UInt64): String
        pub fun getAssetType(id: UInt64): String
        pub fun getAssetMetadata(id: UInt64): {String: String}
        pub fun getInvitees(id: UInt64): [Address]
        pub fun inviteeExists(id: UInt64, invitee: Address): Bool
    }

    // Collection
    //
    // The resource that stores a user's Asset NFT collection.
    // It includes a few functions to allow the owner to easily
    // move tokens in and out of the collection.
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, CollectionPublic {
        
        // Dictionary to hold the NFTs in the Collection
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            pre {
                false: "Withdrawing Asset directly from Asset contract is not allowed"
            }
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Error withdrawing Asset NFT")
            emit Withdraw(id: withdrawID, from: self.owner!.address)
            return <-token
        }

        // deposit takes an NFT as an argument and adds it to the Collection
        pub fun deposit(token: @NonFungibleToken.NFT) {
            pre {
                false: "Depositing Asset directly to Asset contract is not allowed"
            }
            let assetToken <- token as! @NFT
            assetToken.removeInvitees()

            emit Deposit(id: assetToken.id, to: self.owner!.address)

            let oldToken <- self.ownedNFTs[assetToken.id] <- assetToken
            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowViewResolver is to conform with MetadataViews
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT

            return refAssetNFT as &AnyResource{MetadataViews.Resolver}
        }

        // Returns a borrowed reference to an NFT in the collection so that the caller can read data and call methods from it
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // Returns a borrowed reference to the Asset in the collection so that the caller can read data and call methods from it
        pub fun borrowAsset(id: UInt64): &NFT {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return refNFT as! &NFT
        }

        // Checks if id of NFT exists in collection
        pub fun idExists(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }

        // Returns the asset ID for an NFT in the collection
        pub fun getKID(id: UInt64): String {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.kID
        }

        // Returns the serial number for an NFT in the collection
        pub fun getSerialNumber(id: UInt64): UInt64 {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.serialNumber
        }

        // Returns the asset name for an NFT in the collection
        pub fun getAssetName(id: UInt64): String {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.assetName
        }

        // Returns the asset description for an NFT in the collection
        pub fun getAssetDescription(id: UInt64): String {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.assetDescription
        }

        // Returns the asset URL for an NFT in the collection
        pub fun getAssetURL(id: UInt64): String {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.assetURL
        }

        // Returns the asset thumbnail URL for an NFT in the collection
        pub fun getAssetThumbnailURL(id: UInt64): String {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.assetThumbnailURL
        }

        // Returns the asset type for an NFT in the collection
        pub fun getAssetType(id: UInt64): String {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return TrmAssetV2_1.assetTypeToString(refAssetNFT.data.assetType)
        }

        // Returns the asset metadata for an NFT in the collection
        pub fun getAssetMetadata(id: UInt64): {String: String} {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.assetMetadata
        }

        // Returns the invitees list for an NFT in the collection
        pub fun getInvitees(id: UInt64): [Address] {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.data.invitees
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        access(contract) fun withdrawAsset(id: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("Error withdrawing Asset NFT")
            emit Withdraw(id: id, from: self.owner!.address)
            return <-token
        }

        // deposit takes an NFT as an argument and adds it to the Collection
        access(contract) fun depositAsset(token: @NonFungibleToken.NFT) {
            let assetToken <- token as! @NFT
            assetToken.removeInvitees()

            // This is removed as this was creating too many events in case of batch mint
            // emit Deposit(id: assetToken.id, to: self.owner!.address)

            let oldToken <- self.ownedNFTs[assetToken.id] <- assetToken
            destroy oldToken
        }

        // Sets the asset type
        access(contract) fun updateAsset(id: UInt64, assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?) {
            pre {
                assetType == "private" || assetType == "public" || assetType == nil: 
                    "Asset Type must be private or public or null"
                
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            refAssetNFT.updateAsset(assetName: assetName, assetDescription: assetDescription, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata)

            emit AssetUpdated(id: id, assetName: assetName, assetDescription: assetDescription, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata, owner: self.owner?.address)
        }

        // Sets the asset type of multiple tokens
        access(contract) fun batchUpdateAsset(ids: [UInt64], kID: String, assetName: String?, assetDescription: String?, assetThumbnailURL: String?, assetType: String?, assetMetadata: {String: String}?) {
            pre {
                assetType == "private" || assetType == "public" || assetType == nil:
                    "Asset Type must be private or public or null"

                ids.length > 0: "Total length of ids cannot be less than 1"
            }

            for id in ids {
                if self.ownedNFTs[id] != nil {
                    let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                    let refAssetNFT = refNFT as! &NFT
                    if (refAssetNFT.data.kID != kID) {
                        panic("Asset Token ID and KID do not match")
                    }
                    refAssetNFT.updateAsset(assetName: assetName, assetDescription: assetDescription, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata)
                } else {
                    panic("Asset Token ID ".concat(id.toString()).concat(" not owned"))
                }
            }

            emit AssetBatchUpdated(ids: ids, kID: kID, assetName: assetName, assetDescription: assetDescription, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata, owner: self.owner?.address)
        }

        // Adds an entry to metadata in asset
        access(contract) fun addAssetMetadataEntry(id: UInt64, key: String, value: String) {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            refAssetNFT.addAssetMetadataEntry(key: key, value: value)
        }

        // Adds an entry to metadata in asset for multiple tokens
        access(contract) fun batchAddAssetMetadataEntry(ids: [UInt64], kID: String, key: String, value: String) {
            pre {
                ids.length > 0: "Total length of ids cannot be less than 1"
            }

            for id in ids {
                if self.ownedNFTs[id] != nil {
                    let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                    let refAssetNFT = refNFT as! &NFT
                    if (refAssetNFT.data.kID != kID) {
                        panic("Asset Token ID and KID do not match")
                    }
                    refAssetNFT.addAssetMetadataEntry(key: key, value: value)
                } else {
                    panic("Asset Token ID ".concat(id.toString()).concat(" not owned"))
                }
            }

            emit AssetMetadataEntryBatchAdded(ids: ids, kID: kID, key: key, value: value)
        }

        // Sets an entry to metadata in asset
        access(contract) fun setAssetMetadataEntry(id: UInt64, key: String, value: String) {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            refAssetNFT.setAssetMetadataEntry(key: key, value: value)
        }

        // Sets an entry to metadata in asset for multiple tokens
        access(contract) fun batchSetAssetMetadataEntry(ids: [UInt64], kID: String, key: String, value: String) {
            pre {
                ids.length > 0: "Total length of ids cannot be less than 1"
            }

            for id in ids {
                if self.ownedNFTs[id] != nil {
                    let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                    let refAssetNFT = refNFT as! &NFT
                    if (refAssetNFT.data.kID != kID) {
                        panic("Asset Token ID and KID do not match")
                    }
                    refAssetNFT.setAssetMetadataEntry(key: key, value: value)
                } else {
                    panic("Asset Token ID ".concat(id.toString()).concat(" not owned"))
                }
            }

            emit AssetMetadataEntryBatchUpdated(ids: ids, kID: kID, key: key, value: value)
        }

        // Removes an entry to metadata in asset
        access(contract) fun removeAssetMetadataEntry(id: UInt64, key: String) {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            refAssetNFT.removeAssetMetadataEntry(key: key)
        }

        // Removes an entry to metadata in asset for multiple tokens
        access(contract) fun batchRemoveAssetMetadataEntry(ids: [UInt64], kID: String, key: String) {
            pre {
                ids.length > 0: "Total length of ids cannot be less than 1"
            }

            for id in ids {
                if self.ownedNFTs[id] != nil {
                    let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                    let refAssetNFT = refNFT as! &NFT
                    if (refAssetNFT.data.kID != kID) {
                        panic("Asset Token ID and KID do not match")
                    }
                    refAssetNFT.removeAssetMetadataEntry(key: key)
                } else {
                    panic("Asset Token ID ".concat(id.toString()).concat(" not owned"))
                }
            }

            emit AssetMetadataEntryBatchRemoved(ids: ids, kID: kID, key: key)
        }

        // Add an invitee to invitee list
        access(contract) fun invite(id: UInt64, invitee: Address) {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            refAssetNFT.invite(invitee: invitee)
        }

        // Remove an invitee to invitee list. Only the owner of the asset is allowed to set this
        access(contract) fun disinvite(id: UInt64, invitee: Address) {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            refAssetNFT.disinvite(invitee: invitee)
        }

        pub fun inviteeExists(id: UInt64, invitee: Address): Bool {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }

            let refNFT = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refAssetNFT = refNFT as! &NFT
            return refAssetNFT.inviteeExists(invitee: invitee)
        }

        // Destroys specified token in the collection
        access(contract) fun destroyToken(id: UInt64) {
            pre {
                self.ownedNFTs[id] != nil: "Asset Token ID does not exist"
            }
            let oldToken <- self.ownedNFTs.remove(key: id)
            destroy oldToken
        }

        // If a transaction destroys the Collection object, all the NFTs contained within are also destroyed!
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // createEmptyCollection creates an empty Collection and returns it to the caller so that they can own NFTs
    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    // Minter
    //
    // Minter is a special resource that is used for minting Assets
    pub resource Minter {

        // mintNFT mints the asset NFT and stores it in the collection of recipient
        pub fun mintNFT(kID: String, serialNumber: UInt64, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetType: String, assetMetadata: {String: String}, recipient: &TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic, NonFungibleToken.CollectionPublic}): UInt64 {
            pre {
                assetType == "private" || assetType == "public":
                    "Asset Type must be private or public"

                serialNumber >= 0: "Serial Number cannot be less than 0"

                kID.length > 0: "KID is invalid"
            }

            let tokenID = TrmAssetV2_1.totalSupply

            recipient.depositAsset(token: <- create NFT(id: tokenID, kID: kID, serialNumber: serialNumber, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata))

            emit AssetMinted(id: tokenID, kID: kID, serialNumber: serialNumber, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata, owner: recipient.owner?.address)

            TrmAssetV2_1.totalSupply = tokenID + 1
            
            return TrmAssetV2_1.totalSupply
        }

        // batchMintNFTs mints the asset NFT in batch and stores it in the collection of recipient
        pub fun batchMintNFTs(kID: String, totalSerialNumbers: UInt64, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetType: String, assetMetadata: {String: String}, recipient: &TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic, NonFungibleToken.CollectionPublic}): UInt64 {
            pre {
                assetType == "private" || assetType == "public":
                    "Asset Type must be private or public"

                totalSerialNumbers > 0: "Total Serial Numbers cannot be less than 1"

                assetURL.length > 0: "Asset URL is invalid"

                kID.length > 0: "KID is invalid"
            }

            let startTokenID = TrmAssetV2_1.totalSupply
            var tokenID = startTokenID
            var counter: UInt64 = 0

            while counter < totalSerialNumbers {

                recipient.depositAsset(token: <- create NFT(id: tokenID, kID: kID, serialNumber: counter, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata))

                counter = counter + 1
                tokenID = tokenID + 1
            }

            let endTokenID = tokenID - 1

            emit AssetBatchMinted(startId: startTokenID, endId: endTokenID, kID: kID, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata, totalSerialNumbers: totalSerialNumbers, owner: recipient.owner?.address)

            TrmAssetV2_1.totalSupply = tokenID
            
            return TrmAssetV2_1.totalSupply
        }
    }

    /// Admin is a special authorization resource that 
    /// allows the admin to perform important functions
    pub resource Admin {

        pub fun withdrawAsset(
            assetCollectionAddress: Address, 
            id: UInt64,
        ): @NonFungibleToken.NFT {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            return <-assetCollectionCapability.withdrawAsset(id: id)
        }

        pub fun depositAsset(
            assetCollectionAddress: Address, 
            token: @NonFungibleToken.NFT,
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.depositAsset(token: <-token)
        }

        pub fun updateAsset(
            assetCollectionAddress: Address, 
            id: UInt64,
            assetName: String?, 
            assetDescription: String?, 
            assetThumbnailURL: String?, 
            assetType: String?, 
            assetMetadata: {String: String}?
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.updateAsset(id: id, assetName: assetName, assetDescription: assetDescription, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata)
        }

        pub fun batchUpdateAsset(
            assetCollectionAddress: Address, 
            ids: [UInt64],
            kID: String, 
            assetName: String?, 
            assetDescription: String?, 
            assetThumbnailURL: String?, 
            assetType: String?, 
            assetMetadata: {String: String}?
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.batchUpdateAsset(ids: ids, kID: kID, assetName: assetName, assetDescription: assetDescription, assetThumbnailURL: assetThumbnailURL, assetType: assetType, assetMetadata: assetMetadata)
        }

        pub fun addAssetMetadataEntry(
            assetCollectionAddress: Address, 
            id: UInt64,
            key: String, 
            value: String
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.addAssetMetadataEntry(id: id, key: key, value: value)
        }

        pub fun batchAddAssetMetadataEntry(
            assetCollectionAddress: Address, 
            ids: [UInt64],
            kID: String,
            key: String, 
            value: String
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.batchAddAssetMetadataEntry(ids: ids, kID: kID, key: key, value: value)
        }

        pub fun setAssetMetadataEntry(
            assetCollectionAddress: Address, 
            id: UInt64,
            key: String, 
            value: String
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.setAssetMetadataEntry(id: id, key: key, value: value)
        }

        pub fun batchSetAssetMetadataEntry(
            assetCollectionAddress: Address, 
            ids: [UInt64],
            kID: String,
            key: String, 
            value: String
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.batchSetAssetMetadataEntry(ids: ids, kID: kID, key: key, value: value)
        }

        pub fun removeAssetMetadataEntry(
            assetCollectionAddress: Address, 
            id: UInt64,
            key: String
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.removeAssetMetadataEntry(id: id, key: key)
        }

        pub fun batchRemoveAssetMetadataEntry(
            assetCollectionAddress: Address, 
            ids: [UInt64],
            kID: String,
            key: String
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.batchRemoveAssetMetadataEntry(ids: ids, kID: kID, key: key)
        }

        pub fun invite(
            assetCollectionAddress: Address, 
            id: UInt64,
            invitee: Address
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.invite(id: id, invitee: invitee)
        }

        pub fun disinvite(
            assetCollectionAddress: Address, 
            id: UInt64,
            invitee: Address
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.disinvite(id: id, invitee: invitee)
        }

        pub fun destroyToken(
            assetCollectionAddress: Address, 
            id: UInt64
        ) {
            let assetCollectionCapability = getAccount(assetCollectionAddress).getCapability<&TrmAssetV2_1.Collection{TrmAssetV2_1.CollectionPublic}>(
                TrmAssetV2_1.collectionPublicPath
                ).borrow()
            ?? panic("Could not borrow asset collection capability from provided asset collection address")
            
            assetCollectionCapability.destroyToken(id: id)
        }
    }

    init() {
        self.totalSupply = 0

        // Settings paths
        self.collectionStoragePath = /storage/TrmAssetV2_1Collection
        self.collectionPublicPath = /public/TrmAssetV2_1Collection
        self.collectionPrivatePath = /private/TrmAssetV2_1Collection
        self.minterStoragePath = /storage/TrmAssetV2_1Minter
        self.adminStoragePath = /storage/TrmAssetV2_1Admin

        // First, check to see if a minter resource already exists
        if self.account.type(at: self.minterStoragePath) == nil {
            
            // Put the minter in storage with access only to admin
            self.account.save(<-create Minter(), to: self.minterStoragePath)
        }

        // First, check to see if a minter resource already exists
        if self.account.type(at: self.adminStoragePath) == nil {
            
            // Put the minter in storage with access only to admin
            self.account.save(<-create Admin(), to: self.adminStoragePath)
        }

        emit ContractInitialized()
    }
}
 