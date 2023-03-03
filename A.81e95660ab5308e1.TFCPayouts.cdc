import FungibleToken from 0xf233dcee88fe0abe

pub contract TFCPayouts {

    // Events
    pub event PayoutCompleted(to: Address, amount: UFix64, token: String)
    pub event ContractInitialized()

    // Named Paths
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    pub resource Administrator {
        pub fun payout(to: Address, from: @FungibleToken.Vault, paymentVaultType: Type, receiverPath: PublicPath) {
            let amount = from.balance
            let receiver = getAccount(to).getCapability(receiverPath)
                .borrow<&{FungibleToken.Receiver}>()
                ?? panic("Could not borrow receiver reference to the recipient's Vault")
            receiver.deposit(from: <-from)
            emit PayoutCompleted(to: to, amount: amount, token: paymentVaultType.identifier)
        }
    }

    init() {
        // Set our named paths
        self.AdminStoragePath = /storage/TFCPayoutsAdmin
        self.AdminPrivatePath=/private/TFCPayoutsPrivate

        // Create a Admin resource and save it to storage
        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
        self.account.link<&Administrator>(self.AdminPrivatePath, target: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
 