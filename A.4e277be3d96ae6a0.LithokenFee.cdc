// Fee manager

pub contract LithokenFee {

    pub let commonFeeManagerStoragePath: StoragePath

    pub event SellerFeeChanged(value: UFix64)
    pub event BuyerFeeChanged(value: UFix64)
    pub event FeeAddressUpdated(label: String, address: Address)

    access(self) var feeAddresses: {String:Address}

    
    pub var sellerFee: UFix64

    
    pub var buyerFee: UFix64

    pub resource Manager {
        pub fun setSellerFee(_ fee: UFix64) {
            LithokenFee.sellerFee = fee
            emit SellerFeeChanged(value: LithokenFee.sellerFee)
        }

        pub fun setBuyerFee(_ fee: UFix64) {
            LithokenFee.buyerFee = fee
            emit BuyerFeeChanged(value: LithokenFee.buyerFee)
        }

        pub fun setFeeAddress(_ label: String, address: Address) {
            LithokenFee.feeAddresses[label] = address
            emit FeeAddressUpdated(label: label, address: address)
        }
    }

    init() {
        self.sellerFee = 0.05
        emit SellerFeeChanged(value: LithokenFee.sellerFee)
        self.buyerFee = 0.05
        emit BuyerFeeChanged(value: LithokenFee.buyerFee)

        self.feeAddresses = {}

        self.commonFeeManagerStoragePath = /storage/commonFeeManager
        self.account.save(<- create Manager(), to: self.commonFeeManagerStoragePath)
    }

    pub fun feeAddress(): Address {
        return self.feeAddresses["lithoken"] ?? self.account.address
    }

    pub fun feeAddressByName(_ label: String): Address {
        return self.feeAddresses[label] ?? self.account.address
    }

    pub fun addressMap(): {String:Address} {
        return LithokenFee.feeAddresses
    }
}
