// SPDX-License-Identifier: Unlicense

import ARTIFACTPackV3 from 0x24de869c5e40b2eb
import ARTIFACTV2 from 0x24de869c5e40b2eb
import Interfaces from 0x24de869c5e40b2eb
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract ARTIFACTAdminV2: Interfaces {

  // -----------------------------------------------------------------------
  // ARTIFACTAdminV2 contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------

  /// Path where the `Admin` is stored
  pub let ARTIFACTAdminStoragePath: StoragePath

  /// Path where the private capability for the `Admin` is available
  pub let ARTIFACTAdminPrivatePath: PrivatePath

  /// Path where the private capability for the `Admin` is available
  pub let ARTIFACTAdminOpenerPrivatePath: PrivatePath
  
  /// Path where the `AdminTokenReceiver` is stored
  pub let ARTIFACTAdminTokenReceiverStoragePath: StoragePath

  /// Path where the public capability for the `AdminTokenReceiver` is available
  pub let ARTIFACTAdminTokenReceiverPublicPath: PublicPath

  /// Path where the private capability for the `AdminTokenReceiver` is available
  pub let ARTIFACTAdminTokenReceiverPrivatePath: PrivatePath
    
  // -----------------------------------------------------------------------
  // ARTIFACTAdminV2 contract-level Composite Type definitions
  // -----------------------------------------------------------------------
  // These are just *definitions* for Types that this contract
  // and other accounts can use. These definitions do not contain
  // actual stored values, but an instance (or object) of one of these Types
  // can be created by this contract that contains stored values.
  // ----------------------------------------------------------------------- 

  // ARTIFACTAdminV2 is a resource that ARTIFACTAdminV2 creator has
  // to mint NFT, create templates, open pack, create pack and create pack template
  // 
  pub resource Admin : Interfaces.ARTIFACTAdminOpener {
    
    // openPack create new NFTs randomly
    //
    // Parameters: userPack: The userPack reference with all pack informations
    // Parameters: packID: The pack ID
    // Parameters: owner: The pack owner
    //
    // returns: @[NonFungibleToken.NFT] the NFT created by the pack
    pub fun openPack(userPack: &{Interfaces.IPack}, packID: UInt64, owner: Address, royalties: [MetadataViews.Royalty], packOption: {Interfaces.IPackOption}?): @[NonFungibleToken.NFT] {
      pre {
          !userPack.isOpen : "User Pack must be closed"    
          !ARTIFACTPackV3.checkPackTemplateLockStatus(packTemplateId: userPack.templateId): "pack template is locked"
      }

      let packTemplate = ARTIFACTPackV3.getPackTemplate(templateId: userPack.templateId)! 
      var nfts: @[NonFungibleToken.NFT] <- []

      if packOption!.options.length > 19 {
        panic("Max number of template IDs inside a pack is 19")
      }

      var i: Int = 0
      while i < packOption!.options.length {
        let token <- self.mintNFT(templateId: packOption!.options[i], packID: packID, owner: owner, royalties: royalties, hashMetadata: ARTIFACTV2.HashMetadata(hash: packOption!.hash.hash, start: packOption!.hash.start, end:packOption!.hash.end))
        nfts.append(<- token)
        i = i + 1
      } 

      ARTIFACTPackV3.updatePackTemplate(packTemplate: packTemplate)

      return <- nfts
    }

    // updateLockStatus to update lock status of packs
    //
    // Parameters: packTemplateId: The pack template ID
    // Parameters: lockStatus: The lock status of pack template
    //
    pub fun updateLockStatus(packTemplateId: UInt64, lockStatus: Bool) {
      ARTIFACTPackV3.updateLockStatus(packTemplateId: packTemplateId, lockStatus: lockStatus)
    }

    // addPackOptions to add pack options to a pack template
    //
    // Parameters: packTemplateId: The pack template ID
    // Parameters: packsAvailable: The pack options
    //
    pub fun addPackOptions(packTemplateId: UInt64, packsAvailable: [ARTIFACTPackV3.PackOption]) {
      ARTIFACTPackV3.addPackOptions(packTemplateId: packTemplateId, packsAvailable: packsAvailable)
    }
    
    // createPack create a new Pack NFT 
    //
    // Parameters: packTemplate: The pack template with all information
    // Parameters: adminRef: Admin capability to open Pack 
    // Parameters: owner: The Pack owner
    // Parameters: listingID: The sale offer ID
    //
    // returns: @NonFungibleToken.NFT the pack that was created
    pub fun createPack(packTemplate: {Interfaces.IPackTemplate}, adminRef: Capability<&{Interfaces.ARTIFACTAdminOpener}>, owner: Address, listingID: UInt64, royalties: [MetadataViews.Royalty]) : @NonFungibleToken.NFT {
      return <- ARTIFACTPackV3.createPack(packTemplate: packTemplate, adminRef: adminRef, owner: owner, listingID: listingID, royalties: royalties)
    }

    // createPackTemplate create a new PackTemplate
    //
    // Parameters: metadata: The flexible field 
    // Parameters: totalSupply: The max quantity of pack to sell
    // Parameters: maxQuantityPerTransaction: The max quantity of pack to sell into one transaction
    // Parameters: packsAvailable: The available pack options 
    //
    // returns: UInt64 the new pack template ID 
    pub fun createPackTemplate(metadata: {String: String}, totalSupply: UInt64, maxQuantityPerTransaction: UInt64) : UInt64 {
      var newPackTemplate = ARTIFACTPackV3.createPackTemplate(metadata: metadata, totalSupply: totalSupply, maxQuantityPerTransaction: maxQuantityPerTransaction)

      return newPackTemplate.templateId
    }
    // mintNFT create a new NFT using a template ID
    //
    // Parameters: templateId: The Template ID
    // Parameters: packID: The pack ID
    // Parameters: owner: The pack owner
    //
    // returns: @NFT the token that was created
    pub fun mintNFT(templateId: String, packID: UInt64, owner: Address, royalties: [MetadataViews.Royalty], hashMetadata: ARTIFACTV2.HashMetadata): @ARTIFACTV2.NFT {
      return <- ARTIFACTV2.createNFT(templateId: templateId, packID: packID, owner: owner, royalties: royalties, hashMetadata: hashMetadata)
    }

    pub fun revealNFT(artifactCollection: &{ARTIFACTV2.IRevealNFT}, nftId: UInt64, metadata: {String: String}, edition: UInt64, rarity: UInt64) {
      artifactCollection.revealNFT(id: nftId, metadata: metadata, edition: edition, rarity: rarity)
    }

    pub fun removeOnePackOption(templateId: UInt64) : ARTIFACTPackV3.PackOption {
      let packTemplate = ARTIFACTPackV3.getPackTemplate(templateId: templateId)! 
      return ARTIFACTPackV3.getTemplateIdsFromPacksAvailable(packTemplate: packTemplate)
    }
  }

  pub resource SuperAdmin {
    access(self) var admins: [Address]

    init() {
      self.admins = []
    }

    pub fun givePermission(address: Address) {
      pre {
        self.admins.length <= 310 : "Max limit is 310"
      }
      self.admins.append(address)
    }

    pub fun revokePermission(address: Address) {
      var i: Int = 0
      while i < self.admins.length {
        if self.admins[i] == address {
          self.admins.remove(at: i)
        }
        i = i + 1
      }
    }
  }

  pub resource interface AdminTokenReceiverPublic {
      pub fun receiveAdmin(adminRef: Capability<&Admin> )
      pub fun receiveAdminCapabilityOpener(adminRef: Capability<&{Interfaces.ARTIFACTAdminOpener}> )
      pub fun receiveSuperAdmin(superAdminRef: @SuperAdmin)
  }

  pub resource AdminTokenReceiver: AdminTokenReceiverPublic {

    access(self) var adminRef: Capability<&Admin>?
    access(self) var adminCapabilityOpener: Capability<&{Interfaces.ARTIFACTAdminOpener}>?
    access(self) var superAdminRef: @[SuperAdmin]

    init() {
      self.adminRef = nil
      self.adminCapabilityOpener = nil
      self.superAdminRef <- []
    }

    destroy() {
      destroy self.superAdminRef
    }

    pub fun receiveAdmin(adminRef: Capability<&Admin> ) {
      self.adminRef = adminRef
    }
    
    pub fun receiveAdminCapabilityOpener(adminRef: Capability<&{Interfaces.ARTIFACTAdminOpener}> ) {
      self.adminCapabilityOpener = adminRef
    }

    pub fun receiveSuperAdmin(superAdminRef: @SuperAdmin) {
      self.superAdminRef.append(<- superAdminRef) 
    }

    pub fun getAdminRef(): &Admin? {
      return self.adminRef!.borrow()
    }

    pub fun getAdminOpenerRef(): Capability<&{Interfaces.ARTIFACTAdminOpener}> {
      return self.adminCapabilityOpener!
    }

    pub fun getSuperAdminRef(): &SuperAdmin {
      if( self.superAdminRef.length == 0) {
        panic("Can't access super admin permission")
      }
      return &self.superAdminRef[0] as auth &SuperAdmin
    }
  }

  // -----------------------------------------------------------------------
  // ARTIFACTAdminV2 contract-level function definitions
  // -----------------------------------------------------------------------

  // createAdminTokenReceiver create a admin token receiver
  //
  pub fun createAdminTokenReceiver(): @AdminTokenReceiver {
    return <- create AdminTokenReceiver()
  }
  
  init() {
    // Paths
    self.ARTIFACTAdminStoragePath = /storage/ARTIFACTAdminV2
    self.ARTIFACTAdminPrivatePath = /private/ARTIFACTAdminV2
    self.ARTIFACTAdminOpenerPrivatePath = /private/ARTIFACTAdminV2Opener
    self.ARTIFACTAdminTokenReceiverStoragePath = /storage/ARTIFACTAdminV2TokenReceiver
    self.ARTIFACTAdminTokenReceiverPublicPath = /public/ARTIFACTAdminV2TokenReceiver
    self.ARTIFACTAdminTokenReceiverPrivatePath = /private/ARTIFACTAdminV2TokenReceiver
    
    if(self.account.borrow<&{ARTIFACTAdminV2.AdminTokenReceiverPublic}>(from: self.ARTIFACTAdminTokenReceiverStoragePath) == nil) {
        self.account.save<@ARTIFACTAdminV2.AdminTokenReceiver>(<- create AdminTokenReceiver(), to: self.ARTIFACTAdminTokenReceiverStoragePath)
        self.account.link<&{ARTIFACTAdminV2.AdminTokenReceiverPublic}>(self.ARTIFACTAdminTokenReceiverPublicPath, target: self.ARTIFACTAdminTokenReceiverStoragePath)
    }

    let adminTokenReceiver = self.account.borrow<&ARTIFACTAdminV2.AdminTokenReceiver>(from: self.ARTIFACTAdminTokenReceiverStoragePath)
          ?? panic("Could not borrow user ARTIFACTAdminV2 admin token reference")
    adminTokenReceiver.receiveSuperAdmin(superAdminRef: <- create SuperAdmin())

    if self.account.borrow<&ARTIFACTAdminV2.Admin>(from: ARTIFACTAdminV2.ARTIFACTAdminStoragePath) == nil {
      self.account.save<@ARTIFACTAdminV2.Admin>(<- create ARTIFACTAdminV2.Admin(), to: ARTIFACTAdminV2.ARTIFACTAdminStoragePath)
    }

    self.account.link<&ARTIFACTAdminV2.Admin>(ARTIFACTAdminV2.ARTIFACTAdminPrivatePath, target: ARTIFACTAdminV2.ARTIFACTAdminStoragePath)!
    self.account.link<&{Interfaces.ARTIFACTAdminOpener}>(ARTIFACTAdminV2.ARTIFACTAdminOpenerPrivatePath, target: ARTIFACTAdminV2.ARTIFACTAdminStoragePath)!
  }
}