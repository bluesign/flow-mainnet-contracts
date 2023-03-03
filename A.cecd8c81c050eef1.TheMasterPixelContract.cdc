

import TheMasterPieceContract from 0xcecd8c81c050eef1

pub contract TheMasterPixelContract {

  // Named Paths
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let CollectionPrivatePath: PrivatePath
  pub let MinterStoragePath: StoragePath


  init() {
      // Set our named paths
      self.CollectionStoragePath = /storage/TheMasterSectors
      self.CollectionPublicPath = /public/TheMasterSectors
      self.CollectionPrivatePath = /private/TheMasterSectors
      self.MinterStoragePath = /storage/TheMasterPixelMinter

      if (self.account.borrow<&TheMasterPixelMinter>(from: self.MinterStoragePath) == nil && self.account.borrow<&TheMasterSectors>(from: self.CollectionStoragePath) == nil) {
        self.account.save(<-create TheMasterPixelMinter(), to: self.MinterStoragePath)

        self.account.save(<-self.createEmptySectors(), to: self.CollectionStoragePath)
        self.account.link<&{TheMasterSectorsInterface}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        self.account.link<&TheMasterSectors>(self.CollectionPrivatePath, target: self.CollectionStoragePath)
      }
  }

  // ########################################################################################

  pub resource TheMasterPixel {
    pub let id: UInt32

    init(id: UInt32) {
      self.id = id
    }

    destroy() {
    }
  }


  pub resource TheMasterPixelMinter {
      init() {
      }

      pub fun mintTheMasterPixel(theMasterSectorsRef: &TheMasterPixelContract.TheMasterSectors, pixels: {UInt32: UInt32}, sector: UInt16) {
        let sectorRef = theMasterSectorsRef.getSectorRef(sectorId: sector)

        for id in pixels.keys {
          sectorRef.deposit(id: id)
          sectorRef.setColor(id: id, color: pixels[id]!)
        }

        TheMasterPieceContract.setWalletSize(sectorId: sector, address: (self.owner!).address, size: UInt16(sectorRef.getIds().length + pixels.length))
      }
  }


  // ########################################################################################

  pub resource TheMasterSector {
    priv var ownedNFTs: @{UInt32: TheMasterPixel}
    priv var colors: {UInt32: UInt32}
    pub var id: UInt16

    init (sectorId: UInt16) {
        self.id = sectorId
        self.ownedNFTs <- {}
        self.colors = {}
    }

    access(account) fun withdraw(id: UInt32): UInt32 {
        return self.colors.remove(key: id)!
    }

    access(account) fun deposit(id: UInt32) {
        self.colors[id] = 4294967295
    }

    pub fun getColor(id: UInt32): UInt32 {
        return self.colors[id]!
    }

    pub fun getPixels() : {UInt32: UInt32} {
        return self.colors
    }

    pub fun setColor(id: UInt32, color: UInt32) {
        if (self.colors.containsKey(id)) {
          self.colors[id] = color
        }
    }

    access(account) fun setColors(colors: {UInt32: UInt32}) {
        self.colors = colors
        TheMasterPieceContract.setWalletSize(sectorId: self.id, address: (self.owner!).address, size: UInt16(colors.length))
    }

    pub fun getIds() : [UInt32] {
        return self.colors.keys
    }

    destroy() {
        destroy self.ownedNFTs
    }
  }

  // ########################################################################################

  pub resource interface TheMasterSectorsInterface {
    pub fun getPixels(sectorId: UInt16) : {UInt32: UInt32}
    pub fun getIds(sectorId: UInt16) : [UInt32]
    access(account) fun getSectorRef(sectorId: UInt16) : &TheMasterSector
  }

  pub fun createEmptySectors(): @TheMasterSectors {
      return <- create TheMasterSectors()
  }

  pub resource TheMasterSectors: TheMasterSectorsInterface {
    priv var ownedSectors: @{UInt16: TheMasterSector}

    init () {
        self.ownedSectors <- {}
    }

    access(account) fun getSectorRef(sectorId: UInt16) : &TheMasterSector {
        if self.ownedSectors[sectorId] == nil {
            self.ownedSectors[sectorId] <-! create TheMasterSector(sectorId: sectorId)
        }
        return (&self.ownedSectors[sectorId] as  &TheMasterSector?)!
    }


    pub fun getPixels(sectorId: UInt16) : {UInt32: UInt32} {
        if (self.ownedSectors.containsKey(sectorId)) {
          return self.ownedSectors[sectorId]?.getPixels()!
        } else {
          return {}
        }
    }

    pub fun setColors(sectorId: UInt16, colors: {UInt32: UInt32}) {
        self.getSectorRef(sectorId: sectorId).setColors(colors: colors)
    }

    pub fun setColor(sectorId: UInt16, id: UInt32, color: UInt32) {
        if (self.ownedSectors.containsKey(sectorId)) {
            self.ownedSectors[sectorId]?.setColor(id: id, color: color)!
        }
    }

    pub fun getIds(sectorId: UInt16) : [UInt32] {
        if (self.ownedSectors.containsKey(sectorId)) {
          return self.ownedSectors[sectorId]?.getIds()!
        } else {
          return []
        }
    }

    destroy() {
        destroy self.ownedSectors
    }
  }

}
