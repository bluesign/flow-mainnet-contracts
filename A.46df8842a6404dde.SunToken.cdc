import FungibleToken from 0xf233dcee88fe0abe

pub contract SunToken: FungibleToken {

    /// Total supply of sunTokens in existence
    pub var totalSupply: UFix64
    
    // Declare Path constants so paths do not have to be hardcoded
    // in transactions and scripts
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath
    pub let BalanceReceiverPublicPath: PublicPath
    pub let VestedReceiverPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let MinterStoragePath: StoragePath

    /// TokensInitialized
    ///
    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// TokensWithdrawn
    ///
    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// TokensDeposited
    ///
    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// TokensMinted
    ///
    /// The event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    /// TokensBurned
    ///
    /// The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    /// MinterCreated
    ///
    /// The event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    /// BurnerCreated
    ///
    /// The event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    /// VestedReceiver
    ///
    /// The interface that enforces the requirements for depositing and
    /// viewing vested sun tokens within a vault
    pub resource interface VestedReceiver {
        pub fun getVestedAmounts(): AnyStruct
        pub fun adminDeposit(from: @FungibleToken.Vault, isEarlyMember: Bool)
    }

    /// Vault
    ///
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, VestedReceiver {

        /// The total balance of this vault
        pub var balance: UFix64
        //Array of arrays
        //[[tokenAmount],[unlockDate timestamp],...]
        pub var shortTermLockedBalance: [[UFix64]]
        pub var longTermLockedBalance: [[UFix64]]

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
            self.shortTermLockedBalance = []
            self.longTermLockedBalance = []
        }

        /// getVestedAmounts
        ///
        /// Returns the Vault's vested token arrays within a struct
        pub fun getVestedAmounts(): AnyStruct {
            let amounts = {
                "shortTerm": self.shortTermLockedBalance,
                "longTerm": self.longTermLockedBalance
            }
            return amounts
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        ///
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        ///
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @SunToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        /// unlockVestedTokens
        ///
        /// Function that loops through the vault's shortTerm & longTerm vested
        /// tokens, checking if vested tokens have exceeded their lock time, and 
        /// adding them to the vault's balance. 
        pub fun unlockVestedTokens() {
            var i = 0
            while i < self.shortTermLockedBalance.length {
                let vested = self.shortTermLockedBalance[i]
                
                if (vested[1] < getCurrentBlock().timestamp) {
                    self.balance = self.balance + vested[0]
                    self.shortTermLockedBalance.remove(at: i)
                }

                i = i+1
            }

            i = 0

            while i < self.longTermLockedBalance.length {
                let vested = self.longTermLockedBalance[i]
                
                if (vested[1] < getCurrentBlock().timestamp) {
                    self.balance = self.balance + vested[0]
                    self.longTermLockedBalance.remove(at: i)
                }

                i = i+1
            }
        }

        /// adminDeposit
        ///
        /// Function that deposits tokens into a user's vault, locking
        /// 2/3 of the tokens into a vested locked state.
        ///
        /// isEarlyMember bool to determine if the vault owner is
        /// an early member
        pub fun adminDeposit(from: @FungibleToken.Vault, isEarlyMember: Bool) {
            let vault <- from as! @SunToken.Vault
            var tokenSplit = vault.balance / 3.0
            //3 months(seconds)
            var shortTermSeconds: UFix64 = 7889238.0
            //6 months(seconds)
            var longTermSeconds: UFix64 = 15778462.0

            if (!isEarlyMember) {
                self.balance = self.balance + tokenSplit
                self.shortTermLockedBalance.append([tokenSplit, getCurrentBlock().timestamp+shortTermSeconds])
                self.longTermLockedBalance.append([tokenSplit, getCurrentBlock().timestamp+longTermSeconds])
            } else {
                tokenSplit = vault.balance / 2.0
                //12 months(seconds)
                shortTermSeconds = 31556925.0
                //24 months(seconds)
                longTermSeconds = 63113904.0
                self.shortTermLockedBalance.append([tokenSplit, getCurrentBlock().timestamp+shortTermSeconds])
                self.longTermLockedBalance.append([tokenSplit, getCurrentBlock().timestamp+longTermSeconds])
            }
            
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            SunToken.totalSupply = SunToken.totalSupply - self.balance
        }
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    /// Administrator
    ///
    /// Oversees the creation of Minter and Burner resources
    ///
    pub resource Administrator {

        /// createNewMinter
        ///
        /// Function that creates and returns a new minter resource
        /// Remove after token planning is complete
        pub fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }

        /// createNewBurner
        ///
        /// Function that creates and returns a new burner resource
        ///
        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }
    }

    /// Minter
    ///
    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    pub resource Minter {

        /// The amount of tokens that the minter is allowed to mint
        pub var allowedAmount: UFix64

        /// mintTokens
        ///
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// All existing sun tokens may be minted on initialization, rendering this function useless
        pub fun mintTokens(amount: UFix64): @SunToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            SunToken.totalSupply = SunToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    /// Burner
    ///
    /// Resource object that token admin accounts can hold to burn tokens.
    /// Do we actually need a Burner?
    pub resource Burner {
        /// burnTokens
        ///
        /// Function that destroys a Vault instance, effectively burning the tokens.
        ///
        /// Note: the burned tokens are automatically subtracted from the
        /// total supply in the Vault destructor.
        ///
        pub fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @SunToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        /// What will our initial supply be?
        /// Should be immediately transferred to rewards account
        self.totalSupply = 250000000.0

        //Set Path variables
        self.VaultStoragePath = /storage/sunTokenVault
        self.VaultPublicPath = /public/sunTokenVault
        self.ReceiverPublicPath = /public/sunTokenReceiver
        self.BalanceReceiverPublicPath = /public/sunTokenBalance
        self.VestedReceiverPublicPath = /public/sunTokenVestedBalance
        self.AdminStoragePath = /storage/sunTokenAdmin
        self.MinterStoragePath = /storage/sunTokenMinter

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&{FungibleToken.Receiver}>(
            self.VestedReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the VestedReceiver methods through the `Receiver` interface
        //
        self.account.link<&{SunToken.VestedReceiver}>(
            self.VestedReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&SunToken.Vault{FungibleToken.Balance}>(
            self.BalanceReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create and Admin resource and save it to storage
        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized
        //
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}