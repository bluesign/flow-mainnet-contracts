// SPDX-License-Identifier: Unlicense

import NonFungibleToken from 0x1d7e57aa55817448
import NFTStorefront from 0xb91d6d1a35de19b9
import StoreFront from 0xb91d6d1a35de19b9

// TOKEN RUNNERS: Contract responsable for Admin and Super admin permissions
pub contract StoreFrontSuperAdmin {

  // -----------------------------------------------------------------------
  // StoreFrontSuperAdmin contract-level fields.
  // These contain actual values that are stored in the smart contract.
  // -----------------------------------------------------------------------

  /// Path where the public capability for the `Collection` is available
  pub let storeFrontAdminReceiverPublicPath: PublicPath

  /// Path where the private capability for the `Collection` is available
  pub let storeFrontAdminReceiverStoragePath: StoragePath

  /// Path where the store capability for the `SuperAdmin` is available
  pub let storeFrontSuperAdminStoragePath: StoragePath

  /// Path where the store capability for the `Admin` is available
  pub let storeFrontAdminStoragePath: StoragePath

  /// Event used on contract initiation
  pub event ContractInitialized()

  /// Event used on create super admin
  pub event StoreFrontCreated(databaseID: String)

  // -----------------------------------------------------------------------
  // StoreFrontSuperAdmin contract-level Composite Type definitions
  // -----------------------------------------------------------------------
  // These are just *definitions* for Types that this contract
  // and other accounts can use. These definitions do not contain
  // actual stored values, but an instance (or object) of one of these Types
  // can be created by this contract that contains stored values.
  // -----------------------------------------------------------------------

  pub resource interface ISuperAdminStoreFrontPublic {
    pub fun getStoreFrontPublic(): &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    pub fun getSecondaryMarketplaceFee(): UFix64
  }

  pub resource SuperAdmin: ISuperAdminStoreFrontPublic {
    pub var storeFront: @NFTStorefront.Storefront
    pub var adminRef: @{UInt64: StoreFront.Admin}
    pub var fee: UFix64

    init() {
      self.storeFront <- NFTStorefront.createStorefront()
      self.adminRef <- {}
      self.adminRef[0] <-! StoreFront.createStoreFrontAdmin()
      self.fee = 0.0
    }

    destroy() {
      destroy self.storeFront
      destroy self.adminRef
    }

    pub fun getStoreFront(): &NFTStorefront.Storefront {
      return &self.storeFront as &NFTStorefront.Storefront
    }

    pub fun getStoreFrontPublic(): &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic} {
      return &self.storeFront as &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    }

    pub fun getSecondaryMarketplaceFee(): UFix64 {
      return self.fee
    }

    pub fun changeFee(_newFee: UFix64) {
      self.fee = _newFee
    }

    pub fun withdrawAdmin(): @StoreFront.Admin {

      let token <- self.adminRef.remove(key: 0)
          ?? panic("Cannot withdraw admin resource")

      return <- token
    }
  }

  pub resource interface AdminTokenReceiverPublic {
    pub fun receiveAdmin(adminRef: Capability<&StoreFront.Admin>)
    pub fun receiveSuperAdmin(superAdminRef: Capability<&SuperAdmin>)
    pub fun getSuperAdminRefPublic(): &SuperAdmin{ISuperAdminStoreFrontPublic}?
  }

  pub resource AdminTokenReceiver: AdminTokenReceiverPublic {

    access(self) var adminRef: Capability<&StoreFront.Admin>?
    access(self) var superAdminRef: Capability<&SuperAdmin>?

    init() {
      self.adminRef = nil
      self.superAdminRef = nil
    }

    pub fun receiveAdmin(adminRef: Capability<&StoreFront.Admin>) {
      self.adminRef = adminRef
    }

    pub fun receiveSuperAdmin(superAdminRef: Capability<&SuperAdmin>) {
      self.superAdminRef = superAdminRef
    }

    pub fun getSuperAdminRefPublic(): &SuperAdmin{ISuperAdminStoreFrontPublic}? {
      return self.superAdminRef!.borrow()
    }

    pub fun getAdminRef(): &StoreFront.Admin? {
      return self.adminRef!.borrow()
    }

    pub fun getSuperAdminRef(): &SuperAdmin? {
      return self.superAdminRef!.borrow()
    }
  }

  // -----------------------------------------------------------------------
  // StoreFrontSuperAdmin contract-level function definitions
  // -----------------------------------------------------------------------

  // createAdminTokenReceiver create a admin token receiver. Must be public
  //
  pub fun createAdminTokenReceiver(): @AdminTokenReceiver {
    return <- create AdminTokenReceiver()
  }

  // createSuperAdmin create a super admin. Must be public
  //
  pub fun createSuperAdmin(adminTokenReceiver: Capability<&{AdminTokenReceiverPublic}>, storeFrontSuperAdminPrivatePath: PrivatePath, storeFrontAdminPrivatePath: PrivatePath) {
    pre {
      adminTokenReceiver.address == self.requestedAdress : "Wallet can't get super admin permission!"
  }

    let capabilitySuperAdmin = self.account.link<&SuperAdmin>(storeFrontSuperAdminPrivatePath, target: self.storeFrontSuperAdminStoragePath)!
    let capabilityAdmin = self.account.link<&StoreFront.Admin>(storeFrontAdminPrivatePath, target: self.storeFrontAdminStoragePath)!

    adminTokenReceiver.borrow()!.receiveSuperAdmin(superAdminRef: capabilitySuperAdmin)
    adminTokenReceiver.borrow()!.receiveAdmin(adminRef: capabilityAdmin)
  }

  access(contract) let requestedAdress: Address

  init(requestedAdress: Address) {
    // Paths
    self.storeFrontAdminReceiverPublicPath = /public/AdminTokenReceiver0xb91d6d1a35de19b9
    self.storeFrontAdminReceiverStoragePath = /storage/AdminTokenReceiver0xb91d6d1a35de19b9
    self.storeFrontSuperAdminStoragePath = /storage/superAdminStoreFront
    self.storeFrontAdminStoragePath = /storage/AdminStoreFront

    self.requestedAdress = requestedAdress

    let superAdmin <- create SuperAdmin()
    let admin <- superAdmin.withdrawAdmin()

    self.account.save<@SuperAdmin>(<- superAdmin, to: self.storeFrontSuperAdminStoragePath)
    self.account.save<@StoreFront.Admin>(<- admin, to: self.storeFrontAdminStoragePath)

    emit ContractInitialized()
  }
}