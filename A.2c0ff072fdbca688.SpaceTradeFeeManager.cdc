import FungibleToken from 0xf233dcee88fe0abe
import SpaceTradeAssetCatalog from 0x2c0ff072fdbca688

pub contract SpaceTradeFeeManager {

    pub event ContractInitialized()

    pub let SpaceTradeManagerStoragePath: StoragePath
    pub let SpaceTradeManagerPrivatePath: PrivatePath

    pub var fee: Fee?

    // We can have multiple receivers that has their each cut percentage specified
    pub struct FeeCut {
        pub let receiver: Capability<&{FungibleToken.Receiver}>
        pub let cutPercentage: UFix64

        init(
            receiver: Capability<&{FungibleToken.Receiver}>,
            cutPercentage: UFix64
        ) {
            self.receiver = receiver
            self.cutPercentage = cutPercentage
        }
    }

    pub struct Fee {
        pub let tokenName: String
        pub let vaultType: Type
        pub let tokenAmount: UFix64
        pub let feeCuts: [FeeCut]

        init(
            tokenName: String,
            vaultType: Type, 
            tokenAmount: UFix64, 
            feeCuts: [FeeCut]
        ) {
            pre {
                SpaceTradeAssetCatalog.isSupportedFT(tokenName): "Unsupported fungible token specified for fees"
            }
            self.tokenName = tokenName
            self.vaultType = vaultType
            self.tokenAmount = tokenAmount
            self.feeCuts = feeCuts
        }

        pub fun deposit(payment: @FungibleToken.Vault) {
            pre {
                payment.isInstance(self.vaultType): "Unable to transfer fee with unknown token type"
            }
    
            let availableReceivers: [&AnyResource{FungibleToken.Receiver}] = []
            let initialBalance = payment.balance
            
            for feeCut in self.feeCuts {
                // Rather than aborting the transaction if any receiver is absent when we try to pay it to available receivers with their specified cuts
                if let receiver = feeCut.receiver.borrow() {
                    let cut <- payment.withdraw(amount: initialBalance * feeCut.cutPercentage)
                    receiver.deposit(from: <- cut)
                    availableReceivers.append(receiver)
                }
            }

            if payment.balance > 0.0 {
                // Equally distribute to available receivers
                let restBalance = payment.balance
                for availableReceiver in availableReceivers {
                    let cut <- payment.withdraw(amount: restBalance * (1.0 / UFix64(availableReceivers.length)))
                    availableReceiver.deposit(from: <- cut)
                }
            }

            // noop normally, but ensure that we have deposited everything!
            availableReceivers[0].deposit(from: <- payment)
        }
    }

    pub resource Manager {

        pub fun updateFee(_ fee: SpaceTradeFeeManager.Fee?)  {
            SpaceTradeFeeManager.fee = fee
        }
    }

    init() {
        self.SpaceTradeManagerStoragePath = /storage/SpaceTradeFreeManager
        self.SpaceTradeManagerPrivatePath = /private/SpaceTradeFreeManager

        // Create a manager and store it to contract account
        self.account.save(<- create Manager(), to: self.SpaceTradeManagerStoragePath)
        self.account.link<&Manager>(self.SpaceTradeManagerPrivatePath, target: self.SpaceTradeManagerStoragePath) 

        // Fee details, nil means that this contract is free to use, manager can use SpaceTradeFreeManager to override this
        self.fee = nil

        emit ContractInitialized()
    }
}
 