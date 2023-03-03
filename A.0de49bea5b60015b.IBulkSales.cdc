import FungibleToken from 0xf233dcee88fe0abe

/// IBulkSales
/// Contract interface for BulkListing and BulkPurchasing contracts that defines common values and interfaces
access(all) contract interface IBulkSales {

    /// AdminStoragePath
    /// Storage path for contract admin object
    access(all) AdminStoragePath: StoragePath

    /// CommissionAdminPrivatePath
    /// Private path for commission admin capability
    access(all) CommissionAdminPrivatePath: PrivatePath

    /// CommissionReaderPublicPath
    /// Public path for commission reader capability
    access(all) CommissionReaderPublicPath: PublicPath

    /// CommissionReaderCapability
    /// Stored capability for commission reader
    access(all) CommissionReaderCapability: Capability<&{ICommissionReader}>

    /// Readable
    /// Interface that provides a human-readable output of the struct's data
    access(all) struct interface IReadable {
        access(all) view fun getReadable(): {String: AnyStruct}
    }

    access(all) struct interface IRoyalty {
        access(all) receiverAddress: Address
        access(all) rate: UFix64
    }

    /// Royalty
    /// An object representing a single royalty cut for a given listing
    access(all) struct Royalty: IRoyalty, IReadable {
        init(receiverAddress: Address, rate: UFix64) {
            pre {
                rate > 0.0 && rate < 1.0: "rate must be between 0 and 1"
            }
        }
    }

    /// CommissionAdmin
    /// Private capability to manage commission receivers
    access(all) resource interface ICommissionAdmin {
        access(all) fun addCommissionReceiver(_ receiver: Capability<&AnyResource{FungibleToken.Receiver}>)
        access(all) fun removeCommissionReceiver(receiverTypeIdentifier: String)
    }

    /// CommissionReader
    /// Public capability to get a commission receiver
    access(all) resource interface ICommissionReader {
        access(all) view fun getCommissionReceiver(_ identifier: String): Capability<&AnyResource{FungibleToken.Receiver}>?
    }
}
