// SPDX-License-Identifier: Unlicense

import FungibleToken from 0xf233dcee88fe0abe

pub contract CreateStoreFront {

    pub event CreateStoreFrontSubmit(storefrontAddress: Address)

    access(account) var beneficiaryCapability: Capability<&{FungibleToken.Receiver}>?
    access(account) var amount: UFix64
    
    pub fun createStorefront(storefrontAddress: Address, vault: @FungibleToken.Vault) {
        pre {
            vault.balance == self.amount: "Amount does not match the amount"
            self.amount >= UFix64(0): "Configure the amount field"
        }
        
        self.beneficiaryCapability!.borrow()!
            .deposit(from: <-vault)

        emit CreateStoreFrontSubmit(storefrontAddress: storefrontAddress)
    }

    pub resource Admin {
        pub fun updateBeneficiary(beneficiaryCapabilityReceiver: Capability<&{FungibleToken.Receiver}>) {
            CreateStoreFront.beneficiaryCapability = beneficiaryCapabilityReceiver
        }
        pub fun updateAmount(amountReceiver: UFix64) {
            CreateStoreFront.amount = amountReceiver
        }
    }

    init () {
        self.amount = UFix64(0)
        self.beneficiaryCapability = nil
        self.account.save<@CreateStoreFront.Admin>(<- create Admin(), to: /storage/createStoreFrontAdmin)
    }
}
 