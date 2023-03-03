// SPDX-License-Identifier: Unlicense

import NonFungibleToken from 0x1d7e57aa55817448
import NFTStorefront from 0x1e66a65ea2c60694
import StoreFront from 0x1e66a65ea2c60694

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

    init(databaseID: String) {
      self.storeFront <- NFTStorefront.createStorefront()
      self.adminRef <- {}
      self.adminRef[0] <-! StoreFront.createStoreFrontAdmin()
      self.fee = 0.0

      emit StoreFrontCreated(databaseID: databaseID)
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
  pub fun createSuperAdmin(databaseID: String): @SuperAdmin {
    return <- create SuperAdmin(databaseID: databaseID)
  }

  init() {
    // Paths
    self.storeFrontAdminReceiverPublicPath = /public/AdminTokenReceiver0x1e66a65ea2c60694
    self.storeFrontAdminReceiverStoragePath = /storage/AdminTokenReceiver0x1e66a65ea2c60694

    emit ContractInitialized()
  }
}