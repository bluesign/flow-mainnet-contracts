import MultiFungibleToken from 0x3620aa78dc6c5b54

/**

PierLPToken is the LP token contract for Metapier Wharf v1.
For each liquidity pool, we have one dedicated LP token, with
the `tokenId` of the LP token equals to the `poolId` of the pool.

@author Metapier Foundation Ltd.

 */
pub contract PierLPToken: MultiFungibleToken {

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    // Event that is emitted when tokens are minted
    pub event TokensMinted(tokenId: UInt64, amount: UFix64)

    // Event that is emitted when tokens are burned
    pub event TokensBurned(tokenId: UInt64, amount: UFix64)

    // Event that is emitted when tokens are withdrawn from a Vault of some token ID
    pub event TokensWithdrawn(tokenId: UInt64, amount: UFix64, from: Address?)

    // Event that is emitted when tokens are deposited into a Vault of some token ID
    pub event TokensDeposited(tokenId: UInt64, amount: UFix64, to: Address?)

    // Event that is emitted when a new TokenMaster resource is created
    pub event TokenMasterCreated(tokenId: UInt64)

    // The common storage path for storing a PierLPToken.Collection
    pub let CollectionStoragePath: StoragePath

    // The common public path for linking to the PierLPToken.Collection{MultiFungibleToken.CollectionPublic}
    pub let CollectionPublicPath: PublicPath

    // A mapping from token ID to the corresponding total supply
    access(contract) let totalSupply: {UInt64: UFix64}

    // PierLPToken Vault
    pub resource Vault: MultiFungibleToken.Receiver, MultiFungibleToken.View {

        // The total balance of the Vault
        pub var balance: UFix64

        // The liquidity pool id that the Vault corresponds to
        pub let tokenId: UInt64

        // Vault initializer
        //
        // @param tokenId The liquidity pool id that the Vault corresponds to
        // @param balance The initial balance of the Vault
        init(tokenId: UInt64, balance: UFix64) {
            self.tokenId = tokenId
            self.balance = balance
        }

        // Subtracts the amount of tokens from the owner's Vault
        // and returns a Vault with the subtracted balance.
        //
        // @param amount The amount of tokens to withdraw
        // @return A new Vault (of the same token id) that contains the requested amount of tokens
        pub fun withdraw(amount: UFix64): @PierLPToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(tokenId: self.tokenId, amount: amount, from: self.owner?.address)
            return <- create Vault(tokenId: self.tokenId, balance: amount)
        }

        // Takes a Vault of the same token id and adds its
        // balance to the balance of this Vault
        //
        // @param from A Vault that is ready to have its balance added to this Vault
        pub fun deposit(from: @MultiFungibleToken.Vault) {
            let vault <- from as! @Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(tokenId: self.tokenId, amount: vault.balance, to: self.owner?.address)
            // no need to reset the vault's balance because destroy() do not change the total supply
            destroy vault
        }

        destroy() {
            // Destroys a non-empty Vault will not affect the total supply but lock the balance forever instead
        }
    }

    // A collection to help with storing and organizing multiple LP tokens.
    pub resource Collection: 
        MultiFungibleToken.Provider, 
        MultiFungibleToken.Receiver, 
        MultiFungibleToken.CollectionPublic 
    {
        // A mapping from token id (pool id) to LP token Vault
        pub var vaults: @{UInt64: PierLPToken.Vault}

        // For a given token id, subtracts the amount of tokens from the corresponding Vault
        // in the collection and returns a Vault with the token id and the subtracted balance.
        //
        // Note: A new empty Vault will be created in the collection if the collection doesn't
        //  contain the requested LP token.
        //
        // @param tokenId The token id (pool id) of the Vault from which to withdraw
        // @param amount The amount of tokens to withdraw
        // @return A new Vault (of the same token id) that contains the requested amount of tokens
        pub fun withdraw(tokenId: UInt64, amount: UFix64): @PierLPToken.Vault {
            if !self.vaults.containsKey(tokenId) {
                self.vaults[tokenId] <-! PierLPToken.createEmptyVault(tokenId: tokenId)
            }

            let vault = (&self.vaults[tokenId] as &PierLPToken.Vault?)!
            return <- vault.withdraw(amount: amount)
        }

        // Adds the balance of the deposit Vault to the Vault with the same token id
        // in the collection.
        //
        // Note: A new Vault will be created in the collection if the collection doesn't
        //  contain the given LP token.
        //
        // @param from The LP token Vault to deposit into the collection
        pub fun deposit(from: @MultiFungibleToken.Vault) {
            if from.balance == 0.0 {
                // ignore zero-balance vaults to prevent spamming
                destroy from
                return
            }

            let tokenId = from.tokenId
            if !self.vaults.containsKey(tokenId) {
                self.vaults[tokenId] <-! PierLPToken.createEmptyVault(tokenId: tokenId)
            }

            let vault = (&self.vaults[tokenId] as &PierLPToken.Vault?)!
            vault.deposit(from: <- from)
        }

        // Gets the token ids of all vaults stored in the collection, including the
        // empty ones.
        //
        // @return An array of the token ids of all vaults stored in the collection.
        pub fun getTokenIds(): [UInt64] {
            return self.vaults.keys
        }

        // Checks if the internal `vaults` contains the requested LP token.
        // 
        // @return `true` iff the internal `vaults` contains a Vault of the
        //  requested token id ()
        pub fun hasToken(tokenId: UInt64): Bool {
            return self.vaults.containsKey(tokenId)
        }
 
        // Returns a restricted Vault of the requested token id for public access,
        // or throws an exception if it doesn't have a Vault of the requested token
        // id
        //
        // @param tokenId The token id (pool id) of the Vault to query
        // @return A Vault reference of the requested token id, which exposes only
        //  the Receiver and View
        pub fun getPublicVault(tokenId: UInt64):
            &PierLPToken.Vault{MultiFungibleToken.Receiver, MultiFungibleToken.View}
        {
            return (&self.vaults[tokenId] as &PierLPToken.Vault{MultiFungibleToken.Receiver, MultiFungibleToken.View}?)!
        }

        // Initializes the Collection
        init() {
            self.vaults <- {}
        }

        // Destroys the Collection and permanently locks all the stored LP tokens (if there are any) 
        destroy() {
            destroy self.vaults
        }
    }

    // TokenMaster is a resource to manage the LP token supply for
    // one specific liquidity pool
    pub resource TokenMaster {

        // The id of the LP token this TokenMaster can manage
        pub let tokenId: UInt64

        // Mints the given amount of LP tokens and returns a Vault
        // that stores the minted tokens.
        //
        // @param amount The amount of tokens to mint and return
        // @return A Vault that contains the requested amount of LP
        //  tokens (of the predefined token id)
        pub fun mintTokens(amount: UFix64): @PierLPToken.Vault {
            pre {
                amount > 0.0: "Metapier PierLPToken: Amount to mint must be greater than zero"
            }

            PierLPToken.totalSupply[self.tokenId] = PierLPToken.totalSupply[self.tokenId]! + amount
            emit TokensMinted(tokenId: self.tokenId, amount: amount)

            return <- create Vault(tokenId: self.tokenId, balance: amount)
        }

        // Burns the given LP token Vault by subtracting its balance
        // from the total supply.
        //
        // @param vault The LP token Vault to burn (must have the 
        //  expected token id)
        pub fun burnTokens(vault: @PierLPToken.Vault) {
            pre {
                self.tokenId == vault.tokenId: "Metapier PierLPToken: Cannot burn other LP tokens"
            }

            PierLPToken.totalSupply[self.tokenId] = PierLPToken.totalSupply[self.tokenId]! - vault.balance
            emit TokensBurned(tokenId: vault.tokenId, amount: vault.balance)

            destroy vault
        }

        // Initializes the TokenMaster for a specific LP token
        //
        // @param tokenId The id of the LP token this TokenMaster can manage
        init(tokenId: UInt64) {
            self.tokenId = tokenId
        }
    }

    // Admin is a resource for initializing new LP tokens
    pub resource Admin {

        // Initializes a new LP token and returns a TokenMaster for
        // managing its total supply. Will throw an error if the token
        // already exists.
        // 
        // @param tokenId The id of the new LP token
        // @return A TokenMaster for the new LP token (implied by 
        //  token id)
        pub fun initNewLPToken(tokenId: UInt64): @TokenMaster {
            pre {
                !PierLPToken.totalSupply.containsKey(tokenId): "Metapier PierLPToken: LP Token already exists"
            }
            // initializes the total supply entry
            PierLPToken.totalSupply[tokenId] = 0.0
            emit TokenMasterCreated(tokenId: tokenId)
            return <- create TokenMaster(tokenId: tokenId)
        }
    }

    // Creates an empty collection
    //
    // @return A new empty Collection
    pub fun createEmptyCollection(): @PierLPToken.Collection {
        return <- create Collection()
    }

    // Creates a new Vault of the requested token id that has a zero balance,
    // or throws an error if the requested token id has not yet been initialized
    //
    // @param tokenId The token id (pool id) the new Vault is associate with
    // @return A new empty Vault of the requested token id
    pub fun createEmptyVault(tokenId: UInt64): @PierLPToken.Vault {
        return <- create Vault(tokenId: tokenId, balance: 0.0)
    }

    // Gets the total supply of the requested token id, or nil if the token
    // id has not yet been initialized
    //
    // @param tokenId The token id (pool id) to query
    // @return The total supply of the requested token id, or nil if the
    //  token doesn't exist
    pub fun getTotalSupply(tokenId: UInt64): UFix64? {
        return self.totalSupply[tokenId]
    }

    // Initializes the contract
    init() {
        self.CollectionStoragePath = /storage/metapierLPTokenCollection
        self.CollectionPublicPath = /public/metapierLPTokenCollection

        self.totalSupply = {}

        let admin <- create Admin()
        self.account.save(<- admin, to: /storage/metapierLPTokenAdmin)

        emit ContractInitialized()
    }
}
