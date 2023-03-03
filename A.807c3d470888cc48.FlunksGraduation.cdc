// SPDX-License-Identifier: MIT

import Flunks from 0x807c3d470888cc48

pub contract FlunksGraduation {
  pub event ContractInitialized()
  pub event Graduate(address: Address, tokenID: UInt64, templateID: UInt64)
  pub event GraduateTimeUpdate(tokenID: UInt64, time: UInt64)

  pub let AdminStoragePath: StoragePath

  access(self) var GraduatedFlunks: {UInt64: Bool}
  access(self) var GraduationTime: {UInt64: UInt64}
  access(self) var tokenIDToUri: {UInt64: String}

  pub fun graduateFlunk(owner: AuthAccount, tokenID: UInt64) {
    pre {
      !FlunksGraduation.GraduatedFlunks.containsKey(tokenID):
        "Flunk has already graduated"
      FlunksGraduation.GraduationTime[tokenID] ?? 1682049600 <= UInt64(getCurrentBlock().timestamp):
        "Not time yet"
    }

    // Check if owner is the true owner of the NFT
    let collection = getAccount(owner.address).getCapability<&Flunks.Collection{Flunks.FlunksCollectionPublic}>(Flunks.CollectionPublicPath).borrow()!
    let ownerCollectionTokenIds = collection.getIDs()
    if !ownerCollectionTokenIds.contains(tokenID) {
      panic("Not owner")
    }

    let item = collection.borrowFlunks(id: tokenID)
    let templateID = item!.templateID
    let itemTemplate = item!.getNFTTemplate()

    // Update the NFT metadata and traits on-chain
    let admin = self.account.borrow<&Flunks.Admin>(from: Flunks.AdminStoragePath)
      ?? panic("Could not borrow a reference to the Flunks Admin")
    let adminSet = admin.borrowSet(setID: itemTemplate.addedToSet)
    
    let newMetadata = item!.getNFTMetadata()
    newMetadata["Type"] = "Graduated"
    newMetadata["pixelUri"] = newMetadata["uri"]
    newMetadata["uri"] = FlunksGraduation.tokenIDToUri[tokenID]!
    adminSet.updateTemplateMetadata(templateID: templateID, newMetadata: newMetadata)
    // Graduate Flunks
    FlunksGraduation.GraduatedFlunks[tokenID] = true
    FlunksGraduation.GraduationTime.remove(key: tokenID)
    emit Graduate(address: owner.address, tokenID: tokenID, templateID: templateID)
  }

  pub fun isFlunkGraduated(tokenID: UInt64): Bool {
    return FlunksGraduation.GraduatedFlunks[tokenID] ?? false
  }

  pub fun getFlunksGraduationTimeTable(): {UInt64: UInt64} {
    return FlunksGraduation.GraduationTime
  }

  pub resource Admin {
    pub fun updateGraduationTime(tokenID: UInt64, _timeInSeconds: UInt64) {
      pre {
        !FlunksGraduation.GraduatedFlunks.containsKey(tokenID):
          "Flunk has already graduated"
      }
      FlunksGraduation.GraduationTime[tokenID] = _timeInSeconds

      // emit GraduateTimeUpdate(tokenID: tokenID, time: _timeInSeconds)
    }

    pub fun setGraduatedUri(tokenID: UInt64, uri: String) {
        if FlunksGraduation.GraduatedFlunks.containsKey(tokenID) {
          return
        }
      FlunksGraduation.tokenIDToUri[tokenID] = uri
    }

    pub fun alfredGraduatesForYa(ownerAddress: Address, templateID: UInt64, tokenID: UInt64) {
      pre {
        !FlunksGraduation.GraduatedFlunks.containsKey(tokenID):
          "Flunk has already graduated"
      }

      // Check if owner is the true owner of the NFT
      let collection = getAccount(ownerAddress).getCapability<&Flunks.Collection{Flunks.FlunksCollectionPublic}>(Flunks.CollectionPublicPath).borrow()!
      let ownerCollectionTokenIds = collection.getIDs()
      if !ownerCollectionTokenIds.contains(tokenID) {
        panic("Not owner")
      }

      let item = collection.borrowFlunks(id: tokenID)
      let templateID = item!.templateID
      let itemTemplate = item!.getNFTTemplate()

      // Update the NFT metadata and traits on-chain
      let admin = FlunksGraduation.account.borrow<&Flunks.Admin>(from: Flunks.AdminStoragePath)
        ?? panic("Could not borrow a reference to the Flunks Admin")
      let adminSet = admin.borrowSet(setID: itemTemplate.addedToSet)
      
      let newMetadata = item!.getNFTMetadata()
      newMetadata["Type"] = "Graduated"
      newMetadata["pixelUri"] = newMetadata["uri"]
      newMetadata["uri"] = FlunksGraduation.tokenIDToUri[tokenID]!
      adminSet.updateTemplateMetadata(templateID: templateID, newMetadata: newMetadata)
      // Graduate Flunks
      FlunksGraduation.GraduatedFlunks[tokenID] = true
      FlunksGraduation.GraduationTime.remove(key: tokenID)
      emit Graduate(address: ownerAddress, tokenID: tokenID, templateID: templateID)
    }

    pub fun refreshGraduatedMetadata(ownerAddress: Address, templateID: UInt64, tokenID: UInt64) {
      emit Graduate(address: ownerAddress, tokenID: tokenID, templateID: templateID)
    }
  }

  init() {
    self.AdminStoragePath = /storage/FlunksGraduationAdmin
    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    self.GraduatedFlunks = {}
    self.GraduationTime = {}
    self.tokenIDToUri = {}

    emit ContractInitialized()
  }
}
 