// SPDX-License-Identifier: UNLICENSED

import Flunks from 0x807c3d470888cc48
import Backpack from 0x807c3d470888cc48
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c

pub contract BackpackMinter {

  pub event ContractInitialized()
  pub event BackpackClaimed(FlunkTokenID: UInt64, BackpackTokenID: UInt64, signer: Address)

  pub let AdminStoragePath: StoragePath

  access(self) var backpackClaimedPerFlunkTokenID: {UInt64: UInt64} // Flunk token ID: backpack token ID
  access(self) var backpackClaimedPerFlunkTemplate: {UInt64: UInt64} // Flunks template ID: backpack token ID

  pub fun claimBackPack(tokenID: UInt64, signer: AuthAccount, setID: UInt64) {
    // verify that the token is not already claimed
    pre {
      tokenID >= 0 && tokenID <= 9998:
        "Invalid Flunk token ID"

      !BackpackMinter.backpackClaimedPerFlunkTokenID.containsKey(tokenID):
        "Token ID already claimed"
    }

    // verify Flunk ownership
    let collection = getAccount(signer.address).getCapability<&Flunks.Collection{Flunks.FlunksCollectionPublic}>(Flunks.CollectionPublicPath).borrow()!
    let collectionIDs = collection.getIDs()
    if !collectionIDs.contains(tokenID) {
      panic("signer is not owner of Flunk")
    }

    // Get recipient receiver capoatility
    let recipient = getAccount(signer.address)
    let backpackReceiver = recipient.getCapability(Backpack.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the Backpack NFT Collection")

    // mint backpack to signer
    let admin = self.account.borrow<&Backpack.Admin>(from: Backpack.AdminStoragePath)
      ?? panic("Could not borrow a reference to the Backpack Admin")
    let backpackSet = admin.borrowSet(setID: setID)

    let backpackNFT <- backpackSet.mintNFT()
    let backpackTokenID = backpackNFT.id
    emit BackpackClaimed(FlunkTokenID: tokenID, BackpackTokenID: backpackNFT.id, signer: signer.address)
    backpackReceiver.deposit(token: <- backpackNFT)

    BackpackMinter.backpackClaimedPerFlunkTokenID[tokenID] = backpackTokenID

    let templateID = collection.borrowFlunks(id: tokenID)!.templateID
    BackpackMinter.backpackClaimedPerFlunkTemplate[templateID] = backpackTokenID
  }

  pub fun getClaimedBackPacksPerFlunkTokenID(): {UInt64: UInt64} {
    return BackpackMinter.backpackClaimedPerFlunkTokenID
  }

  pub fun getClaimedBackPacksPerFlunkTemplateID(): {UInt64: UInt64} {
    return BackpackMinter.backpackClaimedPerFlunkTemplate
  }

  init() {
    self.AdminStoragePath = /storage/BackpackMinterAdmin

    self.backpackClaimedPerFlunkTokenID = {}
    self.backpackClaimedPerFlunkTemplate = {}

    emit ContractInitialized()
  }
}