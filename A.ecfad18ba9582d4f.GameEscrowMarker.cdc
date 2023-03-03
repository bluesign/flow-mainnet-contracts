import FungibleToken from 0xf233dcee88fe0abe

pub contract GameEscrowMarker: FungibleToken {
    pub var totalSupply: UFix64
    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)

    pub let AdminStoragePath:StoragePath
    pub let AdminPrivatePath:PrivatePath

    access(contract) let GameEscrowVaults: {/*gameID*/String: {/*Token Identifier*/ String: Capability<&FungibleToken.Vault>}}

    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {
        pub var balance: UFix64
        access(contract) var tokenIdentifier: String?
        access(contract) var gameID: String?

        init(balance: UFix64) {
            self.balance = balance
            self.tokenIdentifier = nil
            self.gameID = nil
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            if(self.balance < amount) { panic("Not Enough Escrowed") }

            let copy <- create Vault(balance: amount)
            copy.tokenIdentifier = self.tokenIdentifier
            copy.gameID = self.gameID

            self.balance = self.balance-amount;
            copy.balance = amount

            return <- copy
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            let gameEscrowVault: @GameEscrowMarker.Vault <- from as! @GameEscrowMarker.Vault
            if(self.tokenIdentifier == nil) {
                self.tokenIdentifier = gameEscrowVault.tokenIdentifier
                self.gameID = gameEscrowVault.gameID
            } else if(self.tokenIdentifier != gameEscrowVault.tokenIdentifier || self.gameID != gameEscrowVault.gameID) {
                panic("Incompatible Vault")
            }
            self.balance = self.balance + gameEscrowVault.balance
            destroy gameEscrowVault
        }

        access(contract) fun getVault(): &FungibleToken.Vault {
            let gameCapabilities = GameEscrowMarker.GameEscrowVaults[self.gameID!] ?? panic("Not Initialized")
            let capability = gameCapabilities[self.tokenIdentifier!] ?? panic("No Compatible Vault Found")
            return capability.borrow() ?? panic("Invalid Capability")
        }

        pub fun depositToEscrowVault(gameID:String, vault:@FungibleToken.Vault) {
            if(self.tokenIdentifier == nil) {
                self.tokenIdentifier = vault.getType().identifier
                self.gameID = gameID
            } else if(self.tokenIdentifier != vault.getType().identifier || self.gameID != gameID) {
                panic("Incompatible Vault")
            }

            self.balance = self.balance + vault.balance
            self.getVault().deposit(from: <- vault)
        }

        pub fun withdrawFromEscrowVault(amount: UFix64): @FungibleToken.Vault {
            if(self.balance > amount) { panic("Not Enough") }
            self.balance = self.balance - amount
            return <- self.getVault().withdraw(amount: amount)
        }
    }

    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    pub resource GameEscrowAdmin {
        pub fun RegisterGameEscrowVault(gameID: String, capability: Capability<&FungibleToken.Vault>) {
            let gameCapabilities = GameEscrowMarker.GameEscrowVaults[gameID] ?? {}
            let vault = capability.borrow()!
            let tokenIdentifier = vault.getType().identifier;

            if(gameCapabilities.containsKey(tokenIdentifier)) {
                let reference = gameCapabilities[tokenIdentifier]!.borrow()
                if(reference != nil) {
                    vault.deposit(from: <- reference!.withdraw(amount: reference!.balance))
                }
            }

            gameCapabilities[tokenIdentifier] = capability
            GameEscrowMarker.GameEscrowVaults[gameID] = gameCapabilities;
        }
    }

    init() {
        self.totalSupply = 0.0
        self.GameEscrowVaults = {}
        self.AdminStoragePath = /storage/GameEscrowMarker
        self.AdminPrivatePath = /private/GameEscrowMarker

        let admin <- create GameEscrowAdmin()
        self.account.save(<- admin, to: self.AdminStoragePath)
        self.account.link<&GameEscrowAdmin>(self.AdminPrivatePath, target: self.AdminStoragePath)
    }
}