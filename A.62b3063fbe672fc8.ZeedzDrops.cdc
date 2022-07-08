import FungibleToken from 0xf233dcee88fe0abe

pub contract ZeedzDrops {

    // Events 
    
    pub event ProductPurchased(productID: UInt64, details: ProductDetails, currency: String, userID: String)
    pub event ProductAdded(productID: UInt64, details: ProductDetails)
    pub event ProductRemoved(productID: UInt64)
    pub event ProductUpdated(productID: UInt64, details: ProductDetails, field: String)

    // Paths

    pub let ZeedzDropsStoragePath: StoragePath

    // {Type of the FungibleToken => array of SaleCutRequirements}
    access(contract) var saleCutRequirements: {String : [SaleCutRequirement]}

    // {Product.uuid => Product}
    access(contract) var products: @{UInt64: Product}

    //
    // Used to defined sale cuts for each product sold via this contract.
    // Contains a FungibleToken reciever capability for the sale cut recieving address and a ratio which defines the percentage of the sale cut.
    //
    pub struct SaleCutRequirement {
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        pub let ratio: UFix64

        init(receiver: Capability<&{FungibleToken.Receiver}>, ratio: UFix64) {
            pre {
                ratio <= 1.0: "ratio must be less than or equal to 1.0"
                receiver.borrow() != nil: "invalid reciever capability"
            }
            self.receiver = receiver
            self.ratio = ratio
        }
    }

    //
    // A struct used to define the details of a Product
    //
    pub struct ProductDetails {
        // product name
        pub let name: String

        // description
        pub let description: String

        // product id
        pub let id: String

        // total product item quantity
        pub let total: UInt64

        // {Type of the FungibleToken => price}
        access(contract) var prices: {String : UFix64}

        // total products sold
        pub var sold: UInt64

        // total products reserved
        pub var reserved: UInt64

        // if true, the product is buyable
        pub var saleEnabled: Bool

        // product sale start timestamp
        pub var timeStart: UFix64

        // product sale start timestamp
        pub var timeEnd: UFix64

        init (
            name: String,
            description: String,
            id: String,
            total: UInt64,
            saleEnabled: Bool,
            timeStart: UFix64,
            timeEnd: UFix64,
            prices: {String: UFix64},
        ) {
            self.name = name
            self.description = description
            self.id = id
            self.total = total
            self.sold = 0
            self.reserved = 0
            self.timeStart = timeStart
            self.timeEnd = timeEnd
            self.prices = prices
            self.saleEnabled = saleEnabled
        }

        access(contract) fun setSaleEnabledStatus(status: Bool) {
            self.saleEnabled = status
        }

        access(contract) fun setStartTime(startTime: UFix64) {
            assert(self.timeEnd > startTime, message: "startTime should be lesser than endTime")
            self.timeStart = startTime
        }

        access(contract) fun setEndTime(endTime: UFix64) {
            assert(endTime > self.timeStart, message: "endTime should be grater than startTime")
            self.timeEnd = endTime
        }

        access(contract) fun setSoldAfterPurchase() {
            self.sold = self.sold + 1
        }

        access(contract) fun reserve(amount: UInt64) {
            self.sold = self.sold + amount
            self.reserved = self.reserved + amount
        }

        access(contract) fun setPrices(prices: {String : UFix64}) {
            self.prices = prices
        }

        pub fun getPrices(): {String : UFix64} {
            return self.prices
        }
    }

    //   
    // An interface providing the details function to a Product
    //
    pub resource interface ProductPublic {
        pub fun getDetails(): ProductDetails
    }


    //   
    // An interface used by the ZeedzDrops Contract Administrator to manage various Product fields.
    //
    pub resource interface ProductsManager {
        pub fun setSaleEnabledStatus(productID: UInt64, status: Bool)
        pub fun setStartTime(productID: UInt64, startTime: UFix64)
        pub fun setEndTime(productID: UInt64, endTime: UFix64)
        pub fun reserve(productID: UInt64, amount: UInt64)
        pub fun removeProduct(productID: UInt64)
        pub fun purchase(productID: UInt64, payment: @FungibleToken.Vault, vaultType: Type, userID: String)
        pub fun purchaseWithDiscount(
            productID: UInt64,
            payment: @FungibleToken.Vault,
            discount: UFix64,
            vaultType: Type,
            userID: String)
        pub fun addProduct(
            name: String,
            description: String,
            id: String,
            total: UInt64,
            saleEnabled: Bool,
            timeStart: UFix64,
            timeEnd: UFix64,
            prices: {String : UFix64}): UInt64
        pub fun setPrices(productID: UInt64, prices: {String : UFix64})
    }

    //   
    // An interface used by the ZeedzDrops Contract Administrator to manage the Drops Contract fields
    //
    pub resource interface DropsManager {
        pub fun updateSaleCutRequirement(requirements: [SaleCutRequirement], vaultType: Type)
    }

    //   
    // A resource which represents a product available for purchase on chain. The purchase methods are protected
    // by the administrator interface in order to prevent bot attacks.
    //
    pub resource Product: ProductPublic {

        access(contract) let details: ProductDetails

        pub fun getDetails(): ProductDetails {
            return self.details
        }

        //
        // Used to purchase a product on chain, a payment in the form of a FungibleToken.Vault has to be supplied 
        // to this function, along with the vault type and the Zeedz user cognitoID. If all the checks are passed and
        // after the purchase is complete, our backend will process the ProductPurchased event 
        // and assign the purchased product to the specified Zeedz cognito userID.
        //
        access(contract) fun purchase(payment: @FungibleToken.Vault, vaultType: Type, userID: String) {
            pre {
                self.details.saleEnabled == true: "the sale of this product is disabled"
                (self.details.total - self.details.sold) > 0: "these products are sold out"
                payment.isInstance(vaultType): "payment vault is not requested fungible token type"
                payment.balance == self.details.prices[vaultType.identifier]: "payment vault does not contain requested price"
                getCurrentBlock().timestamp > self.details.timeStart: "the sale of this product has not started yet"
                getCurrentBlock().timestamp < self.details.timeEnd: "the sale of this product has ended"
                ZeedzDrops.saleCutRequirements[vaultType.identifier] != nil: "sale cuts not set for requested fungible token"
            }

            var residualReceiver: &{FungibleToken.Receiver}? = nil

            for cut in ZeedzDrops.saleCutRequirements[vaultType.identifier]! {
                if let receiver = cut.receiver.borrow() {
                   let paymentCut <- payment.withdraw(amount: cut.ratio * self.details.prices[vaultType.identifier]!)
                    receiver.deposit(from: <-paymentCut)
                    if (residualReceiver == nil) {
                        residualReceiver = receiver
                    }
                }
            }

            assert(residualReceiver != nil, message: "no valid payment receivers")

            residualReceiver!.deposit(from: <-payment)

            self.details.setSoldAfterPurchase()

            emit ProductPurchased(productID: self.uuid, details: self.details, currency: vaultType.identifier, userID: userID)
        }

        //
        // Used to purchase a product on chain with a discount, uses the same logic as the purchase method, along 
        // with a discout modifier. Protected by the admin interface in order to check the validity of the supplied discount vaule.
        //
        access(contract) fun purchaseWithDiscount(payment: @FungibleToken.Vault, discount: UFix64, productID: UInt64, vaultType: Type, userID: String) {
             pre {
                discount < 1.0: "discount cannot be higher than 100%"
                self.details.saleEnabled == true: "the sale of this product is disabled"
                (self.details.total - self.details.sold) > 0: "these products are sold out"
                payment.isInstance(vaultType): "payment vault is not requested fungible token type"
                (payment.balance) == self.details.prices[vaultType.identifier]!*(1.0-discount): "payment vault does not contain requested price"
                getCurrentBlock().timestamp > self.details.timeStart: "the sale of this product has not started yet"
                getCurrentBlock().timestamp < self.details.timeEnd: "the sale of this product has ended"
                ZeedzDrops.saleCutRequirements[vaultType.identifier] != nil: "sale cuts not set for requested fungible token"
            }

            var residualReceiver: &{FungibleToken.Receiver}? = nil

            for cut in ZeedzDrops.saleCutRequirements[vaultType.identifier]! {
                if let receiver = cut.receiver.borrow() {
                   let paymentCut <- payment.withdraw(amount: cut.ratio * self.details.prices[vaultType.identifier]!*(1.0-discount))
                    receiver.deposit(from: <-paymentCut)
                    if (residualReceiver == nil) {
                        residualReceiver = receiver
                    }
                }
            }

            assert(residualReceiver != nil, message: "no valid payment receivers")

            residualReceiver!.deposit(from: <-payment)

            self.details.setSoldAfterPurchase()

            emit ProductPurchased(productID: self.uuid, details: self.details, currency: vaultType.identifier, userID: userID)
        }

        destroy () {
            emit ProductRemoved(
                productID: self.uuid,
            )
        }

        init (
            name: String,
            description: String,
            id: String,
            total: UInt64,
            saleEnabled: Bool,
            timeStart: UFix64,
            timeEnd: UFix64,
            prices: {String : UFix64}
            ) {
            self.details = ProductDetails(
                name: name,
                description: description,
                id: id,
                total: total,
                saleEnabled: saleEnabled,
                timeStart: timeStart,
                timeEnd: timeEnd,
                prices: prices
                )
        }
    }

    //
    // This resource is owned by the ZeedzDrops Administrator and it has acess to all the functions that are needed
    // to modify the available products on chain.
    //
    pub resource DropsAdmin: ProductsManager, DropsManager {
        pub fun addProduct(
            name: String,
            description: String,
            id: String,
            total: UInt64,
            saleEnabled: Bool,
            timeStart: UFix64,
            timeEnd: UFix64,
            prices: {String : UFix64}
            ): UInt64 {
            let product <- create Product(
                        name: name,
                        description: description,
                        id: id,
                        total: total,
                        saleEnabled: saleEnabled,
                        timeStart: timeStart,
                        timeEnd: timeEnd,
                        prices: prices)

            let productID = product.uuid

            let details = product.getDetails()

            let oldProduct <- ZeedzDrops.products[productID] <- product
            // Note that oldProduct will always be nil, but we have to handle it.
            destroy oldProduct

            emit ProductAdded(
                productID: productID,
                details: details
            )

            return productID
        }

        pub fun reserve(productID: UInt64, amount: UInt64) {
            let product = ZeedzDrops.borrowProduct(id: productID) ?? panic("not able to borrow specified product")
            assert(product.details.total - product.details.sold >= amount, message: "reserve amount can't be higher than available pack amount")
            product.details.reserve(amount: amount)
            emit ProductUpdated(productID: productID, details: product.getDetails(), field: "reserved")

        }
        pub fun removeProduct(productID: UInt64) {
            pre {
                ZeedzDrops.products[productID] != nil: "could not find product with given id"
            }
            let product <- ZeedzDrops.products.remove(key: productID)!
            destroy product
        }

        pub fun setSaleEnabledStatus(productID: UInt64, status: Bool) {
            let product = ZeedzDrops.borrowProduct(id: productID) ?? panic("not able to borrow specified product")
            product.details.setSaleEnabledStatus(status: status)
            emit ProductUpdated(productID: productID, details: product.getDetails(), field: "saleEnabled")
        }

        pub fun setStartTime(productID: UInt64, startTime: UFix64,) {
            let product = ZeedzDrops.borrowProduct(id :productID) ?? panic("not able to borrow specified product")
            product.details.setStartTime(startTime: startTime)
            emit ProductUpdated(productID: productID, details: product.getDetails(), field: "startTime")
        }

        pub fun setEndTime(productID: UInt64, endTime: UFix64) {
            let product = ZeedzDrops.borrowProduct(id :productID) ?? panic("not able to borrow specified product")
            product.details.setEndTime(endTime: endTime)
            emit ProductUpdated(productID: productID, details: product.getDetails(), field: "endTime")
        }

        pub fun purchase(productID: UInt64, payment: @FungibleToken.Vault, vaultType: Type, userID: String) {
            let product = ZeedzDrops.borrowProduct(id: productID) ?? panic("not able to borrow specified product")
            product.purchase(payment: <- payment, vaultType: vaultType, userID: userID)
        }

        pub fun purchaseWithDiscount(productID: UInt64, payment: @FungibleToken.Vault, discount: UFix64, vaultType: Type, userID: String) {
            let product = ZeedzDrops.borrowProduct(id: productID) ?? panic("not able to borrow specified product")
            product.purchaseWithDiscount(payment: <- payment, discount: discount, productID: productID, vaultType: vaultType, userID: userID)
        }

        pub fun updateSaleCutRequirement(requirements: [SaleCutRequirement], vaultType: Type) {
            var totalRatio: UFix64 = 0.0
            for requirement in requirements {
                totalRatio = totalRatio + requirement.ratio
            }
            assert(totalRatio <= 1.0, message: "total ratio must be less than or equal to 1.0")
            ZeedzDrops.saleCutRequirements[vaultType.identifier] = requirements
        }

        pub fun setPrices(productID: UInt64, prices: {String : UFix64}) {
            let product = ZeedzDrops.borrowProduct(id: productID) ?? panic("not able to borrow specified product")
            product.details.setPrices(prices: prices)
            emit ProductUpdated(productID: productID, details: product.getDetails(), field: "prices")
        }
    }

    //
    // Returns the current sale cut requirements
    //
    pub fun getAllSaleCutRequirements(): {String: [SaleCutRequirement]} {
        return self.saleCutRequirements
    }

    //
    // Returns all of the current product ids
    //
    pub fun getAllProductIDs(): [UInt64]? {
      return self.products.keys
    }

    //
    // Returns a reference to a product which can be used to access the product's details
    //
    pub fun borrowProduct(id: UInt64): &ZeedzDrops.Product? {
        return (&self.products[id] as &ZeedzDrops.Product?)!
    }

    init () {
        self.ZeedzDropsStoragePath = /storage/ZeedzDrops

        self.saleCutRequirements = {}
        self.products <- {}

        let admin <- create DropsAdmin()
        self.account.save(<-admin, to: self.ZeedzDropsStoragePath)
    }
}