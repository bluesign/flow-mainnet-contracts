import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import FungibleTokenMetadataViews from 0xf233dcee88fe0abe

pub contract Rumble: FungibleToken {

    /// Total supply of ExampleTokens in existence
    pub var totalSupply: UFix64
    pub var maxSupply: UFix64
    
    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    /// The event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    /// The event that is emitted when a new burner resource is created
    pub event BurnerCreated()

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
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {

        /// The total balance of this vault
        pub var balance: UFix64

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            if self.balance > 0.0 {
                Rumble.totalSupply = Rumble.totalSupply - self.balance
            }
        }

        /// The way of getting all the Metadata Views implemented by ExampleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        pub fun getViews(): [Type]{
            return [Type<FungibleTokenMetadataViews.FTView>(),
                    Type<FungibleTokenMetadataViews.FTDisplay>(),
                    Type<FungibleTokenMetadataViews.FTVaultData>()]
        }

        /// The way of getting a Metadata View out of the ExampleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FungibleTokenMetadataViews.FTView>():
                    return FungibleTokenMetadataViews.FTView(
                        ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                        ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                    )
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    let media = MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let medias = MetadataViews.Medias([media])
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: "Raiders Rumble Token",
                        symbol: "RUMB",
                        description: "This fungible token is used as an example to help you develop your next FT #onFlow.",
                        externalURL: MetadataViews.ExternalURL("https://example-ft.onflow.org"),
                        logos: medias,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<FungibleTokenMetadataViews.FTVaultData>():
                    return FungibleTokenMetadataViews.FTVaultData(
                        storagePath: Rumble.VaultStoragePath,
                        receiverPath: Rumble.ReceiverPublicPath,
                        metadataPath: Rumble.VaultPublicPath,
                        providerPath: /private/RumbleVault,
                        receiverLinkedType: Type<&Vault{FungibleToken.Receiver}>(),
                        metadataLinkedType: Type<&Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
                        providerLinkedType: Type<&Vault{FungibleToken.Provider}>(),
                        createEmptyVaultFunction: (fun (): @Vault {
                            return <- Rumble.createEmptyVault()
                        })
                    )
            }
            return nil
        }
    }

    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    /// @return The new Vault resource
    ///
    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    pub resource Minter {

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// @param amount: The quantity of tokens to mint
        /// @return The Vault resource containing the minted tokens
        ///
        pub fun mintTokens(amount: UFix64): @Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount + Rumble.totalSupply <= Rumble.maxSupply: "Cannot mint more than the max supply."
            }
            Rumble.totalSupply = Rumble.totalSupply + amount
            emit TokensMinted(amount: amount)
            return <- create Vault(balance: amount)
        }

        pub fun changeMaxSupply(maxSupply: UFix64) {
            pre {
                maxSupply >= Rumble.totalSupply: "New max supply must be greater than or equal to the current total supply"
            }
            Rumble.maxSupply = maxSupply
        }
    }

    init() {
        self.totalSupply = 0.0
        self.maxSupply = 100000000.0
        self.VaultStoragePath = /storage/RumbleVault
        self.VaultPublicPath = /public/RumblePublic
        self.ReceiverPublicPath = /public/RumbleReceiver
        self.MinterStoragePath = /storage/RumbleAdmin

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.link<&Vault{FungibleToken.Receiver}>(
            self.ReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.link<&Vault{FungibleToken.Balance}>(
            self.VaultPublicPath,
            target: self.VaultStoragePath
        )

        self.account.save(<- create Minter(), to: self.MinterStoragePath)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
 