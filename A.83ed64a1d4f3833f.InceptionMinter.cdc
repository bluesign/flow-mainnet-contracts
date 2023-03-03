// SPDX-License-Identifier: MIT

import InceptionAvatar from 0x83ed64a1d4f3833f
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import FlowUtilityToken from 0xead892083b3e2c6c
import InceptionCrystal from 0x83ed64a1d4f3833f
import InceptionBlackBox from 0x83ed64a1d4f3833f

pub contract InceptionMinter {

  pub event ContractInitialized()

  pub let AdminStoragePath: StoragePath
  pub var tipMintPriceInDuc: UFix64
  pub var tipMintPriceInFlow: UFix64

  pub var preSaleMintLimitPerTx: UInt64
  pub var tipSaleLimitPerTx: UInt64

  access(self) var whitelistedAccounts: {Address: UInt64}
  access(self) var publicMintedAccounts: {Address: UInt64}
  access(self) var tipMintedAccounts: {Address: UInt64}
  access(self) var usdTipTracker: {Address: UFix64}
  access(self) var flowTipTracker: {Address: UFix64}

  pub fun tipMintWithDUC(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, merchantAccount: Address, numberOfTokens: UInt64) {
    pre {
      UInt64(self.tipMintedAccounts[buyer] ?? 0) + numberOfTokens <= 5:
        "You've tipped too much. Please wait for the next tip sale."
      numberOfTokens <= InceptionMinter.tipSaleLimitPerTx:
        "purchaseAmount too large"
      paymentVault.balance >= UFix64(numberOfTokens) * InceptionMinter.tipMintPriceInDuc:
        "Insufficient payment amount."
      paymentVault.getType() == Type<@DapperUtilityCoin.Vault>():
        "payment type not DapperUtilityCoin.Vault."
    }

    let admin = self.account.borrow<&InceptionAvatar.Admin>(from: InceptionAvatar.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionAvatar Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }

    // Get DUC receiver reference of InceptionAvatar merchant account
    let merchantDUCReceiverRef = getAccount(merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
      assert(merchantDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")
    // Deposit DUC to InceptionAvatar merchant account DUC Vault (it's then forwarded to the main DUC contract afterwards)
    merchantDUCReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive InceptionAvatar
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(InceptionAvatar.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint InceptionAvatar NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Add number of mints to tipMintedAccounts
    InceptionMinter.tipMintedAccounts[buyer] = UInt64(InceptionMinter.tipMintedAccounts[buyer] ?? 0) + numberOfTokens

    // Add amount to tipTracker
    InceptionMinter.usdTipTracker[buyer] = UFix64(InceptionMinter.usdTipTracker[buyer] ?? 0.00) + UFix64(numberOfTokens) * InceptionMinter.tipMintPriceInDuc

    // Hidden gem from the brotherhood of tinkers for your generosity
    if (InceptionBlackBox.mintLimit >= InceptionBlackBox.totalSupply) {
      let InceptionBlackBoxAdmin = self.account.borrow<&InceptionBlackBox.Admin>(from: InceptionBlackBox.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionBlackBox Admin")

      let InceptionBlackBoxReceiver = recipient.getCapability(InceptionBlackBox.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>()
        ?? panic("Could not get receiver reference to the InceptionBlackBox Collection")

      var blackBoxMintCounter = numberOfTokens
      while(blackBoxMintCounter > 0) {
        InceptionBlackBoxAdmin.mintInceptionBlackBox(recipient: InceptionBlackBoxReceiver)
        blackBoxMintCounter = blackBoxMintCounter - 1
      }
    }
  }

  pub fun tipMintWithFUT(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, merchantAccount: Address, numberOfTokens: UInt64) {
    pre {
      UInt64(self.tipMintedAccounts[buyer] ?? 0) + numberOfTokens < 10:
        "You've tipped too much. Please wait for the next tip sale."
      numberOfTokens <= InceptionMinter.tipSaleLimitPerTx:
        "purchaseAmount too large"
      paymentVault.balance >= UFix64(numberOfTokens) * InceptionMinter.tipMintPriceInFlow:
        "Insufficient payment amount."
      paymentVault.getType() == Type<@FlowUtilityToken.Vault>():
        "payment type not FlowUtilityToken.Vault."
    }

    let admin = self.account.borrow<&InceptionAvatar.Admin>(from: InceptionAvatar.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionAvatar Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }
    if (set.isPublic) { panic("Cannot mint public set with mintPrivateNFTWithFUT") }

    // Get FUT receiver reference of InceptionAvatar merchant account
    let merchantFUTReceiverRef = getAccount(merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)
      assert(merchantFUTReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant FUT receiver")
    // Deposit FUT to InceptionAvatar merchant account FUT Vault (it's then forwarded to the main FUT contract afterwards)
    merchantFUTReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive InceptionAvatar
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(InceptionAvatar.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint InceptionAvatar NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Add number of mints to tipMintedAccounts
    InceptionMinter.tipMintedAccounts[buyer] = UInt64(InceptionMinter.tipMintedAccounts[buyer] ?? 0) + numberOfTokens

    // Add amount to tipTracker
    InceptionMinter.flowTipTracker[buyer] = UFix64(InceptionMinter.flowTipTracker[buyer] ?? 0.00) + UFix64(numberOfTokens) * InceptionMinter.tipMintPriceInFlow

    // Hidden gem from the brotherhood of tinkers for your generosity
    if (InceptionBlackBox.mintLimit >= InceptionBlackBox.totalSupply) {
      let InceptionBlackBoxAdmin = self.account.borrow<&InceptionBlackBox.Admin>(from: InceptionBlackBox.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionBlackBox Admin")

      let InceptionBlackBoxReceiver = recipient.getCapability(InceptionBlackBox.CollectionPublicPath)
        .borrow<&{NonFungibleToken.CollectionPublic}>()
        ?? panic("Could not get receiver reference to the InceptionBlackBox Collection")

      var blackBoxMintCounter = numberOfTokens
      while(blackBoxMintCounter > 0) {
        InceptionBlackBoxAdmin.mintInceptionBlackBox(recipient: InceptionBlackBoxReceiver)
        blackBoxMintCounter = blackBoxMintCounter - 1
      }
    }
  }

  pub fun mintInceptionBlackBoxWithInceptionCrystal(buyer: Address, paymentVault: @InceptionCrystal.Collection) {
    pre {
      UInt64(paymentVault.getIDs().length) == InceptionBlackBox.crystalPrice:
        "incorrect crystal payment"
    }

    let InceptionBlackBoxAdmin = self.account.borrow<&InceptionBlackBox.Admin>(from: InceptionBlackBox.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionBlackBox Admin")

    let recipient = getAccount(buyer)
    let InceptionBlackBoxReceiver = recipient.getCapability(InceptionBlackBox.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the InceptionBlackBox Collection")

    InceptionBlackBoxAdmin.mintInceptionBlackBox(recipient: InceptionBlackBoxReceiver)

    destroy <- paymentVault
  }

  pub fun whitelistFreeMint(buyer: Address, setID: UInt64, numberOfTokens: UInt64) {
    pre {
      InceptionMinter.whitelistedAccounts[buyer]! >= 1:
        "Requesting account is not whitelisted"
      numberOfTokens <= InceptionMinter.preSaleMintLimitPerTx:
        "purchaseAmount too large"
      InceptionMinter.whitelistedAccounts[buyer]! >= numberOfTokens:
        "purchaseAmount exeeds allowed whitelist spots"
    }
    
    let admin = self.account.borrow<&InceptionAvatar.Admin>(from: InceptionAvatar.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionAvatar Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }

    // Get buyer collection public to receive InceptionAvatar
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(InceptionAvatar.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Validate buyer's DUC receiver
    let buyerDUCReceiverRef = getAccount(buyer).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
      assert(buyerDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed buyer DUC receiver")

    // Mint InceptionAvatar NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Empty whitelist spot
    if (InceptionMinter.whitelistedAccounts[buyer]! - numberOfTokens == 0) {
      InceptionMinter.whitelistedAccounts.remove(key: buyer)
    } else {
      InceptionMinter.whitelistedAccounts[buyer] = InceptionMinter.whitelistedAccounts[buyer]! - numberOfTokens
    }
  }

  // 1 for each outcast
  pub fun publicFreeMint(buyer: Address, setID: UInt64) {
    pre {
      !self.publicMintedAccounts.containsKey(buyer):
        "Requesting account has already minted"

      getCurrentBlock().timestamp >= 1663797540.00:
        "Not time yet"
    }

    let admin = self.account.borrow<&InceptionAvatar.Admin>(from: InceptionAvatar.AdminStoragePath)
      ?? panic("Could not borrow a reference to the InceptionAvatar Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }

    // Get buyer collection public to receive InceptionAvatar
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(InceptionAvatar.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Validate buyer's DUC receiver
    let buyerDUCReceiverRef = getAccount(buyer).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
      assert(buyerDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed buyer DUC receiver")

    // Mint InceptionAvatar NFT to recipient
    admin.mintNFT(recipient: NFTReceiver, setID: setID)

    // Add wallet address to minted list
    self.publicMintedAccounts[buyer] = 1
  }

  pub resource Admin {
    pub fun addWhiteListAddress(address: Address, amount: UInt64) {
      pre {
        amount <= 10:
          "Unable to allocate more than 10 whitelist spots"
        InceptionMinter.whitelistedAccounts[address] == nil:
          "Provided Address is already whitelisted"
      }
      InceptionMinter.whitelistedAccounts[address] = amount
    }

    pub fun removeWhiteListAddress(address: Address) {
      pre {
        InceptionMinter.whitelistedAccounts[address] != nil:
          "Provided Address is not whitelisted"
      }
      InceptionMinter.whitelistedAccounts.remove(key: address)
    }

    pub fun pruneWhitelist() {
      InceptionMinter.whitelistedAccounts = {}
    }

    pub fun updateWhiteListAddressAmount(address: Address, amount: UInt64) {
      pre {
        InceptionMinter.whitelistedAccounts[address] != nil:
          "Provided Address is not whitelisted"
      }
      InceptionMinter.whitelistedAccounts[address] = amount
    }

    pub fun updateTipSalePriceInDUC(price: UFix64) {
      InceptionMinter.tipMintPriceInDuc = price
    }

    pub fun updateTipSalePriceInFlow(price: UFix64) {
      InceptionMinter.tipMintPriceInFlow = price
    }

    pub fun getDucTipJar(): {Address: UFix64} {
      return InceptionMinter.usdTipTracker
    }

    pub fun getFlowTipJar(): {Address: UFix64} {
      return InceptionMinter.flowTipTracker
    }

    pub fun pruneAccount(address: Address) {
      if InceptionMinter.tipMintedAccounts.containsKey(address) {
        InceptionMinter.tipMintedAccounts.remove(key: address)
      }

      if InceptionMinter.whitelistedAccounts.containsKey(address) {
        InceptionMinter.whitelistedAccounts.remove(key: address)
      }

      if InceptionMinter.publicMintedAccounts.containsKey(address) {
        InceptionMinter.publicMintedAccounts.remove(key: address)
      }
    }
  }

  pub fun getWhitelistedAccounts(): {Address: UInt64} {
    return InceptionMinter.whitelistedAccounts
  }

  pub fun getWhitelistedEntriesByAddress(address: Address): UInt64 {
    return InceptionMinter.whitelistedAccounts[address] ?? 0
  }

  pub fun getTipMintAccounts(): {Address: UInt64} {
    return InceptionMinter.tipMintedAccounts
  }

  pub fun getTipMintCountPerAccount(address: Address): UInt64 {
    return InceptionMinter.tipMintedAccounts[address] ?? 0
  }

  pub fun getPublicMintCountPerAccount(address: Address): UInt64 {
    return InceptionMinter.publicMintedAccounts[address] ?? 0
  }

  init() {
    self.AdminStoragePath = /storage/InceptionAvatarWhitelistMinterAdmin

    self.preSaleMintLimitPerTx = 4
    self.tipSaleLimitPerTx = 5

    self.tipMintPriceInDuc = 20.00
    self.tipMintPriceInFlow = 12.00

    self.whitelistedAccounts = {}
    self.publicMintedAccounts = {}

    self.tipMintedAccounts = {}
    self.usdTipTracker = {}
    self.flowTipTracker = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}