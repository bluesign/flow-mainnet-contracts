import TopShot from 0x0b2a3299cc857e29
import Ashes from 0xe2a89587100c6096
import UFC_NFT from 0x329feb3ab062d289

pub contract AshesV2 {
    access(contract) var recentBurn: [AshData?]
    pub var nextAshSerial: UInt64
    pub var allowMint: Bool
    pub var maxMessageSize: Int

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath


    // admin events
    pub event AllowMintToggled(allowMint: Bool)

    // nft events
    pub event AshMinted(id: UInt64, ashSerial: UInt64, nftType: Type, nftID: UInt64, ashMeta: {String:String})
    pub event AshDestroyed(id: UInt64)

    // Ash Collection events
    pub event AshWithdrawn(id: UInt64, from: Address?)
    pub event AshDeposited(id: UInt64, to: Address?)

    // Declare the NFT resource type
    pub struct AshData {
       pub let meta: {String: String}
       pub let ashSerial: UInt64
       pub let nftType: Type
       pub let nftID: UInt64

       init(ashSerial: UInt64, nftType: Type, nftID: UInt64, ashMeta: {String:String}) {
        ashMeta["_burnedAtTimestamp"] = getCurrentBlock().timestamp.toString()
        ashMeta["_burnedAtBlockheight"] = getCurrentBlock().height.toString()
        self.meta = ashMeta
        self.ashSerial = ashSerial
        self.nftType = nftType
        self.nftID = nftID
       }
    }

    pub fun getRecentBurn(index: Int): AshData?{
        return self.recentBurn[index]
    }

    priv fun addRecentBurn(ashData: AshData) {
       self.recentBurn.append(ashData)
    }

    priv fun setRecentBurn(ashData: AshData, index: Int) {
        self.recentBurn[index] = ashData
    }

    pub resource Ash {
        pub let data: AshData

        init(nftType: Type, nftID: UInt64, ashMeta: {String:String}, serial: UInt64, overwriteSerial: Bool) {
            if !AshesV2.allowMint {
                panic("minting is closed")
            }

            if let msg = ashMeta["_message"] {
                if msg!.length > AshesV2.maxMessageSize {
                   panic("message exceeds max size")
                }
            }

            var ashSerial =  AshesV2.nextAshSerial

            if overwriteSerial {
                ashSerial = serial
            } else {
                ashSerial = AshesV2.nextAshSerial
                AshesV2.nextAshSerial = AshesV2.nextAshSerial + 1
            }

            let ashData = AshData(ashSerial: ashSerial, nftType: nftType, nftID: nftID, ashMeta: ashMeta)
            self.data = ashData

            emit AshMinted(id: self.uuid, ashSerial: ashData.ashSerial, nftType: ashData.nftType, nftID: ashData.nftID, ashMeta: ashData.meta)

            if overwriteSerial {
                AshesV2.setRecentBurn(ashData: ashData, index: Int(ashSerial-1))
            } else {
                AshesV2.addRecentBurn(ashData: ashData)
            }

        }

        destroy() {
            emit AshDestroyed(id: self.uuid)
        }
    }

    // We define this interface purely as a way to allow users
    // to create public, restricted references to their NFT Collection.
    // They would use this to only expose the deposit, getIDs,
    // and idExists fields in their Collection
    pub resource interface AshReceiver {

        pub fun deposit(token: @Ash)

        pub fun getIDs(): [UInt64]

        pub fun idExists(id: UInt64): Bool

        pub fun borrowAsh(id: UInt64): &Ash? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.uuid == id):
                    "Cannot borrow ash reference: The ID of the returned reference is incorrect"
            }
        }

    }


    // The definition of the Collection resource that
    // holds the NFTs that a user owns
    pub resource Collection: AshReceiver {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: Ash}

        // Initialize the NFTs field to an empty collection
        init () {
            self.ownedNFTs <- {}
        }

        // withdraw
        //
        // Function that removes an NFT from the collection
        // and moves it to the calling context
        pub fun withdraw(withdrawID: UInt64): @Ash {
            // If the NFT isn't found, the transaction panics and reverts
            let token <- self.ownedNFTs.remove(key: withdrawID)!
            emit AshWithdrawn(id: token.uuid, from: self.owner?.address)
            return <-token
        }

        // deposit
        //
        // Function that takes a NFT as an argument and
        // adds it to the collections dictionary
        pub fun deposit(token: @Ash) {
            // add the new token to the dictionary with a force assignment
            // if there is already a value at that key, it will fail and revert
            emit AshDeposited(id: token.uuid, to: self.owner?.address)
            self.ownedNFTs[token.uuid] <-! token
        }

        // idExists checks to see if a NFT
        // with the given ID exists in the collection
        pub fun idExists(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowAsh(id: UInt64): &Ash? {
            return &self.ownedNFTs[id] as! &Ash
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // creates a new empty Collection resource and returns it
    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun mintFromTopShot(topshotNFT: @TopShot.NFT, msg: String): @Ash {
        let ashMeta: {String:String} = {}
        ashMeta["_message"] = msg
        ashMeta["topshotID"] = topshotNFT.id.toString()
        ashMeta["topshotSerial"] = topshotNFT.data.serialNumber.toString()
        ashMeta["topshotSetID"] = topshotNFT.data.setID.toString()
        ashMeta["topshotPlayID"] = topshotNFT.data.playID.toString()

        let res <- create Ash(nftType: topshotNFT.getType(), nftID: topshotNFT.uuid, ashMeta: ashMeta, serial: 0, overwriteSerial: false)
        destroy topshotNFT
        return <-res
    }

    pub fun mintFromVanillaAshes(vanillaAshNFT: @Ashes.Ash, msg: String): @Ash {
        let ashMeta: {String:String} = {}
        ashMeta["_message"] = msg
        ashMeta["vanillaAshTopshotID"] = vanillaAshNFT.id.toString()
        ashMeta["vanillaAshTopshotSerial"] = vanillaAshNFT.momentData.serialNumber.toString()
        ashMeta["vanillaAshTopshotSetID"] = vanillaAshNFT.momentData.setID.toString()
        ashMeta["vanillaAshTopshotPlayID"] = vanillaAshNFT.momentData.playID.toString()

        let res <- create Ash(nftType: vanillaAshNFT.getType(), nftID: vanillaAshNFT.uuid, ashMeta: ashMeta, serial: vanillaAshNFT.ashSerial, overwriteSerial: true)
        destroy vanillaAshNFT
        return <-res
    }

    pub fun mintFromUFCStrike(ufcNFT: @UFC_NFT.NFT, msg: String): @Ash {
        let ashMeta: {String:String} = {}
        ashMeta["_message"] = msg
        ashMeta["ufcID"] = ufcNFT.id.toString()
        ashMeta["ufcSetID"] = ufcNFT.setId.toString()
        ashMeta["ufcEditionNum"] = ufcNFT.editionNum.toString()

        let res <- create Ash(nftType: ufcNFT.getType(), nftID: ufcNFT.uuid, ashMeta: ashMeta, serial: 0, overwriteSerial: false)
        destroy ufcNFT
        return <-res
    }

    pub resource Admin {
        pub fun createAdmin(): @Admin {
            return <- create Admin()
        }

        pub fun toggleAllowMint(allowMint: Bool) {
            AshesV2.allowMint = allowMint
            emit AllowMintToggled(allowMint: allowMint)
        }
    }


    init() {
        // Set named paths
        self.CollectionStoragePath = /storage/AshesV2CollectionV2
        self.CollectionPublicPath = /public/AshesV2CollectionV2
        self.AdminStoragePath = /storage/AshesV2AdminV2
        self.AdminPrivatePath = /private/AshesV2AdminV2

        self.nextAshSerial = Ashes.nextAshSerial
        self.allowMint = false
        self.maxMessageSize = 420

        self.recentBurn = []

        var i = UInt64(1)
        while i < self.nextAshSerial {
            self.recentBurn.append(nil)
            i = i + 1
        }

        self.account.save<@Admin>(<- create Admin(), to: self.AdminStoragePath)
    }

}