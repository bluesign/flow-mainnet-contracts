import FungibleToken from 0xf233dcee88fe0abe

pub contract JoyrideMultiToken {
    // Always 0. This is not really a Token
    pub var totalSupply: UFix64

    // Defines paths for user accounts
    pub let UserStoragePath: StoragePath
    pub let UserPublicPath: PublicPath
    pub let UserPrivatePath: PrivatePath

    // Defines token vault storage paths
    access(contract) let TokenStoragePaths: {UInt8: StoragePath}

    // Defines token vault public paths
    access(contract) let TokenPublicPaths: {UInt8: PublicPath}

    /// TokensInitialized
    ///
    /// The event that is emitted when the contract is created
    ///
    pub event TokensInitialized(initialSupply: UFix64)
    pub event JoyrideMultiTokenInfoEvent(notes: String)

    /// TokensWithdrawn
    ///
    /// The event that is emitted when tokens are withdrawn from a Vault
    ///
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// TokensDeposited
    ///
    /// The event that is emitted when tokens are deposited into a Vault
    ///
    pub event TokensDeposited(amount: UFix64, to: Address?)

    pub enum Vaults: UInt8 {
        pub case treasury
        pub case reserve
    }

    pub resource interface Receiver  {
        pub fun depositToken(from: @FungibleToken.Vault)
        pub fun balanceOf(tokenContext: String): UFix64
    }

    pub resource Vault: Receiver {
        pub let Depositories: {String: Capability<&FungibleToken.Vault>}

        init(zero: UFix64) {
            self.Depositories = {}
        }

        /*pub fun deposit(from: @FungibleToken.Vault) {
            let mtv <- from as! @JoyrideMultiToken.Vault
            for vaultKey in mtv.Depositories.keys {
                let vault = mtv.Depositories[vaultKey]!.borrow() ??
                    panic("unable to borow capability")
                self.depositToken(from: <- vault.withdraw(amount: vault.balance))
            }
            destroy mtv
        }*/

        pub fun depositToken(from: @FungibleToken.Vault) {
            let tokenIdetifier: String = from.getType().identifier
            emit JoyrideMultiTokenInfoEvent(notes: "depositToken for user".concat(tokenIdetifier))
            let vault = self.Depositories[tokenIdetifier]?? panic("unable to borrow capability depositToken")
            let capability = vault.borrow()??panic("unable to get vault capability")
            capability.deposit(from: <- from)
        }

        pub fun withdrawToken(tokenContext: String, amount: UFix64): @FungibleToken.Vault {
            //let tokenIdentifier: String = tokenContext.identifier
            let vault = self.Depositories[tokenContext]?.borrow()??panic("unable to borrow capability withdraw")
            return <- vault!.withdraw(amount: amount)
        }

        pub fun registerCapability(tokenIdentifier: String, capability: Capability<&FungibleToken.Vault>) {
            //let tokenIdentifier: String = capability.borrow()!.getType().identifier;
            emit JoyrideMultiTokenInfoEvent(notes: "registerCapability".concat(tokenIdentifier))
            self.Depositories[tokenIdentifier] = capability;
        }

        pub fun doesCapabilityExists(tokenIdentifier: String): Bool {
            return self.Depositories.containsKey(tokenIdentifier)
        }

        pub fun balanceOf(tokenContext: String): UFix64 {
            //let tokenIdentifier: String = tokenContext.identifier
            let vault = self.Depositories[tokenContext]?.borrow() ?? panic("Token tokenContext Unknown")
            emit JoyrideMultiTokenInfoEvent(notes: vault!.getType().identifier)
            return vault!.balance
        }
    }

    pub fun createEmptyVault() : @Vault {
        return <- create Vault(zero:0.0);
    }

    access(contract) fun getPlatformBalance(vault: Vaults, tokenContext: String) : UFix64 {
        return self.account.borrow<&Vault>(from: self.TokenStoragePaths[vault.rawValue]!)?.balanceOf(tokenContext: tokenContext) ?? 0.0
    }

    access(contract) fun doPlatformWithdraw(vault: Vaults, tokenContext: String, amount: UFix64) : @FungibleToken.Vault? {
        let path = self.TokenStoragePaths[vault.rawValue]
        emit JoyrideMultiTokenInfoEvent(notes: "vault Index".concat(vault.rawValue.toString()))
        if(path == nil) { return nil }

        let vault = self.account.borrow<&Vault>(from: path!)
        if(vault == nil) { return nil }
        if(vault!.balanceOf(tokenContext: tokenContext) < amount) { return nil }
        return <- vault!.withdrawToken(tokenContext: tokenContext, amount: amount)
    }

    access(contract) fun doPlatformDeposit(vault:Vaults, from: @FungibleToken.Vault) {
        self.account.borrow<&Vault>(from: self.TokenStoragePaths[vault.rawValue]!)!.depositToken(from: <-from)
    }

    pub resource interface PlatformBalance {
        pub fun balance(vault:Vaults, tokenContext: String) : UFix64
    }

    pub resource interface PlatformWithdraw {
        pub fun withdraw(vault: Vaults, tokenContext: String, amount: UFix64, purpose: String) : @FungibleToken.Vault?
    }

    pub resource interface PlatformDeposit {
        pub fun deposit(vault:Vaults, from: @FungibleToken.Vault)
    }

    pub resource PlatformAdmin : PlatformBalance, PlatformWithdraw, PlatformDeposit {
        pub fun balance(vault:Vaults, tokenContext: String) : UFix64 {
            return JoyrideMultiToken.getPlatformBalance(vault:vault,tokenContext:tokenContext);
        }

        pub fun withdraw(vault: Vaults, tokenContext: String, amount: UFix64, purpose: String) : @FungibleToken.Vault? {
            return <-JoyrideMultiToken.doPlatformWithdraw(vault: vault, tokenContext: tokenContext, amount: amount)
        }

        pub fun deposit(vault:Vaults, from: @FungibleToken.Vault) {
            JoyrideMultiToken.doPlatformDeposit(vault: vault, from:<-from)
        }
    }

    init() {
        self.totalSupply = 0.0;

        self.TokenStoragePaths = {}
        self.TokenPublicPaths = {}
        self.TokenStoragePaths[Vaults.treasury.rawValue] = /storage/JoyrideMultiToken_PlatformTreasury
        self.TokenPublicPaths[Vaults.treasury.rawValue] = /public/JoyrideMultiToken_PlatformTreasury
        self.TokenStoragePaths[Vaults.reserve.rawValue] = /storage/JoyrideMultiToken_PlatformReserve
        self.TokenPublicPaths[Vaults.reserve.rawValue] = /public/JoyrideMultiToken_PlatformReserve

        self.UserStoragePath = /storage/JoyrideMultiToken
        self.UserPublicPath = /public/JoyrideMultiToken
        self.UserPrivatePath = /private/JoyrideMultiToken

        let treasury <- self.createEmptyVault()
        self.account.save(<-treasury, to: self.TokenStoragePaths[Vaults.treasury.rawValue]!)

        self.account.link<&{FungibleToken.Receiver, FungibleToken.Balance}>(
            self.TokenPublicPaths[Vaults.treasury.rawValue]!,
            target: self.TokenStoragePaths[Vaults.treasury.rawValue]!
        )

        let reserve <- self.createEmptyVault()
        self.account.save(<-reserve, to: self.TokenStoragePaths[Vaults.reserve.rawValue]!)

        self.account.link<&{FungibleToken.Receiver, FungibleToken.Balance}>(
            self.TokenPublicPaths[Vaults.reserve.rawValue]!,
            target: self.TokenStoragePaths[Vaults.reserve.rawValue]!
        )

        let platformAdmin <- create PlatformAdmin()
        self.account.save(<-platformAdmin, to: /storage/JoyrideMultiToken_PlatformAdmin)
        self.account.link<&JoyrideMultiToken.PlatformAdmin>(
            /private/JoyrideMultiToken_PlatformAdmin,
            target: /storage/JoyrideMultiToken_PlatformAdmin
        )

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }

    pub struct TokenContextModel {
        pub var Symbol: String
        pub var TokenName: String
        pub var VaultName: String
        pub var FullAddress: String
        pub var TokenAddress: Address
        pub var StoragePath: String
        pub var BalancePath: String
        pub var ReceiverPath: String
        pub var PrivatePath: String

        init(Symbol: String, TokenName: String, VaultName: String, FullAddress: String, TokenAddress: Address, StoragePath: String, BalancePath: String,
            ReceiverPath: String, PrivatePath: String) {
            self.Symbol = Symbol
            self.TokenName = TokenName
            self.VaultName = VaultName
            self.FullAddress = FullAddress
            self.TokenAddress = TokenAddress
            self.StoragePath = StoragePath
            self.BalancePath = BalancePath
            self.ReceiverPath = ReceiverPath
            self.PrivatePath = PrivatePath
        }
    }
}