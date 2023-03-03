// SPDX-License-Identifier: UNLICENSED

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import Collector from 0x7c8995e83c4b1843

pub contract CollectorMinter {
  pub event ContractInitialized(merchantAccount: Address)

  pub let AdminStoragePath: StoragePath
  
  pub var privateSaleMaxTokens: UInt64
  pub var privateSalePrice: UFix64
  pub var presaleMaxTokens: UInt64
  pub var presalePrice: UFix64
  pub var publicSaleMaxTokens: UInt64
  pub var publicSalePrice: UFix64

  pub var privateSaleRegistrationOpen: Bool
  pub var presaleRegistrationOpen: Bool

  access(self) var privateSaleAccounts: {Address: UInt64}
  access(self) var presaleAccounts: {Address: UInt64}
  access(self) var publicSaleAccounts: {Address: UInt64}

  pub var merchantAccount: Address

  pub fun registerForPrivateSale(buyer: Address) {
    pre {
      self.privateSaleRegistrationOpen == true:
        "Private sale registration is closed"
      self.privateSaleAccounts[buyer] == nil:
        "Address already registered for the private sale"
    }

    self.privateSaleAccounts[buyer] = self.privateSaleMaxTokens
  }

  pub fun privateSaleMintNFTWithDUC(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, numberOfTokens: UInt64, merchantAccount: Address) {
    pre {
      self.privateSaleAccounts[buyer]! >= 0:
        "Requesting account is not whitelisted"
      numberOfTokens <= self.privateSaleMaxTokens:
        "Purchase amount exceeds maximum allowed"
      self.privateSaleAccounts[buyer]! >= numberOfTokens:
        "Purchase amount exceeds maximum buyer allowance"
      paymentVault.balance >= UFix64(numberOfTokens) * self.privateSalePrice:
        "Insufficient payment amount"
      paymentVault.getType() == Type<@DapperUtilityCoin.Vault>():
        "Payment type not DapperUtilityCoin"
      self.merchantAccount == merchantAccount:
        "Mismatching merchant account"
    }

    let admin = self.account.borrow<&Collector.Admin>(from: Collector.AdminStoragePath)
      ?? panic("Could not borrow a reference to the collector admin")

    let set = admin.borrowSet(id: setID)

    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }

    // Check set eligibility
    if (set.isPublic) { panic("Cannot mint public set with privateSaleMintNFTWithDUC") }

    // Get DUC receiver reference of Collector merchant account
    let merchantDUCReceiverRef = getAccount(self.merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
    assert(merchantDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")

    // Deposit DUC to Collector merchant account DUC Vault (it's then forwarded to the main DUC contract afterwards)
    merchantDUCReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive Collector
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(Collector.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT collection")

    // Mint Collector NFTs
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Remove utilized spots
    self.privateSaleAccounts[buyer] = self.privateSaleAccounts[buyer]! - numberOfTokens
  }

  pub fun registerForPresale(buyer: Address) {
    pre {
      self.presaleRegistrationOpen == true:
        "Presale registration is closed"
      self.presaleAccounts[buyer] == nil:
        "Address already registered for the presale"
    }

    self.presaleAccounts[buyer] = self.presaleMaxTokens
  }

  pub fun presaleMintNFTWithDUC(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, numberOfTokens: UInt64, merchantAccount: Address) {
    pre {
      self.presaleAccounts[buyer]! >= 0:
        "Requesting account is not whitelisted"
      numberOfTokens <= self.presaleMaxTokens:
        "Purchase amount exceeds maximum allowed"
      self.presaleAccounts[buyer]! >= numberOfTokens:
        "Purchase amount exceeds maximum buyer allowance"
      paymentVault.balance >= UFix64(numberOfTokens) * self.presalePrice:
        "Insufficient payment amount"
      paymentVault.getType() == Type<@DapperUtilityCoin.Vault>():
        "Payment type not DapperUtilityCoin"
      self.merchantAccount == merchantAccount:
        "Mismatching merchant account"
      Collector.totalSupply < 3506:
        "Reached max capacity"
    }

    let admin = self.account.borrow<&Collector.Admin>(from: Collector.AdminStoragePath)
      ?? panic("Could not borrow a reference to the collector admin")

    let set = admin.borrowSet(id: setID)

    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }

    // Check set eligibility
    if (set.isPublic) { panic("Cannot mint public set with presaleMintNFTWithDUC") }

    // Get DUC receiver reference of Collector merchant account
    let merchantDUCReceiverRef = getAccount(self.merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
    assert(merchantDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")

    // Deposit DUC to Collector merchant account DUC Vault (it's then forwarded to the main DUC contract afterwards)
    merchantDUCReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive Collector
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(Collector.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT collection")

    // Mint Collector NFTs
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Remove utilized spots
    self.presaleAccounts[buyer] = self.presaleAccounts[buyer]! - numberOfTokens
  }

  pub fun publicSaleMintNFTWithDUC(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, numberOfTokens: UInt64, merchantAccount: Address) {
    pre {
      numberOfTokens <= self.publicSaleMaxTokens:
        "Purchase amount exeeds maximum allowed"
      paymentVault.balance >= UFix64(numberOfTokens) * self.publicSalePrice:
        "Insufficient payment amount"
      paymentVault.getType() == Type<@DapperUtilityCoin.Vault>():
        "Payment type not DapperUtilityCoin"
      self.merchantAccount == merchantAccount:
        "Mismatching merchant account"
      Collector.totalSupply < 3506:
        "Reached max capacity"
    }

    // Add address to public sale accounts list
    if (self.publicSaleAccounts[buyer] == nil) {
      self.publicSaleAccounts[buyer] = self.publicSaleMaxTokens
    }

    // Check buyer hasn't exceeded their allowance
    if (self.publicSaleAccounts[buyer]! < numberOfTokens) {
      panic("Purchase amount exceeds maximum buyer allowance")
    }

    let admin = self.account.borrow<&Collector.Admin>(from: Collector.AdminStoragePath)
      ?? panic("Could not borrow a reference to the collector admin")

    let set = admin.borrowSet(id: setID)

    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }

    // Check set eligibility
    if (!set.isPublic) { panic("Cannot mint private set with publicSaleMintNFTWithDUC") }

    // Get DUC receiver reference of Collector merchant account
    let merchantDUCReceiverRef = getAccount(self.merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
    assert(merchantDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")

    // Deposit DUC to Collector merchant account DUC Vault (it's then forwarded to the main DUC contract afterwards)
    merchantDUCReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive Collector
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(Collector.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint Collector NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Remove utilized spots
    self.publicSaleAccounts[buyer] = self.publicSaleAccounts[buyer]! - numberOfTokens
  }

  pub resource Admin {
    //
    // PRIVATE SALE FUNCTIONS
    //
    pub fun addAccountToPrivateSale(address: Address, amount: UInt64) {
      pre {
        amount <= CollectorMinter.privateSaleMaxTokens:
          "Unable to allocate more private sale spots"
        CollectorMinter.privateSaleAccounts[address] == nil:
          "Provided address already added to the private sale"
      }
      CollectorMinter.privateSaleAccounts[address] = amount
    }

    pub fun removeAccountFromPrivateSale(address: Address) {
      pre {
        CollectorMinter.privateSaleAccounts[address] != nil:
          "Provided address is not in the private sale list"
      }
      CollectorMinter.privateSaleAccounts.remove(key: address)
    }

    pub fun updatePrivateSaleAccountAmount(address: Address, amount: UInt64) {
      pre {
        CollectorMinter.privateSaleAccounts[address] != nil:
          "Provided address is not in the private sale list"
      }
      CollectorMinter.privateSaleAccounts[address] = amount
    }

    pub fun updatePrivateSaleMaxTokens(amount: UInt64) {
      CollectorMinter.privateSaleMaxTokens = amount
    }

    pub fun updatePrivateSalePrice(price: UFix64) {
      CollectorMinter.privateSalePrice = price
    }

    pub fun prunePrivateSaleAccounts() {
      CollectorMinter.privateSaleAccounts = {}
    }

    pub fun closePrivateSaleRegistration() {
      CollectorMinter.privateSaleRegistrationOpen = false
    }

    pub fun openPrivateSaleRegistration() {
      CollectorMinter.privateSaleRegistrationOpen = true
    }

    //
    // PRESALE FUNCTIONS
    //
    pub fun addAccountToPresale(address: Address, amount: UInt64) {
      pre {
        amount <= CollectorMinter.presaleMaxTokens:
          "Unable to allocate more presale spots"
        CollectorMinter.presaleAccounts[address] == nil:
          "Provided address already added to the presale"
      }
      CollectorMinter.presaleAccounts[address] = amount
    }

    pub fun removeAccountFromPresale(address: Address) {
      pre {
        CollectorMinter.presaleAccounts[address] != nil:
          "Provided address is not in the presale list"
      }
      CollectorMinter.presaleAccounts.remove(key: address)
    }

    pub fun updatePresaleAccountAmount(address: Address, amount: UInt64) {
      pre {
        CollectorMinter.presaleAccounts[address] != nil:
          "Provided address is not in the presale list"
      }
      CollectorMinter.presaleAccounts[address] = amount
    }

    pub fun updatePresaleMaxTokens(amount: UInt64) {
      CollectorMinter.presaleMaxTokens = amount
    }

    pub fun updatePresalePrice(price: UFix64) {
      CollectorMinter.presalePrice = price
    }

    pub fun prunePresaleAccounts() {
      CollectorMinter.presaleAccounts = {}
    }

    pub fun closePresaleRegistration() {
      CollectorMinter.presaleRegistrationOpen = false
    }

    pub fun openPresaleRegistration() {
      CollectorMinter.presaleRegistrationOpen = true
    }

    //
    // PUBLIC SALE FUNCTIONS
    //
    pub fun updatePublicSaleMaxTokens(amount: UInt64) {
      CollectorMinter.publicSaleMaxTokens = amount
    }

    pub fun updatePublicSalePrice(price: UFix64) {
      CollectorMinter.publicSalePrice = price
    }

    pub fun prunePublicSaleAccounts() {
      CollectorMinter.publicSaleAccounts = {}
    }

    //
    // COMMON
    //
    pub fun updateMerchantAccount(newAddr: Address) {
      CollectorMinter.merchantAccount = newAddr
    }
  }

  pub fun getPrivateSaleAccounts(): {Address: UInt64} {
    return self.privateSaleAccounts
  }
  
  pub fun getPresaleAccounts(): {Address: UInt64} {
    return self.presaleAccounts
  }

  pub fun getPublicSaleAccounts(): {Address: UInt64} {
    return self.publicSaleAccounts
  }

  init(merchantAccount: Address) {
    self.AdminStoragePath = /storage/CollectorMinterAdmin

    self.privateSaleRegistrationOpen = true
    self.presaleRegistrationOpen = true

    self.privateSaleMaxTokens = 1
    self.privateSalePrice = 10.00
    self.privateSaleAccounts = {}

    self.presaleMaxTokens = 3
    self.presalePrice = 129.00
    self.presaleAccounts = {}

    self.publicSaleMaxTokens = 3
    self.publicSalePrice = 179.00
    self.publicSaleAccounts = {}

    // For testnet this should be 0x03df89ac89a3d64a
    // For mainnet this should be 0xfe15c4f52a58c75e
    self.merchantAccount = merchantAccount

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized(merchantAccount: merchantAccount)
  }
}
 