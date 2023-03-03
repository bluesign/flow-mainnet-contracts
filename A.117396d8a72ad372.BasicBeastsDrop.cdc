import FungibleToken from 0xf233dcee88fe0abe

pub contract BasicBeastsDrop {

    pub event ContractInitialized()

    pub let AdminStoragePath: StoragePath

    pub var currentDrop: UInt32
    access(self) var drops: {UInt32: [Drop]}

    pub struct Drop {
        pub let order: UInt32
        pub let drop: UInt32
        pub let amount: UFix64
        pub let totalPurchase: UFix64
        pub let vaultAddress: Address
        pub let type: String
        pub let address: Address


        init(order: UInt32, amount: UFix64, totalPurchase: UFix64, vaultAddress: Address, type: String, address: Address) {
            self.order = order
            self.drop = BasicBeastsDrop.currentDrop
            self.amount = amount
            self.totalPurchase = totalPurchase
            self.vaultAddress = vaultAddress
            self.type = type
            self.address = address
        }
    }

    pub resource Admin {

        pub fun startNewDrop() {
            BasicBeastsDrop.currentDrop = BasicBeastsDrop.currentDrop + 1
        }

    }

    pub fun participate(amount: UFix64, vaultAddress: Address, type: String, vault: @FungibleToken.Vault, address: Address) {
        var quantity = 0
        var amountForPack: UFix64 = 0.0
        switch type {
            case "Starter":
            quantity = Int(amount/10.0)
            amountForPack = 10.0
            case "Cursed Black":
            quantity = Int(amount/300.0)
            amountForPack = 300.0
            case "Shiny Gold":
            quantity = Int(amount/999.0)
            amountForPack = 999.0
        }

        if(BasicBeastsDrop.drops[BasicBeastsDrop.currentDrop] == nil) {
            BasicBeastsDrop.drops[BasicBeastsDrop.currentDrop] = []
        }

        var i = 0

        while(quantity>i) {
            BasicBeastsDrop.drops[BasicBeastsDrop.currentDrop]!.append(
                Drop(
                    order: UInt32(BasicBeastsDrop.drops[BasicBeastsDrop.currentDrop]!.length + 1), 
                    amount: amountForPack, 
                    totalPurchase: amount,
                    vaultAddress: vaultAddress, 
                    type: type, 
                    address: address
                    )
                )
            i = i + 1
        }

        getAccount(vaultAddress).getCapability(/public/fusdReceiver)!.borrow<&{FungibleToken.Receiver}>()!.deposit(from: <-vault)
        
    }

    pub fun getDrops(): [UInt32] {
        return BasicBeastsDrop.drops.keys
    }

    pub fun getDropData(drop: UInt32): [Drop]? {
        return BasicBeastsDrop.drops[drop]
    }

    init() {
        self.AdminStoragePath = /storage/basicBeastsDropAdmin

        self.currentDrop = 12
        self.drops = {}

        // Create a Admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}