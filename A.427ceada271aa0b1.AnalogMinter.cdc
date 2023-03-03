import Analogs from 0x427ceada271aa0b1
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import FlowUtilityToken from 0xead892083b3e2c6c

pub contract AnalogMinter {

  pub event ContractInitialized()

  pub let AdminStoragePath: StoragePath

  pub var mintableSets: {UInt64: MintableSet}

  pub struct MintableSet {
    pub var privateSalePrice: UFix64
    pub var publicSalePrice: UFix64
    pub var whitelistedAccounts: {Address: UInt64}
    access(self) var metadata: {String: String}

    access(account) fun addWhiteListAddress(address: Address, amount: UInt64) {
      pre {
        self.whitelistedAccounts[address] == nil: "Provided Address is already whitelisted"
      }
      self.whitelistedAccounts[address] = amount
    }

    access(account) fun removeWhiteListAddress(address: Address) {
      pre {
        self.whitelistedAccounts[address] != nil: "Provided Address is not whitelisted"
      }
      self.whitelistedAccounts.remove(key: address)
    }

    access(account) fun pruneWhitelist() {
      self.whitelistedAccounts = {}
    }

    access(account) fun updateWhiteListAddressAmount(address: Address, amount: UInt64) {
      pre {
        self.whitelistedAccounts[address] != nil:
          "Provided Address is not whitelisted"
      }
      self.whitelistedAccounts[address] = amount
    }

    access(account) fun updatePrivateSalePrice(price: UFix64) {
      self.privateSalePrice = price
    }

    access(account) fun updatePublicSalePrice(price: UFix64) {
      self.publicSalePrice = price
    }

    init(privateSalePrice: UFix64, publicSalePrice: UFix64){
      self.privateSalePrice = privateSalePrice
      self.publicSalePrice= publicSalePrice
      self.whitelistedAccounts = {}
      self.metadata = {}
    }
  }

  pub fun mintPrivateNFTWithFUT(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, merchantAccount: Address, numberOfTokens: UInt64) {
    pre {
      AnalogMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! >= 1:
        "Requesting account is not whitelisted"
      // This code is commented for future use case. In case addresses needs a buy amount limit for private sales, this should be discommented.
      // AnalogMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! >= numberOfTokens: "purchaseAmount exceeds allowed whitelist spots"
      paymentVault.balance >= UFix64(numberOfTokens) * AnalogMinter.mintableSets[setID]!.privateSalePrice:
        "Insufficient payment amount."
      paymentVault.getType() == Type<@FlowUtilityToken.Vault>():
        "payment type not FlowUtilityToken.Vault."
    }

    let admin = self.account.borrow<&Analogs.Admin>(from: Analogs.AdminStoragePath)
      ?? panic("Could not borrow a reference to the Analogs Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }
    if (set.isPublic) { panic("Cannot mint public set with mintPrivateNFTWithFUT") }

    // Get FUT receiver reference of Analogs merchant account
    let merchantFUTReceiverRef = getAccount(set.analogRoyaltyAddress).getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)
      assert(merchantFUTReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant FUT receiver")
    // Deposit FUT to Analogs merchant account FUT Vault (it's then forwarded to the main FUT contract afterwards)
    merchantFUTReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive Analogs
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(Analogs.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint Analogs NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Empty whitelist spot
    if (AnalogMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! - numberOfTokens == 0) {
      AnalogMinter.mintableSets[setID]!.removeWhiteListAddress(address: buyer)
    } else {
      let newAmount = AnalogMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! - numberOfTokens
      AnalogMinter.mintableSets[setID]!.updateWhiteListAddressAmount(address: buyer, amount: newAmount)
    }
  }

  pub fun mintPublicNFTWithFUT(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, merchantAccount: Address, numberOfTokens: UInt64) {
    pre {
      numberOfTokens <= 4:
        "purchaseAmount too large"
      paymentVault.balance >= UFix64(numberOfTokens) * AnalogMinter.mintableSets[setID]!.publicSalePrice:
        "Insufficient payment amount."
      paymentVault.getType() == Type<@FlowUtilityToken.Vault>():
        "payment type not FlowUtilityToken.Vault."
    }

    let admin = self.account.borrow<&Analogs.Admin>(from: Analogs.AdminStoragePath)
      ?? panic("Could not borrow a reference to the Analogs Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }
    if (!set.isPublic) { panic("Cannot mint private set with mintPublicNFTWithFUT") }

    // Get FUT receiver reference of Analogs merchant account
    let merchantFUTReceiverRef = getAccount(set.analogRoyaltyAddress).getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)
      assert(merchantFUTReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant FUT receiver")
    // Deposit FUT to Analogs merchant account FUT Vault (it's then forwarded to the main FUT contract afterwards)
    merchantFUTReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive Analogs
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(Analogs.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint Analogs NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }
  }

  pub fun mintFreeNFT(buyer: Address, numberOfTokens: UInt64) {
    pre {
      numberOfTokens > 0: "numberOfTokens must be greater than 0"
    }
    let setID: UInt64 = 1
    var mintedCount: UInt64? = AnalogMinter.mintableSets[setID]!.whitelistedAccounts[buyer]
    if mintedCount == nil {
      mintedCount = 0
      AnalogMinter.mintableSets[setID]!.addWhiteListAddress(address: buyer, amount: numberOfTokens)
    } else {
      AnalogMinter.mintableSets[setID]!.updateWhiteListAddressAmount(address: buyer, amount: mintedCount! + numberOfTokens)
    }
    assert(mintedCount! + numberOfTokens <= 5, message: "You exceed the minting limit")
    
    let admin = self.account.borrow<&Analogs.Admin>(from: Analogs.AdminStoragePath)
      ?? panic("Could not borrow a reference to the Analogs Admin")

    let set = admin.borrowSet(setID: setID)
    if (set.getAvailableTemplateIDs().length == 0) {
      panic("Set is empty")
    }
    if (set.locked) {
      panic("Set is locked")
    }

    let buyerFUTReceiverRef = getAccount(buyer).getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)
    assert(buyerFUTReceiverRef.borrow() != nil, message: "Missing or mis-typed buyer FUT receiver")

    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(Analogs.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }
  }

  pub resource Admin {

    pub fun createMintableSet(setID: UInt64, privateSalePrice: UFix64, publicSalePrice: UFix64) {
      pre {
        AnalogMinter.mintableSets[setID] == nil: "Set already exists"
      }
      AnalogMinter.mintableSets[setID] = MintableSet(privateSalePrice: privateSalePrice, publicSalePrice: publicSalePrice)
    }

    pub fun addWhiteListAddress(setID: UInt64, address: Address, amount: UInt64) {
      AnalogMinter.mintableSets[setID]!.addWhiteListAddress(address: address, amount: amount)
    }

    pub fun removeWhiteListAddress(setID: UInt64, address: Address) {
      AnalogMinter.mintableSets[setID]!.removeWhiteListAddress(address: address)
    }

    pub fun pruneWhitelist(setID: UInt64) {
      AnalogMinter.mintableSets[setID]!.pruneWhitelist()
    }

    pub fun updateWhiteListAddressAmount(setID: UInt64, address: Address, amount: UInt64) {
      AnalogMinter.mintableSets[setID]!.updateWhiteListAddressAmount(address: address, amount: amount)
    }

    pub fun updatePrivateSalePrice(setID: UInt64, price: UFix64) {
      AnalogMinter.mintableSets[setID]!.updatePrivateSalePrice(price: price)
    }

    pub fun updatePublicSalePrice(setID: UInt64, price: UFix64) {
      AnalogMinter.mintableSets[setID]!.updatePublicSalePrice(price: price)
    }
  }

  pub fun getWhitelistedAccounts(setID: UInt64): {Address: UInt64} {
    return AnalogMinter.mintableSets[setID]!.whitelistedAccounts
  }

  init() {
    self.AdminStoragePath = /storage/AnalogMinterAdmin

    self.mintableSets = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}