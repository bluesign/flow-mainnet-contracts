import FungibleToken from 0xf233dcee88fe0abe
import MemeToken from 0x4ba5947a0f1852c0

/// The MarketplaceFees contract is responsible for managing the fees for the marketplace.
/// This contract derived from the FlowTokenFees contract in the FlowToken contract.
pub contract MarketplaceFees {

    // Event that is emitted when tokens are deposited to the fee vault
    pub event TokensDeposited(amount: UFix64)

    // Event that is emitted when tokens are withdrawn from the fee vault
    pub event TokensWithdrawn(amount: UFix64)

    // Event that is emitted when fees are deducted
    pub event FeesDeducted(amount: UFix64)

    // Event that is emitted when fee parameters change
    pub event FeeParametersChanged(rate: UFix64)

    // Private vault with public deposit function
    access(self) var vault: @MemeToken.Vault

    pub fun deposit(from: @FungibleToken.Vault) {
        let from <- from as! @MemeToken.Vault
        let balance = from.balance
        self.vault.deposit(from: <-from)
        emit TokensDeposited(amount: balance)
    }

    /// Get the balance of the Fees Vault
    pub fun getFeeBalance(): UFix64 {
        return self.vault.balance
    }

    pub resource Administrator {
        // withdraw
        //
        // Allows the administrator to withdraw tokens from the fee vault
        pub fun withdrawTokensFromFeeVault(amount: UFix64): @FungibleToken.Vault {
            let vault <- MarketplaceFees.vault.withdraw(amount: amount)
            emit TokensWithdrawn(amount: amount)
            return <-vault
        }

        /// Allows the administrator to change all the fee parameters at once
        pub fun setFeeParameters(rate: UFix64, receiverCapability: Capability<&{FungibleToken.Receiver}>) {
            let newParameters = FeeParameters(rate: rate, receiverCapability: receiverCapability)
            MarketplaceFees.setFeeParameters(newParameters)
        }
    }

    /// A struct holding the fee parameters needed to calculate the fees
    pub struct FeeParameters {
        /// The surge factor is used to make transaction fees respond to high loads on the network
        pub var rate: UFix64

        /// The receiver capability is used to deposit the fees to the fee vault
        pub var receiverCapability: Capability<&{FungibleToken.Receiver}>

        init(rate: UFix64, receiverCapability: Capability<&{FungibleToken.Receiver}>){
            self.rate = rate
            self.receiverCapability = receiverCapability
        }
    }

    /// Called when a transaction is submitted to deduct the fee
    /// from the AuthAccount that submitted it
    pub fun deductFee(_ account: AuthAccount, totalAmount: UFix64) {
        var feeAmount = self.computeFees(amount: totalAmount, description: nil)

        if feeAmount == UFix64(0) {
            // If there are no fees to deduct, do not continue, 
            // so that there are no unnecessarily emitted events
            return
        }

        let tokenVault = account.borrow<&MemeToken.Vault>(from: MemeToken.VaultStoragePath)
            ?? panic("Unable to borrow reference to the default token vault")

        
        if feeAmount > tokenVault.balance {
            // In the future this code path will never be reached, 
            // as payers that are under account minimum balance will not have their transactions included in a collection
            //
            // Currently this is not used to fail the transaction (as that is the responsibility of the minimum account balance logic),
            // But is used to reduce the balance of the vault to 0.0, if the vault has less available balance than the transaction fees. 
            feeAmount = tokenVault.balance
        }
        
        let feeVault <- tokenVault.withdraw(amount: feeAmount)
        self.vault.deposit(from: <-feeVault)

        // The fee calculation can be reconstructed using the data from this event and the FeeParameters at the block when the event happened
        emit FeesDeducted(amount: feeAmount)
    }

    pub fun getFeeParameters(): FeeParameters {
        return self.account.copy<FeeParameters>(from: /storage/MarketplaceFeeParameters) ?? panic("Error getting marketplace fee parameters. They need to be initialized first!")
    }

    access(self) fun setFeeParameters(_ feeParameters: FeeParameters) {
        // empty storage before writing new FeeParameters to it
        self.account.load<FeeParameters>(from: /storage/MarketplaceFeeParameters)
        self.account.save(feeParameters,to: /storage/MarketplaceFeeParameters)
        emit FeeParametersChanged(rate: feeParameters.rate)
    }

    // compute the transaction fees with the current fee parameters and the given inclusionEffort and executionEffort
    pub fun computeFees(amount: UFix64, description: String?): UFix64 {
        let params = self.getFeeParameters()
        return params.rate * amount
    }

    init() {
        // Create a new empty Vault for the fees if not already created
        self.vault <- MemeToken.createEmptyVault()

        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/marketplaceFeesAdmin)

        // Create receiver capability for the fee vault
        let capability = getAccount(self.account.address)
            .getCapability<&{FungibleToken.Receiver}>(MemeToken.ReceiverPublicPath)


        // Initialize the fee parameters if they are not already initialized
        if self.account.borrow<&FeeParameters>(from: /storage/MarketplaceFeeParameters) == nil {
            let feeParameters = FeeParameters(rate: 0.05, receiverCapability: capability)
            self.account.save(feeParameters, to: /storage/MarketplaceFeeParameters)
        }
    }
}