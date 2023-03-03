import MultiFungibleToken from 0xa378eeb799df8387
import PierLPToken from 0x609e10301860b683

/**

PierSwapSettings provides an Admin resource to control
some behaviors in PierPair and PierSwapFactory contracts.

@author Metapier Foundation Ltd.

 */
pub contract PierSwapSettings {

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    // Event that is emitted when the trading fees have been updated
    pub event SwapFeesUpdated(poolTotalFee: UFix64, poolProtocolFee: UFix64)

    // Event that is emitted when the protocol fee recipient has been updated
    pub event ProtocolFeeRecipientUpdated(newAddress: Address)

    // DEPRECATED: Event that is emitted when the information for oracles is turned on/off
    pub event ObservationSwitchUpdated(enabled: Bool)

    // The fraction of the swap input to collect as the total trading fee
    pub var poolTotalFee: UFix64

    // The fraction of the swap input to collect as protocol fee (part of `poolTotalFee`)
    pub var poolProtocolFee: UFix64

    // The address to receive LP tokens as protocol fee
    pub var protocolFeeRecipient: Address

    // Admin resource provides functions for tuning fields
    // in this contract.
    pub resource Admin {
        
        // Updates `poolTotalFee` and `poolProtocolFee`
        // Always update both values to avoid bad configuration by mistakes
        pub fun setFees(newTotalFee: UFix64, newProtocolFee: UFix64) {
            pre {
                newTotalFee <= 0.01: "Metapier PierSwapSettings: Total fee can't exceed 1%"
                newProtocolFee < newTotalFee: "Metapier PierSwapSettings: Protocol fee can't exceed total fee"
            }
            post {
                PierSwapSettings.getPoolTotalFeeCoefficient() % 1.0 == 0.0: 
                    "Metapier PierSwapSettings: Total fee doesn't support 4 or more decimals"
                newProtocolFee == 0.0 || PierSwapSettings.getPoolProtocolFeeCoefficient() % 1.0 == 0.0: 
                    "Metapier PierSwapSettings: Protocol fee should be zero or its coefficient should be an integer"
            }

            PierSwapSettings.poolTotalFee = newTotalFee
            PierSwapSettings.poolProtocolFee = newProtocolFee

            emit SwapFeesUpdated(poolTotalFee: newTotalFee, poolProtocolFee: newProtocolFee)
        }

        // Updates `protocolFeeRecipient`
        pub fun setProtocolFeeRecipient(newAddress: Address) {
            pre {
                getAccount(newAddress)
                    .getCapability<&PierLPToken.Collection{MultiFungibleToken.Receiver}>(PierLPToken.CollectionPublicPath)
                    .check():
                    "Metapier PierSwapSettings: Cannot find LP token collection in new protocol fee recipient"
            }
            PierSwapSettings.protocolFeeRecipient = newAddress

            emit ProtocolFeeRecipientUpdated(newAddress: newAddress)
        }
    }

    // Used in PierPair to calculate total fee
    pub fun getPoolTotalFeeCoefficient(): UFix64 {
        return self.poolTotalFee * 1_000.0
    }

    // Used in PierPair to calculate protocol fee
    pub fun getPoolProtocolFeeCoefficient(): UFix64 {
        return self.poolTotalFee / self.poolProtocolFee - 1.0
    }

    // Used in PierPair to deposit minted LP tokens as protocol fee
    pub fun depositProtocolFee(vault: @MultiFungibleToken.Vault) {
        let feeCollectionRef = getAccount(self.protocolFeeRecipient)
            .getCapability<&PierLPToken.Collection{MultiFungibleToken.Receiver}>(PierLPToken.CollectionPublicPath)
            .borrow() ?? panic("Metapier PierSwapSettings: Protocol fee receiver not found")
        feeCollectionRef.deposit(from: <-vault)
    }

    init() {
        self.poolTotalFee = 0.003 // The initial total fee is 0.3%
        self.poolProtocolFee = 0.0005 // The initial protocol fee is 0.05%
        self.protocolFeeRecipient = self.account.address // The default recipient is current account

        // create and store admin
        let admin <- create Admin()
        self.account.save(<- admin, to: /storage/metapierSwapSettingsAdmin)

        // LP token collection setup
        self.account.save(<-PierLPToken.createEmptyCollection(), to: PierLPToken.CollectionStoragePath)
        self.account.link<&PierLPToken.Collection{MultiFungibleToken.Receiver, MultiFungibleToken.CollectionPublic}>(
            PierLPToken.CollectionPublicPath, 
            target: PierLPToken.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}