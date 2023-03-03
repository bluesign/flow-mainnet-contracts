import FungibleToken from 0xf233dcee88fe0abe;

pub contract YDYToken: FungibleToken {

    pub var totalSupply: UFix64

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // Events
    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)
    pub event TokensMinted(amount: UFix64)
    pub event TokensBurned(amount: UFix64)
    pub event MinterCreated()
    pub event BurnerCreated()

    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {
        pub var balance: UFix64

        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @YDYToken.Vault
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            self.balance = self.balance + vault.balance

            vault.balance = 0.0
            destroy vault
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <- create Vault(balance: amount)
        }

        init(balance: UFix64) {
            self.balance = balance
        }
        
        // When tokens get burned
        destroy() {
            if self.balance > 0.0 {
                YDYToken.totalSupply = YDYToken.totalSupply - self.balance
                emit TokensBurned(amount: self.balance)
            }
        }
    }

    pub fun createEmptyVault(): @FungibleToken.Vault {
        return <- create Vault(balance: 0.0)
    }

    pub resource Administrator {
        pub fun createNewMinter(): @Minter {
            emit MinterCreated()
            return <-create Minter()
        }
    }

    pub resource Minter {
        pub fun mintToken(amount: UFix64): @FungibleToken.Vault {
            pre {
                YDYToken.totalSupply + amount <= 1000000000.0 : "Adding this amount causes YDY tokens to go over max supply of 1 billion"
            }
            
            YDYToken.totalSupply = YDYToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            
            return <- create Vault(balance: amount)
        }

        init() {

        }
    }

    pub resource Burner {
        init() {

        }
    }

    init() {
        self.totalSupply = 0.0

        self.VaultStoragePath = /storage/YDYTokenVault
        self.ReceiverPublicPath = /public/YDYTokenReceiver
        self.BalancePublicPath = /public/YDYTokenBalance
        self.AdminStoragePath = /storage/YDYTokenAdmin

        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
    }

}