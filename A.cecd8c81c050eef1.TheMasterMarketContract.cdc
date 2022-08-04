

import TheMasterPieceContract from 0xcecd8c81c050eef1
import TheMasterPixelContract from 0xcecd8c81c050eef1
import FungibleToken from 0xf233dcee88fe0abe

pub contract TheMasterMarketContract {

    pub event ForSale(sectorId: UInt16, ids: [UInt32], price: UFix64)
    pub event TokenPurchased(sectorId: UInt16, ids: [UInt32], price: UFix64)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath


    pub let MarketStateStoragePath: StoragePath
    pub let MarketStatePublicPath: PublicPath

    pub fun createTheMasterMarket(sectorsRef: Capability<&TheMasterPixelContract.TheMasterSectors>): @TheMasterMarket {
        return <- create TheMasterMarket(sectorsRef: sectorsRef)
    }

    init() {

        // Set our named paths
        self.CollectionStoragePath = /storage/TheMasterMarket
        self.CollectionPublicPath = /public/TheMasterMarket

        self.MarketStateStoragePath = /storage/TheMasterMarketState
        self.MarketStatePublicPath = /public/TheMasterMarketState

        if (self.account.borrow<&TheMasterMarketState>(from: self.MarketStateStoragePath) == nil) {
          self.account.save(<- create TheMasterMarketState(), to: self.MarketStateStoragePath)
          self.account.link<&{TheMasterMarketStateInterface}>(self.MarketStatePublicPath, target: self.MarketStateStoragePath)
        }

        if (self.account.borrow<&TheMasterMarket>(from: self.CollectionStoragePath) == nil) {
          self.account.save(<-self.createTheMasterMarket(sectorsRef: self.account.getCapability<&TheMasterPixelContract.TheMasterSectors>(TheMasterPixelContract.CollectionPrivatePath)), to: self.CollectionStoragePath)
          self.account.link<&{TheMasterMarketInterface}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        }
    }

    access(contract) fun isOpened(ownerAddress: Address): Bool {
      let refMarketState = getAccount(self.account.address).getCapability<&AnyResource{TheMasterMarketStateInterface}>(/public/TheMasterMarketState).borrow()!
      return refMarketState.isOpened() || (self.account.address == ownerAddress)
    }

    // ########################################################################################

    pub resource TheMasterMarketSector {
        priv var forSale: @{UInt32: TheMasterPixelContract.TheMasterPixel}
        priv var prices: {UInt32: UFix64}
        pub var sectorId: UInt16

        access(account) let ownerVault: Capability<&AnyResource{FungibleToken.Receiver}>
        access(account) let creatorVault: Capability<&AnyResource{FungibleToken.Receiver}>
        access(account) let sectorsRef: Capability<&TheMasterPixelContract.TheMasterSectors>

        init (sectorId: UInt16, ownerVault: Capability<&AnyResource{FungibleToken.Receiver}>, creatorVault: Capability<&AnyResource{FungibleToken.Receiver}>, sectorsRef: Capability<&TheMasterPixelContract.TheMasterSectors>) {
            self.sectorId = sectorId
            self.forSale <- {}
            self.prices = {}

            self.ownerVault = ownerVault
            self.creatorVault = creatorVault
            self.sectorsRef = sectorsRef
        }

        pub fun listForSale(tokenIDs: [UInt32], price: UFix64) {
            pre {
              TheMasterMarketContract.isOpened(ownerAddress: (self.owner!).address):
                    "The trade market is not opened yet."
            }

            let sectorsRef = (self.sectorsRef.borrow()!)
            let sectorRef = sectorsRef.getSectorRef(sectorId: self.sectorId)

            TheMasterPieceContract.setSaleSize(sectorId: self.sectorId, address: (self.owner!).address, size: UInt16(self.prices.length + tokenIDs.length))
            TheMasterPieceContract.setWalletSize(sectorId: self.sectorId, address: (self.owner!).address, size: UInt16(sectorRef.getIds().length - tokenIDs.length))

            for tokenID in tokenIDs {
              self.prices[tokenID] = price
              sectorRef.withdraw(id: tokenID)
            }

            emit ForSale(sectorId: self.sectorId, ids: tokenIDs, price: UFix64(tokenIDs.length) * price)
        }

        pub fun purchase(tokenIDs: [UInt32], recipient: &AnyResource{TheMasterPixelContract.TheMasterSectorsInterface}, vaultRef: &AnyResource{FungibleToken.Provider}) {
            var totalPrice: UFix64 = 0.0

            let sectorsRef = (self.sectorsRef.borrow()!)
            let sectorRef : &TheMasterPixelContract.TheMasterSector = sectorsRef.getSectorRef(sectorId: self.sectorId)
            let recipientSectorRef : &TheMasterPixelContract.TheMasterSector = recipient.getSectorRef(sectorId: self.sectorId)

            TheMasterPieceContract.setSaleSize(sectorId: self.sectorId, address: (self.owner!).address, size: UInt16(self.prices.length - tokenIDs.length))
            TheMasterPieceContract.setWalletSize(sectorId: self.sectorId, address: (recipient.owner!).address, size: UInt16(recipientSectorRef.getIds().length + tokenIDs.length))

            for tokenID in tokenIDs {
              recipientSectorRef.deposit(id: tokenID)
              totalPrice = totalPrice + self.prices.remove(key: tokenID)!
            }

            (self.creatorVault.borrow()!).deposit(from: <- vaultRef.withdraw(amount: totalPrice * 0.025))
            (self.ownerVault.borrow()!).deposit(from: <- vaultRef.withdraw(amount: totalPrice * 0.975))

            emit TokenPurchased(sectorId: self.sectorId, ids: tokenIDs, price: totalPrice)
        }

        pub fun cancelListForSale(tokenIDs: [UInt32]) {
            let sectorsRef = (self.sectorsRef.borrow()!)
            let sectorRef : &TheMasterPixelContract.TheMasterSector = sectorsRef.getSectorRef(sectorId: self.sectorId)

            TheMasterPieceContract.setSaleSize(sectorId: self.sectorId, address: (self.owner!).address, size: UInt16(self.prices.length - tokenIDs.length))
            TheMasterPieceContract.setWalletSize(sectorId: self.sectorId, address: (self.owner!).address, size: UInt16(sectorRef.getIds().length + tokenIDs.length))

            for tokenID in tokenIDs {
              sectorRef.deposit(id: tokenID)
              self.prices.remove(key: tokenID)
            }
        }

        pub fun idPrice(tokenID: UInt32): UFix64? {
            return self.prices[tokenID]
        }

        pub fun getPrices(): {UInt32: UFix64} {
            return self.prices
        }

        destroy() {
            destroy self.forSale
        }
    }

    // ########################################################################################

    pub resource interface TheMasterMarketInterface {
        pub fun purchase(sectorId: UInt16, tokenIDs: [UInt32], recipient: &AnyResource{TheMasterPixelContract.TheMasterSectorsInterface}, vaultRef: &AnyResource{FungibleToken.Provider})
        pub fun getPrices(sectorId: UInt16): {UInt32: UFix64}
    }

    pub resource TheMasterMarket: TheMasterMarketInterface {
        priv var saleSectors: @{UInt16: TheMasterMarketSector}

        access(account) let ownerVault: Capability<&AnyResource{FungibleToken.Receiver}>
        access(account) let creatorVault: Capability<&AnyResource{FungibleToken.Receiver}>
        access(account) let sectorsRef: Capability<&TheMasterPixelContract.TheMasterSectors>

        init (sectorsRef: Capability<&TheMasterPixelContract.TheMasterSectors>) {
            self.saleSectors <- {}
            self.ownerVault = getAccount(sectorsRef.address).getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            self.creatorVault  =  getAccount(TheMasterPieceContract.getAddress()).getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            self.sectorsRef = sectorsRef
        }

        pub fun listForSale(sectorId: UInt16, tokenIDs: [UInt32], price: UFix64) {
            if self.saleSectors[sectorId] == nil {
                self.saleSectors[sectorId] <-! create TheMasterMarketSector(sectorId: sectorId, ownerVault: self.ownerVault, creatorVault: self.creatorVault, sectorsRef: self.sectorsRef)
            }
            ((&(self.saleSectors[sectorId]) as &TheMasterMarketSector?)!).listForSale(tokenIDs: tokenIDs, price: price)
        }

        pub fun purchase(sectorId: UInt16, tokenIDs: [UInt32], recipient: &AnyResource{TheMasterPixelContract.TheMasterSectorsInterface}, vaultRef: &AnyResource{FungibleToken.Provider}) {
            ((&self.saleSectors[sectorId] as &TheMasterMarketSector?)!).purchase(tokenIDs: tokenIDs, recipient: recipient, vaultRef: vaultRef)
        }

        pub fun cancelListForSale(sectorId: UInt16, tokenIDs: [UInt32]) {
            if self.saleSectors[sectorId] != nil {
              ((&self.saleSectors[sectorId] as &TheMasterMarketSector?)!).cancelListForSale(tokenIDs: tokenIDs)
            }
        }

        pub fun getPrices(sectorId: UInt16): {UInt32: UFix64} {
            if (self.saleSectors.containsKey(sectorId)) {
              return ((&(self.saleSectors[sectorId]) as &TheMasterMarketSector?)!).getPrices()
            } else {
              return {}
            }
        }

        destroy() {
            destroy self.saleSectors
        }
    }

    // ########################################################################################

    pub resource interface TheMasterMarketStateInterface {
      pub fun isOpened(): Bool
    }

    pub resource TheMasterMarketState: TheMasterMarketStateInterface {
      pub var opened: Bool

      init() {
          self.opened = false
      }

      pub fun setOpened(state: Bool) {
          self.opened = state
      }

      pub fun isOpened(): Bool {
          return self.opened
      }
    }
}
