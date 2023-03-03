import FungibleToken from 0xf233dcee88fe0abe

pub contract SilverlightCoin: FungibleToken {

    // Total supply of Flow tokens in existence
    pub var totalSupply: UFix64

    // Storage Paths
    pub let SilverlightCoinStoragePath: StoragePath
    pub let SilverlightCoinBalancePublicPath: PublicPath
    pub let SilverlightCoinReceiverPublicPath: PublicPath 

    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    // Event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    // Event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    // Event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    // Event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in FungibleToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        // holds the balance of a users tokens
        pub var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @SilverlightCoin.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            SilverlightCoin.totalSupply = SilverlightCoin.totalSupply - self.balance
        }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @FungibleToken.Vault {
        return <-create Vault(balance: 0.0)
    }

    init() {
        self.totalSupply = 5_000_000_000.0 // 5 Billion SLVC

        // init storage paths
        self.SilverlightCoinStoragePath = /storage/SilverlightCoinVault
        self.SilverlightCoinBalancePublicPath = /public/SilverlightCoinBalance
        self.SilverlightCoinReceiverPublicPath = /public/SilverlightCoinReceiver

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: SilverlightCoin.SilverlightCoinStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&SilverlightCoin.Vault{FungibleToken.Receiver}>(
            SilverlightCoin.SilverlightCoinReceiverPublicPath,
            target: SilverlightCoin.SilverlightCoinStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&SilverlightCoin.Vault{FungibleToken.Balance}>(
            SilverlightCoin.SilverlightCoinBalancePublicPath,
            target: SilverlightCoin.SilverlightCoinStoragePath
        )

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}