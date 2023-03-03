// import FungibleToken from "./FungibleToken.cdc"
import FungibleToken from 0xf233dcee88fe0abe

pub contract TheToken: FungibleToken {

    // 属性
    pub var totalSupply: UFix64
    pub let max_totalSupply: UFix64
    pub var pairAddress: Address
    pub var burnAddress: Address
    pub var burnPer: UFix64
    pub let adminPath: StoragePath
    pub let minerPath: StoragePath
    pub let vaultPath: StoragePath
    pub let receiverPath: PublicPath
    pub let balancePath: PublicPath

    // 事件
    pub event TokensInitialized(initialSupply: UFix64)
    pub event PairAddressChanged(pair: Address)
    pub event BurnAddressChanged(pair: Address)
    pub event BurnPerChanged(per: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)
    pub event TokensMinted(amount: UFix64)
    pub event TokensBurned(amount: UFix64)
    pub event MinterCreated(allowedAmount: UFix64)
    pub event BurnerCreated()



    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        pub var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @TheToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            TheToken.totalSupply = TheToken.totalSupply - self.balance
        }
    }

    pub fun createEmptyVault(): @FungibleToken.Vault {
        return <-create Vault(balance: 0.0)
    }

    pub resource Administrator {

        pub fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }

        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }

        pub fun changePairAddress(pair: Address) {
            TheToken.pairAddress = pair
            emit PairAddressChanged(pair: pair)
        }

        pub fun changeBurnAddress(burn: Address) {
            TheToken.burnAddress = burn
            emit BurnAddressChanged(pair: burn)
        }

        pub fun changeBurnPer(per: UFix64) {
            TheToken.burnPer = per
            emit BurnPerChanged(per: per)
        }
    }

    pub resource Minter {

        pub var allowedAmount: UFix64

        pub fun mintTokens(amount: UFix64): @TheToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            post {
                TheToken.totalSupply <= TheToken.max_totalSupply: "TotalSupply must less than Max_totalSupply"
            }
            TheToken.totalSupply = TheToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return  <-create Vault(balance: amount)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    pub resource Burner {

        pub fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @TheToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        
        // 初始化一些属性
        self.totalSupply = 0.0
        self.max_totalSupply = 100.0
        self.adminPath = /storage/TheTokenAdmin
        self.minerPath = /storage/TheTokenMiner
        self.vaultPath = /storage/TheTokenVault
        self.receiverPath = /public/TheTokenReceiver
        self.balancePath = /public/TheTokenBalance
        self.pairAddress = self.account.address
        self.burnAddress = self.account.address
        self.burnPer = 0.01

        // 创建管理员
        let admin <- create Administrator()

        // 创建矿工
        let miner <- admin.createNewMinter(allowedAmount: self.max_totalSupply)

        // 把存款操作暴露给大家
        self.account.link<&TheToken.Vault{FungibleToken.Receiver}>(self.receiverPath, target: self.vaultPath)

        // 把余额暴露给大家
        self.account.link<&TheToken.Vault{FungibleToken.Balance}>(self.balancePath, target: self.vaultPath)
        
        self.account.save(<-admin, to: self.adminPath)
        self.account.save(<-miner, to: self.minerPath)

        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
