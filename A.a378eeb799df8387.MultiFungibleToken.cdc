/**

MultiFungibleToken is a semi-fungible token contract which helps to publish a group of fungible tokens without the need
of deploying multiple contracts. There are two cases to consider:
    - tokens are not compatible (non-fungible) when they have different token IDs
    - tokens are compatible (fungible) when they have the same token ID

@author Metapier Foundation Ltd.

 */
pub contract interface MultiFungibleToken {

    /// TokensInitialized
    ///
    /// The event that is emitted when the contract is created
    ///
    pub event ContractInitialized()

    /// TokensWithdrawn
    ///
    /// The event that is emitted when tokens are withdrawn from a Vault of some token ID
    ///
    pub event TokensWithdrawn(tokenId: UInt64, amount: UFix64, from: Address?)

    /// TokensDeposited
    ///
    /// The event that is emitted when tokens are deposited into a Vault of some token ID
    ///
    pub event TokensDeposited(tokenId: UInt64, amount: UFix64, to: Address?)

    /// Provider
    ///
    /// The interface that enforces the requirements for withdrawing
    /// tokens from the implementing type.
    ///
    /// It does not enforce requirements on `balance` here,
    /// because it leaves open the possibility of creating custom providers
    /// that do not necessarily need their own balance.
    ///
    pub resource interface Provider {

        /// withdraw subtracts tokens from the owner's Vault
        /// and returns a Vault with the removed tokens.
        ///
        /// The function's access level is public, but this is not a problem
        /// because only the owner storing the resource in their account
        /// can initially call this function.
        ///
        /// The owner may grant other accounts access by creating a private
        /// capability that allows specific other users to access
        /// the provider resource through a reference.
        ///
        /// The owner may also grant all accounts access by creating a public
        /// capability that allows all users to access the provider
        /// resource through a reference.
        ///
        pub fun withdraw(tokenId: UInt64, amount: UFix64): @Vault {
            post {
                // `result` refers to the return value
                result.balance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
                result.tokenId == tokenId:
                    "The withdrawn Vault must match with the given token ID"
            }
        }
    }

    /// Receiver
    ///
    /// The interface that enforces the requirements for depositing
    /// tokens into the implementing type.
    ///
    /// We do not include a condition that checks the balance because
    /// we want to give users the ability to make custom receivers that
    /// can do custom things with the tokens, like split them up and
    /// send them to different places.
    ///
    pub resource interface Receiver {

        /// deposit takes a Vault and deposits it into the implementing resource type
        ///
        pub fun deposit(from: @Vault)
    }

    /// View
    ///
    /// The interface that contains the `balance` and the `tokenId`
    /// fields of the Vault and enforces that when new Vaults are
    /// created, the fields are initialized correctly.
    ///
    pub resource interface View {

        pub var balance: UFix64

        pub let tokenId: UInt64

        init(tokenId: UInt64, balance: UFix64) {
            post {
                self.tokenId == tokenId:
                    "Token ID must be initialized to the initial tokenId"
                self.balance == balance:
                    "Balance must be initialized to the initial balance"
            }
        }
    }

    /// Vault
    ///
    /// The resource that contains the functions to send and receive tokens.
    ///
    pub resource Vault: Receiver, View {

        /// The total balance of the vault
        ///
        pub var balance: UFix64

        /// The token ID of the vault
        ///
        pub let tokenId: UInt64

        /// The conforming type must declare an initializer
        /// that allows providing the initial balance and token ID
        /// of the Vault
        ///
        init(tokenId: UInt64, balance: UFix64)

        /// withdraw subtracts `amount` from the Vault's balance
        /// and returns a new Vault with the same token ID and
        /// the subtracted balance
        ///
        pub fun withdraw(amount: UFix64): @Vault {
            pre {
                self.balance >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the Vault"
            }
            post {
                self.balance == before(self.balance) - amount:
                    "New Vault balance must be the difference of the previous balance and the withdrawn Vault"
                result.balance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
                self.tokenId == result.tokenId:
                    "The withdrawn tokens must match the given token ID"
            }
        }

        /// deposit takes a Vault of the same token ID and adds its
        /// balance to the balance of this Vault
        ///
        pub fun deposit(from: @Vault) {
            pre {
                from.isInstance(self.getType()): 
                    "Cannot deposit an incompatible token type"
                from.tokenId == self.tokenId:
                    "Cannot deposit a token of a different token ID"
            }
            post {
                self.balance == before(self.balance) + before(from.balance):
                    "New Vault balance must be the sum of the previous balance and the deposited Vault"
            }
        }
    }

    // Interface that an account would commonly use to
    // organize and store all the published tokens
    ///
    pub resource interface CollectionPublic {

        /// deposit stores the given vault into the collection
        /// or merges it into the vault of the same token ID in
        /// the collection if one exists
        ///
        pub fun deposit(from: @Vault)

        /// getTokenIds returns the token IDs of all vaults
        /// in the collection
        ///
        pub fun getTokenIds(): [UInt64]

        /// hasToken returns true iff the vault of the given
        /// token ID exists in the collection
        ///
        pub fun hasToken(tokenId: UInt64): Bool

        /// getPublicVault returns a restricted vault for
        /// public access, or throws an error if it doesn't
        /// have a vault of the requested token id
        ///
        pub fun getPublicVault(tokenId: UInt64): &{Receiver, View} {
            pre {
                self.hasToken(tokenId: tokenId): "Vault of the given ID does not exist in the collection"
            }
        }
    }

    /// Requirement for the the concrete resource type
    /// to be declared in the implementing contract
    ///
    pub resource Collection: Provider, Receiver, CollectionPublic {

        pub fun withdraw(tokenId: UInt64, amount: UFix64): @Vault

        pub fun deposit(from: @Vault)

        pub fun getTokenIds(): [UInt64]

        pub fun hasToken(tokenId: UInt64): Bool

        pub fun getPublicVault(tokenId: UInt64): &{Receiver, View}
    }

    /// createEmptyCollection creates an empty Collection
    /// and returns it to the caller so that they can own NFTs
    ///
    pub fun createEmptyCollection(): @Collection {
        post {
            result.getTokenIds().length == 0: "The created collection must be empty!"
        }
    }

    /// createEmptyVault allows any user to create a new Vault (of a valid token ID)
    /// that has a zero balance, or throws an error if the requested token id has
    /// not yet been initialized
    ///
    pub fun createEmptyVault(tokenId: UInt64): @Vault {
        pre {
            self.getTotalSupply(tokenId: tokenId) != nil: "Token of the given token ID does not exist"
        }
        post {
            result.tokenId == tokenId: "The newly created Vault must have the requested token ID"
            result.balance == 0.0: "The newly created Vault must have zero balance"
        }
    }

    /// getTotalSupply returns the total supply of the token
    /// corresponds to the given token ID, or nil if the token
    /// does not exist
    ///
    pub fun getTotalSupply(tokenId: UInt64): UFix64?
}
