// Fee manager

pub contract GrandmallworldFee {

    pub let commonFeeManagerStoragePath: StoragePath

    pub event SellerFeeChanged(value: UFix64)
    pub event BuyerFeeChanged(value: UFix64)
    pub event FeeAddressUpdated(label: String, address: Address)

    access(self) var feeAddresses: {String:Address}

    
    pub var sellerFee: UFix64

    
    pub var buyerFee: UFix64

    pub resource Manager {
        pub fun setSellerFee(_ fee: UFix64) {
            GrandmallworldFee.sellerFee = fee
            emit SellerFeeChanged(value: GrandmallworldFee.sellerFee)
        }

        pub fun setBuyerFee(_ fee: UFix64) {
            GrandmallworldFee.buyerFee = fee
            emit BuyerFeeChanged(value: GrandmallworldFee.buyerFee)
        }

        pub fun setFeeAddress(_ label: String, address: Address) {
            GrandmallworldFee.feeAddresses[label] = address
            emit FeeAddressUpdated(label: label, address: address)
        }
    }

    init() {
        self.sellerFee = 0.05
        emit SellerFeeChanged(value: GrandmallworldFee.sellerFee)
        self.buyerFee = 0.05
        emit BuyerFeeChanged(value: GrandmallworldFee.buyerFee)

        self.feeAddresses = {}

        self.commonFeeManagerStoragePath = /storage/commonFeeManager
        self.account.save(<- create Manager(), to: self.commonFeeManagerStoragePath)
    }

    pub fun feeAddress(): Address {
        return self.feeAddresses["grandmallworld"] ?? self.account.address
    }

    pub fun feeAddressByName(_ label: String): Address {
        return self.feeAddresses[label] ?? self.account.address
    }

    pub fun addressMap(): {String:Address} {
        return GrandmallworldFee.feeAddresses
    }
}
