/**
    GaiaPrimarySale.cdc

    Description: Facilitates the exchange of Fungible Tokens for NFTs.
**/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract GaiaPrimarySale {

    pub let PrimarySaleStoragePath: StoragePath
    pub let PrimarySalePublicPath: PublicPath
    pub let PrimarySalePrivatePath: PrivatePath

    pub event PrimarySaleCreated(
        externalID: String,
        name: String,
        description: String,
        imageURI: String,
        nftType: Type,
        prices: {String: UFix64}
    )
    pub event PrimarySaleStatusChanged(externalID: String, status: String)
    pub event PriceSet(externalID: String, type: String, price: UFix64)
    pub event PriceRemoved(externalID: String, type: String)
    pub event AssetAdded(externalID: String, assetID: UInt64)
    pub event NFTPurchased(externalID: String, nftType: Type, assetID: UInt64, nftID: UInt64, purchaserAddress: Address, priceType: String, price: UFix64)
    pub event ContractInitialized()

    access(contract) let primarySaleIDs: [String]

    pub resource interface IMinter {
        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT
    }

    // Data struct signed by account with specified "adminPublicKey."
    //
    // Permits accounts to purchase specific NFTs for some period of time.
    pub struct AdminSignedData {
        pub let externalID: String
        pub let priceType: String
        pub let primarySaleAddress: Address
        pub let purchaserAddress: Address
        pub let assetIDs: [UInt64]
        pub let expiration: UInt64 // unix timestamp

        init(externalID: String, primarySaleAddress: Address, purchaserAddress: Address, assetIDs: [UInt64], priceType: String, expiration: UInt64){
            self.externalID = externalID
            self.primarySaleAddress = primarySaleAddress
            self.purchaserAddress = purchaserAddress
            self.assetIDs = assetIDs
            self.priceType = priceType
            self.expiration = expiration
        }

        pub fun toString(): String {
            var assetIDs = ""
            var i = 0
            while (i < self.assetIDs.length) {
                if (i > 0) {
                    assetIDs = assetIDs.concat(",")
                }
                assetIDs = assetIDs.concat(self.assetIDs[i].toString())
                i = i + 1
            }
            return self.externalID.concat(":")
                .concat(self.primarySaleAddress.toString()).concat(":")
                .concat(self.purchaserAddress.toString()).concat(":")
                .concat(assetIDs).concat(":")
                .concat(self.priceType).concat(":")
                .concat(self.expiration.toString())
        }
    }

    pub enum PrimarySaleStatus: UInt8 {
        pub case PAUSED
        pub case OPEN
        pub case CLOSED
    }

    pub resource interface PrimarySalePublic {
        pub fun getDetails(): PrimarySaleDetails
        pub fun getSupply(): Int
        pub fun getPrices(): {String: UFix64}
        pub fun getStatus(): String
        pub fun purchaseNFTs(
            payment: @FungibleToken.Vault,
            data: AdminSignedData,
            sig: String
        ): @[NonFungibleToken.NFT]
    }

    pub resource interface PrimarySalePrivate {
        pub fun pause()
        pub fun open()
        pub fun close()
        pub fun setDetails(
            name: String,
            description: String,
            imageURI: String
        )
        pub fun setPrice(priceType: String, price: UFix64)
        pub fun setAdminPublicKey(adminPublicKey: String)
        pub fun addAsset(assetID: UInt64)
    }

    pub struct PrimarySaleDetails {
        pub var name: String
        pub var description: String
        pub var imageURI: String

        init(
            name: String,
            description: String,
            imageURI: String
        ) {
            self.name = name
            self.description = description
            self.imageURI = imageURI
        }
    }

    pub resource PrimarySale: PrimarySalePublic, PrimarySalePrivate {
        access(self) var externalID: String
        pub let nftType: Type
        access(self) var status: PrimarySaleStatus
        access(self) var prices: {String: UFix64}
        access(self) var availableAssetIDs: {UInt64: Bool}

        // primary sale metadata
        access(self) var details: PrimarySaleDetails

        access(self) let minterCap: Capability<&{IMinter}>
        access(self) let paymentReceiverCap: Capability<&{FungibleToken.Receiver}>

        // pub key used to verify signatures from a specified admin
        access(self) var adminPublicKey: String

        init(
            externalID: String,
            name: String,
            description: String,
            imageURI: String,
            nftType: Type,
            prices: {String: UFix64},
            minterCap: Capability<&{IMinter}>,
            paymentReceiverCap: Capability<&{FungibleToken.Receiver}>,
            adminPublicKey: String
        ) {
            self.externalID = externalID
            self.details = PrimarySaleDetails(
                name: name,
                description: description,
                imageURI: imageURI
            )
            self.nftType = nftType
            self.status = PrimarySaleStatus.PAUSED // primary sale is paused initially
            self.availableAssetIDs = {} // no asset IDs assigned to primary sale initially
            self.prices = prices

            self.minterCap = minterCap
            self.paymentReceiverCap = paymentReceiverCap

            self.adminPublicKey = adminPublicKey

            emit PrimarySaleCreated(
                externalID: externalID,
                name: name,
                description: description,
                imageURI: imageURI,
                nftType: nftType,
                prices: prices
            )
        }

        pub fun getStatus(): String {
            if (self.status == PrimarySaleStatus.PAUSED) {
                return "PAUSED"
            } else if (self.status == PrimarySaleStatus.OPEN) {
                return "OPEN"
            } else if (self.status == PrimarySaleStatus.CLOSED) {
                return "CLOSED"
            } else {
                return ""
            }
        }

        pub fun setDetails(
            name: String,
            description: String,
            imageURI: String
        ) {
            self.details = PrimarySaleDetails(
                name: name,
                description: description,
                imageURI: imageURI
            )
        }

        pub fun getDetails(): PrimarySaleDetails {
            return self.details
        }

        pub fun setPrice(priceType: String, price: UFix64) {
            self.prices[priceType] = price
            emit PriceSet(externalID: self.externalID, type: priceType, price: price)
        }

        pub fun removePrice(priceType: String) {
            self.prices.remove(key: priceType)
            emit PriceRemoved(externalID: self.externalID, type: priceType)
        }

        pub fun getPrices(): {String: UFix64} {
            return self.prices
        }

        pub fun getSupply(): Int {
            return self.availableAssetIDs.length
        }

        pub fun setAdminPublicKey(adminPublicKey: String) {
            self.adminPublicKey = adminPublicKey
        }

        pub fun addAsset(assetID: UInt64) {
            self.availableAssetIDs[assetID] = true
            emit AssetAdded(externalID: self.externalID, assetID: assetID)
        }

        pub fun pause() {
            self.status = PrimarySaleStatus.PAUSED
            emit PrimarySaleStatusChanged(externalID: self.externalID, status: self.getStatus())
        }

        pub fun open() {
            pre {
                self.status != PrimarySaleStatus.OPEN : "Primary sale is already open"
                self.status != PrimarySaleStatus.CLOSED : "Cannot resume primary sale that is closed"
            }

            self.status = PrimarySaleStatus.OPEN
            emit PrimarySaleStatusChanged(externalID: self.externalID, status: self.getStatus())
        }

        pub fun close() {
            self.status = PrimarySaleStatus.CLOSED
            emit PrimarySaleStatusChanged(externalID: self.externalID, status: self.getStatus())
        }

        access(self) fun verifyAdminSignedData(data: AdminSignedData, sig: String): Bool {
            let publicKey = PublicKey(
                publicKey: self.adminPublicKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            )

            return publicKey.verify(
                signature: sig.decodeHex(),
                signedData: data.toString().utf8,
                domainSeparationTag: "FLOW-V0.0-user",
                hashAlgorithm: HashAlgorithm.SHA3_256
            )
        }

        pub fun purchaseNFTs(
            payment: @FungibleToken.Vault,
            data: AdminSignedData,
            sig: String
        ): @[NonFungibleToken.NFT] {
            pre {
                self.externalID == data.externalID: "externalID mismatch"
                self.status == PrimarySaleStatus.OPEN: "primary sale is not open"
                data.assetIDs.length > 0: "must purchase at least one NFT"
                self.verifyAdminSignedData(data: data, sig: sig): "invalid admin signature for data"
                data.expiration >= UInt64(getCurrentBlock().timestamp): "expired signature"
            }

            let price = self.prices[data.priceType] ?? panic("Invalid price type")

            assert(payment.balance == price * UFix64(data.assetIDs.length), message: "payment vault does not contain requested price")

            let receiver = self.paymentReceiverCap.borrow()!
            receiver.deposit(from: <- payment)

            let minter = self.minterCap.borrow() ?? panic("cannot borrow minter")

            var i: Int = 0
            let nfts: @[NonFungibleToken.NFT] <- []
            while i < data.assetIDs.length {
                let assetID = data.assetIDs[i]
                assert(self.availableAssetIDs.containsKey(assetID), message: "NFT is not available for purchase: ".concat(assetID.toString()))
                self.availableAssetIDs.remove(key: assetID)
                let nft <- minter.mint(assetID: assetID, creator: data.purchaserAddress)
                emit NFTPurchased(externalID: self.externalID, nftType: nft.getType(), assetID: assetID, nftID: nft.id, purchaserAddress: data.purchaserAddress, priceType: data.priceType, price: price)
                nfts.append(<-nft)
                i = i + 1
            }
            assert(nfts.length == data.assetIDs.length, message: "nft count mismatch")

            return <- nfts
        }
    }

    pub fun createPrimarySale(
        externalID: String,
        name: String,
        description: String,
        imageURI: String,
        nftType: Type,
        prices: {String: UFix64},
        minterCap: Capability<&{IMinter}>,
        paymentReceiverCap: Capability<&{FungibleToken.Receiver}>,
        adminPublicKey: String
    ): @PrimarySale {
        assert(!self.primarySaleIDs.contains(externalID), message: "Primary sale external ID is already in use")

        self.primarySaleIDs.append(externalID)

        return <- create PrimarySale(
            externalID: externalID,
            name: name,
            description: description,
            imageURI: imageURI,
            nftType: nftType,
            prices: prices,
            minterCap: minterCap,
            paymentReceiverCap: paymentReceiverCap,
            adminPublicKey: adminPublicKey
        )
    }

    init() {
        // default paths but not intended for multiple primary sales on same acct
        self.PrimarySaleStoragePath = /storage/GaiaPrimarySale001
        self.PrimarySalePublicPath = /public/GaiaPrimarySale001
        self.PrimarySalePrivatePath = /private/GaiaPrimarySale001

        self.primarySaleIDs = []

        emit ContractInitialized()
    }
}
