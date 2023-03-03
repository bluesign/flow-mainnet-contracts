// MAINNET

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowUtilityToken from 0xead892083b3e2c6c
import FlowversePass from 0x9212a87501a8a6a2
import FlowverseSocks from 0xce4c02539d1fabe8
import Crypto

pub contract FlowversePrimarySale {
    pub let AdminStoragePath: StoragePath

    // Incremented ID used to create entities
    pub var nextPrimarySaleID: UInt64

    access(contract) var primarySales: @{UInt64: PrimarySale}
    access(contract) var primarySaleIDs: {String: UInt64}

    pub event PrimarySaleCreated(
        primarySaleID: UInt64,
        contractName: String,
        contractAddress: Address,
        setID: UInt64,
        prices: {String: PriceData},
        launchDate: String,
        endDate: String,
        pooled: Bool,
    )
    pub event PrimarySaleStatusChanged(primarySaleID: UInt64, status: String)
    pub event PrimarySaleDateUpdated(primarySaleID: UInt64, date: String, isLaunch: Bool)
    pub event PriceSet(primarySaleID: UInt64, type: String, price: UFix64, eligibleAddresses: [Address]?, maxMintsPerUser: UInt64)
    pub event EntityAdded(primarySaleID: UInt64, entityID: UInt64, pool: String?, quantity: UInt64)
    pub event EntityRemoved(primarySaleID: UInt64, entityID: UInt64, pool: String?)
    // NFTPurchased is deprecated - please refer to PurchasedOrder event instead
    pub event NFTPurchased(primarySaleID: UInt64, entityID: UInt64, nftID: UInt64, purchaserAddress: Address, priceType: String, price: UFix64)
    pub event PurchasedOrder(primarySaleID: UInt64, entityID: UInt64, quantity: UInt64, nftIDs: [UInt64], purchaserAddress: Address, priceType: String, price: UFix64)
    pub event ClaimedTreasures(primarySaleID: UInt64, nftIDs: [UInt64], passIDs: [UInt64], sockIDs: [UInt64], claimerAddress: Address, pool: String)
    pub event ContractInitialized()

    pub resource interface IMinter {
        pub fun mint(entityID: UInt64, minterAddress: Address): @NonFungibleToken.NFT
    }
    
    // Data struct signed by admin account - allows accounts to purchase from a primary sale for a period of time.
    pub struct AdminSignedPayload {
        pub let primarySaleID: UInt64
        pub let purchaserAddress: Address
        pub let expiration: UInt64 // unix timestamp

        init(primarySaleID: UInt64, purchaserAddress: Address, expiration: UInt64){
            self.primarySaleID = primarySaleID
            self.purchaserAddress = purchaserAddress
            self.expiration = expiration
        }

        pub fun toString(): String {
            return self.primarySaleID.toString().concat("-")
                .concat(self.purchaserAddress.toString()).concat("-")
                .concat(self.expiration.toString())
        }
    }

    pub struct PriceData {
        pub let priceType: String
        pub let eligibleAddresses: [Address]?
        pub let price: UFix64
        pub var maxMintsPerUser: UInt64

        init(priceType: String, eligibleAddresses: [Address]?, price: UFix64, maxMintsPerUser: UInt64?){
            self.priceType = priceType
            self.eligibleAddresses = eligibleAddresses
            self.price = price
            self.maxMintsPerUser = maxMintsPerUser ?? 10
        }
    }

    pub struct Order {
        pub let entityID: UInt64
        pub let quantity: UInt64

        init(entityID: UInt64, quantity: UInt64){
            self.entityID = entityID
            self.quantity = quantity
        }
    }

    pub struct PurchaseData {
        pub let primarySaleID: UInt64
        pub let purchaserAddress: Address
        pub let purchaserCollectionRef: &{NonFungibleToken.Receiver}
        pub let orders: [Order]
        pub let priceType: String

        init(primarySaleID: UInt64, purchaserAddress: Address, purchaserCollectionRef: &{NonFungibleToken.Receiver}, orders: [Order], priceType: String){
            self.primarySaleID = primarySaleID
            self.purchaserAddress = purchaserAddress
            self.purchaserCollectionRef = purchaserCollectionRef
            self.orders = orders
            self.priceType = priceType
        }
    }
    
    pub struct PurchaseDataRandom {
        pub let primarySaleID: UInt64
        pub let purchaserAddress: Address
        pub let purchaserCollectionRef: &{NonFungibleToken.Receiver}
        pub let quantity: UInt64
        pub let priceType: String

        init(primarySaleID: UInt64, purchaserAddress: Address, purchaserCollectionRef: &{NonFungibleToken.Receiver}, quantity: UInt64, priceType: String){
            self.primarySaleID = primarySaleID
            self.purchaserAddress = purchaserAddress
            self.purchaserCollectionRef = purchaserCollectionRef
            self.quantity = quantity
            self.priceType = priceType
        }
    }

    pub enum PrimarySaleStatus: UInt8 {
        pub case PAUSED
        pub case OPEN
        pub case CLOSED
    }

    pub resource interface PrimarySalePublic {
        pub fun getSupply(pool: String?): UInt64
        pub fun getPrices(): {String: PriceData}
        pub fun getStatus(): String
        pub fun purchaseRandomNFTs(
            payment: @FungibleToken.Vault,
            data: PurchaseDataRandom,
            adminSignedPayload: AdminSignedPayload, 
            signature: String
        )
        pub fun purchaseNFTs(
            payment: @FungibleToken.Vault,
            data: PurchaseData,
            adminSignedPayload: AdminSignedPayload, 
            signature: String
        )
        pub fun claimTreasures(
            primarySaleID: UInt64,
            pool: String?,
            claimerAddress: Address,
            claimerCollectionRef: &{NonFungibleToken.Receiver},
            adminSignedPayload: AdminSignedPayload,
            signature: String
        )
        pub fun getNumMintedByUser(userAddress: Address, priceType: String): UInt64
        pub fun getNumMintedPerUser(): {String: {Address: UInt64}}
        pub fun getAllAvailableEntities(pool: String?): {UInt64: UInt64}
        pub fun getAvailableEntities(): {UInt64: UInt64}
        pub fun getPooledEntities(): {String: {UInt64: UInt64}}
        pub fun getLaunchDate(): String
        pub fun getEndDate(): String
        pub fun getPooled(): Bool
        pub fun getContractName(): String
        pub fun getContractAddress(): Address
        pub fun getID(): UInt64
        pub fun getSetID(): UInt64
    }

    pub resource PrimarySale: PrimarySalePublic {
        access(self) var primarySaleID: UInt64
        access(self) var contractName: String
        access(self) var contractAddress: Address
        access(self) var setID: UInt64
        access(self) var status: PrimarySaleStatus
        access(self) var prices: {String: PriceData}
        access(self) var availableEntities: {UInt64: UInt64}
        access(self) var pooledEntities: {String: {UInt64: UInt64}}
        access(self) var numMintedPerUser: {String: {Address: UInt64}}
        access(self) var launchDate: String
        access(self) var endDate: String
        access(self) var pooled: Bool

        access(self) let minterCap: Capability<&{IMinter}>
        access(self) var paymentReceiverCap: Capability<&{FungibleToken.Receiver}>

        init(
            contractName: String,
            contractAddress: Address,
            setID: UInt64,
            prices: {String: PriceData},
            minterCap: Capability<&{IMinter}>,
            paymentReceiverCap: Capability<&{FungibleToken.Receiver}>,
            launchDate: String, 
            endDate: String,
            pooled: Bool
        ) {
            self.contractName = contractName
            self.contractAddress = contractAddress
            self.setID = setID
            self.status = PrimarySaleStatus.PAUSED // primary sale is paused initially
            self.availableEntities = {}
            self.pooledEntities = {}
            self.prices = prices

            self.minterCap = minterCap
            self.paymentReceiverCap = paymentReceiverCap
            
            self.launchDate = launchDate
            self.endDate = endDate

            self.pooled = pooled

            self.primarySaleID = FlowversePrimarySale.nextPrimarySaleID
            let key = contractName.concat(contractAddress.toString().concat(setID.toString()))
            FlowversePrimarySale.primarySaleIDs[key] = self.primarySaleID
            
            self.numMintedPerUser = {}
            for priceType in prices.keys {
                self.numMintedPerUser.insert(key: priceType, {})
            }

            emit PrimarySaleCreated(
                primarySaleID: self.primarySaleID,
                contractName: contractName,
                contractAddress: contractAddress,
                setID: setID,
                prices: prices,
                launchDate: launchDate,
                endDate: endDate,
                pooled: pooled
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

        pub fun setPrice(priceData: PriceData) {
            self.prices[priceData.priceType] = priceData
            if !self.numMintedPerUser.containsKey(priceData.priceType) {
                self.numMintedPerUser.insert(key: priceData.priceType, {})
            }
            emit PriceSet(primarySaleID: self.primarySaleID, type: priceData.priceType, price: priceData.price, eligibleAddresses: priceData.eligibleAddresses, maxMintsPerUser: priceData.maxMintsPerUser)
        }

        pub fun getPrices(): {String: PriceData} {
            return self.prices
        }

        pub fun getSupply(pool: String?): UInt64 {
            var supply = UInt64(0)
            if self.pooled {
                for poolKey in self.pooledEntities.keys {
                    if pool == nil || pool == poolKey {
                        let pooledDict = self.pooledEntities[poolKey]!
                        for entityID in pooledDict.keys {
                            supply = supply + pooledDict[entityID]!
                        }
                    }
                }
            } else {
                for entityID in self.availableEntities.keys {
                    supply = supply + self.availableEntities[entityID]!
                }
            }
            return supply
        }

        pub fun getLaunchDate(): String {
            return self.launchDate
        }

        pub fun getEndDate(): String {
            return self.endDate
        }

        pub fun getPaymentReceiverAddress(): Address? {
            let receiver = self.paymentReceiverCap.borrow()!
            if receiver.owner != nil {
                return receiver.owner!.address
            }
            return nil
        }

        pub fun getPooled(): Bool {
            return self.pooled
        }

        pub fun getNumMintedPerUser(): {String: {Address: UInt64}} {
            return self.numMintedPerUser
        }

        pub fun getNumMintedByUser(userAddress: Address, priceType: String): UInt64 {
            assert(self.numMintedPerUser.containsKey(priceType), message: "invalid priceType")
            let numMintedDict = self.numMintedPerUser[priceType]!
            return numMintedDict[userAddress] ?? 0
        }
        
        pub fun getContractName(): String {
            return self.contractName
        }
        
        pub fun getContractAddress(): Address {
            return self.contractAddress
        }

        pub fun getID(): UInt64 {
            return self.primarySaleID
        }

        pub fun getSetID(): UInt64 {
            return self.setID
        }

        pub fun addEntity(entityID: UInt64, pool: String?, quantity: UInt64) {
            if self.pooled {
                assert(pool != nil, message: "must specify pool")
                let poolStr = pool!
                if !self.pooledEntities.containsKey(poolStr) {
                    self.pooledEntities.insert(key: poolStr, {})
                }
                self.pooledEntities[poolStr]!.insert(key: entityID, quantity)
                emit EntityAdded(primarySaleID: self.primarySaleID, entityID: entityID, pool: poolStr, quantity: quantity)
            } else {
                self.availableEntities[entityID] = quantity
                emit EntityAdded(primarySaleID: self.primarySaleID, entityID: entityID, pool: nil, quantity: quantity)
            }
        }

        pub fun removeEntity(entityID: UInt64, pool: String?) {
            if self.pooled {
                assert(pool != nil, message: "must specify pool")
                let poolStr = pool!
                if self.pooledEntities.containsKey(poolStr) {
                    let entity = self.pooledEntities[poolStr]!.remove(key: entityID)
                    if entity != nil {
                        emit EntityRemoved(primarySaleID: self.primarySaleID, entityID: entityID, pool: poolStr)
                    }
                }
            } else {
                let entity = self.availableEntities.remove(key: entityID)
                if entity != nil {
                    emit EntityRemoved(primarySaleID: self.primarySaleID, entityID: entityID, pool: nil)
                }
            }
        }

        pub fun addEntities(entityIDs: [UInt64], pool: String?) {
            for id in entityIDs {
                self.addEntity(entityID: id, pool: pool, quantity: 1)
            }
        }

        pub fun pause() {
            self.status = PrimarySaleStatus.PAUSED
            emit PrimarySaleStatusChanged(primarySaleID: self.primarySaleID, status: self.getStatus())
        }

        pub fun open() {
            pre {
                self.status != PrimarySaleStatus.OPEN : "Primary sale is already open"
                self.status != PrimarySaleStatus.CLOSED : "Cannot re-open primary sale that is closed"
            }

            self.status = PrimarySaleStatus.OPEN
            emit PrimarySaleStatusChanged(primarySaleID: self.primarySaleID, status: self.getStatus())
        }

        pub fun close() {
            self.status = PrimarySaleStatus.CLOSED
            emit PrimarySaleStatusChanged(primarySaleID: self.primarySaleID, status: self.getStatus())
        }

        access(self) fun verifyAdminSignedPayload(signedPayloadData: AdminSignedPayload, signature: String): Bool {
            // Gets the Crypto.KeyList and the public key of the collection's owner
            let keyList = Crypto.KeyList()
            let accountKey = self.owner!.keys.get(keyIndex: 0)!.publicKey
            
            let publicKey = PublicKey(
                publicKey: accountKey.publicKey,
                signatureAlgorithm: accountKey.signatureAlgorithm
            )

            return publicKey.verify(
                signature: signature.decodeHex(),
                signedData: signedPayloadData.toString().utf8,
                domainSeparationTag: "FLOW-V0.0-user",
                hashAlgorithm: HashAlgorithm.SHA3_256
            )
        }

        pub fun purchaseRandomNFTs(
            payment: @FungibleToken.Vault,
            data: PurchaseDataRandom,
            adminSignedPayload: AdminSignedPayload,
            signature: String
        ) {
            pre {
                self.primarySaleID == data.primarySaleID: "primarySaleID mismatch"
                self.status == PrimarySaleStatus.OPEN: "primary sale is not open"
                data.quantity > 0: "must purchase at least one NFT"
                self.minterCap.borrow() != nil: "cannot borrow minter"
                adminSignedPayload.expiration >= UInt64(getCurrentBlock().timestamp): "expired signature"
                self.verifyAdminSignedPayload(signedPayloadData: adminSignedPayload, signature: signature): "failed to validate signature for the primary sale purchase"
                self.contractName != "FlowverseTreasures": "cannot purchase a Flowverse Treasures NFT"
            }

            var pool: String? = nil
            if self.pooled {
                pool = data.priceType
            }
            
            let supply = self.getSupply(pool: pool)
            assert(data.quantity <= supply, message: "insufficient supply")

            let orders: [Order] = []
            var quantityNeeded = data.quantity
            var availableEntities = self.getAllAvailableEntities(pool: pool)!
            for entityID in availableEntities.keys {
                if quantityNeeded > 0 {
                    var quantityToAdd: UInt64 = availableEntities[entityID]!
                    if quantityToAdd > quantityNeeded {
                        quantityToAdd = quantityNeeded
                    }
                    orders.append(Order(entityID: entityID, quantity: quantityToAdd))
                    quantityNeeded = quantityNeeded - quantityToAdd
                } else {
                    break
                }
            }

            let purchaseData = PurchaseData(
                primarySaleID: data.primarySaleID,
                purchaserAddress: data.purchaserAddress,
                purchaserCollectionRef: data.purchaserCollectionRef,
                orders: orders,
                priceType: data.priceType
            )
            
            self.purchase(payment: <-payment, data: purchaseData)
        }

        pub fun purchaseNFTs(
            payment: @FungibleToken.Vault,
            data: PurchaseData,
            adminSignedPayload: AdminSignedPayload,
            signature: String
        ) {
            pre {
                self.primarySaleID == data.primarySaleID: "primarySaleID mismatch"
                self.status == PrimarySaleStatus.OPEN: "primary sale is not open"
                data.orders.length > 0: "must purchase at least one NFT"
                self.minterCap.borrow() != nil: "cannot borrow minter"
                adminSignedPayload.expiration >= UInt64(getCurrentBlock().timestamp): "expired signature"
                self.verifyAdminSignedPayload(signedPayloadData: adminSignedPayload, signature: signature): "failed to validate signature for the primary sale purchase"
                self.contractName != "FlowverseTreasures": "cannot purchase a Flowverse Treasures NFT"
            }
            
            self.purchase(payment: <-payment, data: data)
        }

        pub fun claimTreasures(
            primarySaleID: UInt64,
            pool: String?,
            claimerAddress: Address,
            claimerCollectionRef: &{NonFungibleToken.Receiver},
            adminSignedPayload: AdminSignedPayload,
            signature: String
        ) {
            pre {
                self.primarySaleID == primarySaleID: "primarySaleID mismatch"
                self.status == PrimarySaleStatus.OPEN: "primary sale is not open"
                self.minterCap.borrow() != nil: "cannot borrow minter"
                adminSignedPayload.expiration >= UInt64(getCurrentBlock().timestamp): "expired signature"
                self.verifyAdminSignedPayload(signedPayloadData: adminSignedPayload, signature: signature): "failed to validate signature for the primary sale purchase"
                self.contractName == "FlowverseTreasures": "primary sale must be for a Flowverse Treasure"
            }
            // Get available entity IDs
            let availableEntityIDs = self.getAllAvailableEntities(pool: pool)!.keys
            assert(availableEntityIDs.length > 0, message: "No available entities")

            // Check if claimer is eligible for treasure based on whether they own a Flowverse Pass
            let mysteryPassCollectionRef = getAccount(claimerAddress).getCapability(FlowversePass.CollectionPublicPath)
                .borrow<&{FlowversePass.CollectionPublic}>()
                ?? panic("FlowversePass Collection reference not found")
            var passIDs = mysteryPassCollectionRef.getIDs()
            let numPassesOwned = passIDs.length
            assert(numPassesOwned > 0, message: "ineligible for treasure claim as user does not own a Flowverse Pass")

            // If pool is sockholder, check if claimer owns a Flowverse Sock
            var sockIDs: [UInt64] = []
            var numSocksOwned = 0
            if pool == "sockholders" {
                let socksCollectionRef = getAccount(claimerAddress).getCapability(FlowverseSocks.CollectionPublicPath)
                    .borrow<&{FlowverseSocks.FlowverseSocksCollectionPublic}>()
                    ?? panic("FlowverseSocks Collection reference not found")
                sockIDs = socksCollectionRef.getIDs()
                numSocksOwned = sockIDs.length
                passIDs = []
                assert(numSocksOwned > 0, message: "ineligible for treasure claim in sockholder pool as user does not own a Flowverse Sock")
            }

            let priceType = pool ?? "public"

            // Gets the number of treasure NFTs minted by this user in the current pool
            let numMintedByUser = self.getNumMintedByUser(userAddress: claimerAddress, priceType: priceType)

            // Checks if the user has already claimed all their treasure NFTs
            var quantity = UInt64(numPassesOwned) - numMintedByUser
            if pool == "sockholders" {
                quantity = UInt64(numSocksOwned) - numMintedByUser
            }
            assert(quantity > 0, message: "User has already claimed all their treasure NFTs")

            let minter = self.minterCap.borrow()!
            var n: UInt64 = 0
            let claimedNFTIDs: [UInt64] = []
            while n < quantity {
                let randomIndex = unsafeRandom() % UInt64(availableEntityIDs.length)
                let entityID = availableEntityIDs[randomIndex]
                let nft <- minter.mint(entityID: entityID, minterAddress: claimerAddress)
                claimedNFTIDs.append(nft.id)
                claimerCollectionRef.deposit(token: <-nft)
                n = n + 1
            }
            emit ClaimedTreasures(primarySaleID: primarySaleID, nftIDs: claimedNFTIDs, passIDs: passIDs, sockIDs: sockIDs, claimerAddress: claimerAddress, pool: priceType)
            // Increments the number of NFTs minted by the user
            self.numMintedPerUser[priceType]!.insert(key: claimerAddress, numMintedByUser + quantity)
        }

        access(self) fun purchase(
            payment: @FungibleToken.Vault,
            data: PurchaseData,
        ) {
            pre {
                self.primarySaleID == data.primarySaleID: "primarySaleID mismatch"
                self.status == PrimarySaleStatus.OPEN: "primary sale is not open"
                data.orders.length > 0: "must purchase at least one NFT"
                self.minterCap.borrow() != nil: "cannot borrow minter"
            }
            
            let priceData = self.prices[data.priceType] ?? panic("Invalid price type")

            if priceData.eligibleAddresses != nil {
                // check if purchaser is in eligible address list
                if !priceData.eligibleAddresses!.contains(data.purchaserAddress) {
                     panic("Address is ineligible for purchase")
                }
            }

            if self.pooled {
                assert(self.pooledEntities.containsKey(data.priceType), message: "Pool does not exist for price type")
            }

            // Gets the number of NFTs minted by this user
            let numMintedByUser = self.getNumMintedByUser(userAddress: data.purchaserAddress, priceType: data.priceType)

            // check if purchaser does not exceed maxMintsPerUser limit
            var totalQuantity: UInt64 = 0
            for order in data.orders {
                totalQuantity = totalQuantity + order.quantity
            }
            assert(totalQuantity + UInt64(numMintedByUser) <= priceData.maxMintsPerUser, message: "maximum number of mints exceeded")

            assert(payment.balance == priceData.price * UFix64(totalQuantity), message: "payment vault does not contain requested price")

            var receiver = self.paymentReceiverCap.borrow()!
            
            // check if payment is in FUT (FlowUtilityCoin used by Dapper)
            if payment.isInstance(Type<@FlowUtilityToken.Vault>()) {
                let dapperFUTCapability = getAccount(0xe24e5bbd46e38be1).getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)!
                receiver = dapperFUTCapability.borrow()!
            }

            receiver.deposit(from: <- payment)

            let minter = self.minterCap.borrow()!
            var i: Int = 0
            while i < data.orders.length {
                let entityID = data.orders[i].entityID
                let quantity = data.orders[i].quantity
                if self.pooled {
                    let pooledDict = self.pooledEntities[data.priceType]!
                    assert(pooledDict.containsKey(entityID) && pooledDict[entityID]! >= quantity, message: "NFT is not available for purchase: ".concat(entityID.toString()))
                    if pooledDict[entityID]! > quantity {
                        self.pooledEntities[data.priceType]!.insert(key: entityID, pooledDict[entityID]! - quantity)
                    } else {
                        self.pooledEntities[data.priceType]!.remove(key: entityID)
                    }
                } else {
                    assert(self.availableEntities.containsKey(entityID) && self.availableEntities[entityID]! >= quantity, message: "NFT is not available for purchase: ".concat(entityID.toString()))
                    if self.availableEntities[entityID]! > quantity {
                        self.availableEntities[entityID] = self.availableEntities[entityID]! - quantity
                    } else {
                        self.availableEntities.remove(key: entityID)
                    }
                }
                var n: UInt64 = 0
                let purchasedNFTIds: [UInt64] = []
                while n < quantity {
                    let nft <- minter.mint(entityID: entityID, minterAddress: data.purchaserAddress)
                    purchasedNFTIds.append(nft.id)
                    data.purchaserCollectionRef.deposit(token: <-nft)
                    n = n + 1
                }
                i = i + 1
                emit PurchasedOrder(primarySaleID: self.primarySaleID, entityID: entityID, quantity: quantity, nftIDs: purchasedNFTIds, purchaserAddress: data.purchaserAddress, priceType: data.priceType, price: priceData.price)
            }
            // Increments the number of NFTs minted by the user
            self.numMintedPerUser[data.priceType]!.insert(key: data.purchaserAddress, numMintedByUser + totalQuantity)
        }
        
        pub fun getAllAvailableEntities(pool: String?): {UInt64: UInt64} {
            var availableEntities: {UInt64: UInt64} = {}
            if pool != nil {
                assert(self.pooledEntities.containsKey(pool!), message: "Pool does not exist")
                let pooledDict = self.pooledEntities[pool!]!
                for entityID in pooledDict.keys {
                    availableEntities[entityID] = pooledDict[entityID]!
                }
            } else {
                for entityID in self.availableEntities.keys {
                    availableEntities[entityID] = self.availableEntities[entityID]!
                }
            }
            return availableEntities
        }

        pub fun getAvailableEntities(): {UInt64: UInt64} {
            return self.availableEntities
        }

        pub fun getPooledEntities(): {String: {UInt64: UInt64}} {
            return self.pooledEntities
        }

        pub fun updateLaunchDate(date: String) {
            self.launchDate = date
            emit PrimarySaleDateUpdated(primarySaleID: self.primarySaleID, date: date, isLaunch: true)
        }

        pub fun updateEndDate(date: String) {
            self.endDate = date
            emit PrimarySaleDateUpdated(primarySaleID: self.primarySaleID, date: date, isLaunch: false)
        }

        pub fun updatePaymentReceiver(paymentReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            pre {
                paymentReceiverCap.borrow() != nil: "Could not borrow payment receiver capability"
            }
            self.paymentReceiverCap = paymentReceiverCap
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to create primary sales
    //
    pub resource Admin {
        pub fun createPrimarySale(
            contractName: String,
            contractAddress: Address,
            setID: UInt64,
            prices: {String: PriceData},
            minterCap: Capability<&{IMinter}>,
            paymentReceiverCap: Capability<&{FungibleToken.Receiver}>,
            launchDate: String,
            endDate: String,
            pooled: Bool
        ) {
            pre {
                minterCap.borrow() != nil: "Could not borrow minter capability"
                paymentReceiverCap.borrow() != nil: "Could not borrow payment receiver capability"
            }

            let key = contractName.concat(contractAddress.toString().concat(setID.toString()))
            assert(!FlowversePrimarySale.primarySaleIDs.containsKey(key), message: "Primary sale with contractName, contractAddress, setID already exists")

            var primarySale <- create PrimarySale(
                contractName: contractName,
                contractAddress: contractAddress,
                setID: setID,
                prices: prices,
                minterCap: minterCap,
                paymentReceiverCap: paymentReceiverCap,
                launchDate: launchDate,
                endDate: endDate,
                pooled: pooled
            )

            let primarySaleID = FlowversePrimarySale.nextPrimarySaleID

            FlowversePrimarySale.nextPrimarySaleID = FlowversePrimarySale.nextPrimarySaleID + UInt64(1)

            FlowversePrimarySale.primarySales[primarySaleID] <-! primarySale
        }

        pub fun getPrimarySale(primarySaleID: UInt64): &PrimarySale? {
            if FlowversePrimarySale.primarySales.containsKey(primarySaleID) {
                return (&FlowversePrimarySale.primarySales[primarySaleID] as &PrimarySale?)!
            }
            return nil
        }

        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }

    pub struct PrimarySaleData {
        pub let primarySaleID: UInt64
        pub let contractName: String
        pub let contractAddress: Address
        pub let setID: UInt64
        pub let supply: UInt64
        pub let prices: {String: FlowversePrimarySale.PriceData}
        pub let status: String
        pub let availableEntities: {UInt64: UInt64}
        pub let pooledEntities: {String: {UInt64: UInt64}}
        pub let launchDate: String
        pub let endDate: String
        pub let pooled: Bool
        pub let numMintedPerUser: {String: {Address: UInt64}}

        init(
            primarySaleID: UInt64,
            contractName: String,
            contractAddress: Address,
            setID: UInt64,
            supply: UInt64,
            prices: {String: FlowversePrimarySale.PriceData},
            status: String,
            availableEntities: {UInt64: UInt64},
            pooledEntities: {String: {UInt64: UInt64}},
            launchDate: String,
            endDate: String,
            pooled: Bool,
            numMintedPerUser: {String: {Address: UInt64}}
        ) {
            self.primarySaleID = primarySaleID
            self.contractName = contractName
            self.contractAddress = contractAddress
            self.setID = setID
            self.supply = supply
            self.prices = prices
            self.status = status
            self.availableEntities = availableEntities
            self.pooledEntities = pooledEntities
            self.launchDate = launchDate
            self.endDate = endDate
            self.pooled = pooled
            self.numMintedPerUser = numMintedPerUser
        }
    }

    pub fun getPrimarySaleData(primarySaleID: UInt64): PrimarySaleData {
        pre {
            FlowversePrimarySale.primarySales.containsKey(primarySaleID): "Primary sale does not exist"
        }
        let primarySale = (&FlowversePrimarySale.primarySales[primarySaleID] as &PrimarySale?)!
        return PrimarySaleData(
            primarySaleID: primarySale.getID(),
            contractName: primarySale.getContractName(),
            contractAddress: primarySale.getContractAddress(),
            setID: primarySale.getSetID(),
            supply: primarySale.getSupply(pool: nil),
            prices: primarySale.getPrices(),
            status: primarySale.getStatus(),
            availableEntities: primarySale.getAvailableEntities(),
            pooledEntities: primarySale.getPooledEntities(),
            launchDate: primarySale.getLaunchDate(),
            endDate: primarySale.getEndDate(),
            pooled: primarySale.getPooled(),
            numMintedPerUser: primarySale.getNumMintedPerUser()
        )
    }

    pub fun getPaymentReceiverAddress(primarySaleID: UInt64): Address? {
        pre {
            FlowversePrimarySale.primarySales.containsKey(primarySaleID): "Primary sale does not exist"
        }
        let primarySale = (&FlowversePrimarySale.primarySales[primarySaleID] as &PrimarySale?)!
        return primarySale.getPaymentReceiverAddress()
    }
    
    pub fun getPrice(primarySaleID: UInt64, type: String): UFix64 {
        pre {
            FlowversePrimarySale.primarySales.containsKey(primarySaleID): "Primary sale does not exist"
        }
        let primarySale = (&FlowversePrimarySale.primarySales[primarySaleID] as &PrimarySale?)!
        let prices = primarySale.getPrices()
        assert(prices.containsKey(type), message: "price type does not exist")
        return prices[type]!.price
    }

    pub fun purchaseRandomNFTs(
        payment: @FungibleToken.Vault,
        data: PurchaseDataRandom,
        adminSignedPayload: AdminSignedPayload,
        signature: String
    ) {
        pre {
            FlowversePrimarySale.primarySales.containsKey(data.primarySaleID): "Primary sale does not exist"
        }
        let primarySale = (&FlowversePrimarySale.primarySales[data.primarySaleID] as &PrimarySale?)!
        primarySale.purchaseRandomNFTs(payment: <-payment, data: data, adminSignedPayload: adminSignedPayload, signature: signature)
    }

    pub fun purchaseNFTs(
        payment: @FungibleToken.Vault,
        data: PurchaseData,
        adminSignedPayload: AdminSignedPayload,
        signature: String
    ) {
        pre {
            FlowversePrimarySale.primarySales.containsKey(data.primarySaleID): "Primary sale does not exist"
        }
        let primarySale = (&FlowversePrimarySale.primarySales[data.primarySaleID] as &PrimarySale?)!
        primarySale.purchaseNFTs(payment: <-payment, data: data, adminSignedPayload: adminSignedPayload, signature: signature)
    }

    pub fun claimTreasures(
            primarySaleID: UInt64,
            pool: String?,
            claimerAddress: Address,
            claimerCollectionRef: &{NonFungibleToken.Receiver},
            adminSignedPayload: AdminSignedPayload,
            signature: String
        ){
        pre {
            FlowversePrimarySale.primarySales.containsKey(primarySaleID): "Primary sale does not exist"
        }
        let primarySale = (&FlowversePrimarySale.primarySales[primarySaleID] as &PrimarySale?)!
        primarySale.claimTreasures(
            primarySaleID: primarySaleID,
            pool: pool,
            claimerAddress: claimerAddress,
            claimerCollectionRef: claimerCollectionRef,
            adminSignedPayload: adminSignedPayload,
            signature: signature
        )
    }

    pub fun getID(contractName: String, contractAddress: Address, setID: UInt64): UInt64 {
        let key = contractName.concat(contractAddress.toString().concat(setID.toString()))
        assert(FlowversePrimarySale.primarySaleIDs.containsKey(key), message: "primary sale does not exist")
        return FlowversePrimarySale.primarySaleIDs[key]!
    }

    init() {
        self.AdminStoragePath = /storage/FlowversePrimarySaleAdminStoragePath

        self.primarySales <- {}
        self.primarySaleIDs = {}

        self.nextPrimarySaleID = 1
        
        self.account.save<@Admin>(<- create Admin(), to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
