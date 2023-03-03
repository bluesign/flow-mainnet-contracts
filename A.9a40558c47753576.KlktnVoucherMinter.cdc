// SPDX-License-Identifier: MIT
import FungibleToken from 0xf233dcee88fe0abe
import DapperUtilityCoin from 0xead892083b3e2c6c
import NonFungibleToken from 0x1d7e57aa55817448
import KlktnVoucher from 0x9a40558c47753576

pub contract KlktnVoucherMinter {
  pub event ContractInitialized()

  pub let AdminStoragePath: StoragePath
  access(contract) var mintedAccounts: {Address: UInt64}

  pub fun mintKlktnVoucher(buyer: Address, templateID: UInt64) {

    pre {
      !KlktnVoucherMinter.mintedAccounts.containsKey(buyer):
        "Already minted!"
    }

    let admin = self.account.borrow<&KlktnVoucher.Admin>(from: KlktnVoucher.AdminStoragePath)
      ?? panic("Could not borrow a reference to the KlktnVoucher Admin")

    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(KlktnVoucher.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Validate buyer's DUC receiver
    let buyerDUCReceiverRef = getAccount(buyer).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
      assert(buyerDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed buyer DUC receiver")

    admin.mintNFT(recipient: NFTReceiver, templateID: templateID)

    KlktnVoucherMinter.mintedAccounts[buyer] = 1
  }

  pub fun hasMinted(address: Address): Bool {
    return KlktnVoucherMinter.mintedAccounts.containsKey(address)
  }

  pub resource Admin {
    pub fun removeUserFromMintedAccounts(address: Address) {
      pre {
        KlktnVoucherMinter.mintedAccounts[address] != nil:
          "Provided Address is not found"
      }

      KlktnVoucherMinter.mintedAccounts.remove(key: address)
    }
  }



  init() {
    self.AdminStoragePath = /storage/KlktnVoucherMinterWhitelistMinterAdmin
    self.mintedAccounts = {}
    
    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}
 