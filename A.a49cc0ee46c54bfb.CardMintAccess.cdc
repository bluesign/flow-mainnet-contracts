import MotoGPCard from 0xa49cc0ee46c54bfb
import MotoGPAdmin from 0xa49cc0ee46c54bfb
import ContractVersion from 0xa49cc0ee46c54bfb

pub contract CardMintAccess: ContractVersion {

    pub fun getVersion(): String {
        return "1.0.0"
    }

    pub resource interface MintProxyPublic {
        pub fun setCapability(mintCapability: Capability<&MintGuard{MintGuardPrivate}>)
        pub fun getMax(): UInt64 
        pub fun getTotal(): UInt64
    }

    pub resource interface MintProxyPrivate {
        pub fun mint(cardID: UInt64, serial: UInt64): @MotoGPCard.NFT
    }

    pub resource MintProxy: MintProxyPublic, MintProxyPrivate { 

        pub var mintCapability: Capability<&MintGuard{MintGuardPrivate}>?

        pub fun getMax(): UInt64 {
            return self.mintCapability!.borrow()!.max
        }

        pub fun getTotal(): UInt64 {
            return self.mintCapability!.borrow()!.total
        }

        // Can be called successfully only by a MintGuard owner, since the Capability type is based on a private link
        pub fun setCapability(mintCapability: Capability<&MintGuard{MintGuardPrivate}>){
            pre {
                mintCapability.check() == true : "mintCapability.check() is false"
            }
            self.mintCapability = mintCapability
        }

        pub fun mint(cardID: UInt64, serial: UInt64): @MotoGPCard.NFT {
            return <- self.mintCapability!.borrow()!.mint(cardID: cardID, serial: serial)
        }

        init() {
            self.mintCapability = nil
        }
    }

    pub resource interface MintGuardPrivate {
        pub fun mint(cardID: UInt64, serial: UInt64): @MotoGPCard.NFT
        pub var total: UInt64
        pub var max: UInt64
    }

    pub resource interface MintGuardPublic {
        pub fun getTotal(): UInt64
        pub fun getMax(): UInt64
    }

    pub resource MintGuard: MintGuardPrivate, MintGuardPublic {
        
        // max is the largest total amount that can be withdrawn using the VaultGuard
        //
        pub var max: UInt64
        
        // total keeps track of how many cards have been minted via the VaultGuard
        //
        pub var total: UInt64

        pub fun getTotal(): UInt64 {
            return self.total
        }

        pub fun getMax(): UInt64 {
            return self.max
        }

        pub fun mint(cardID: UInt64, serial: UInt64): @MotoGPCard.NFT {
            // check authoried amount
            pre {
                (self.total + UInt64(1)) <= self.max : "total of amount + previously withdrawn exceeds max withdrawal."
            }
            self.total = self.total + UInt64(1)
            // No need for a capability access, can use direct contract access, since createNFT is account-scoped
            return <- MotoGPCard.createNFT(cardID: cardID, serial: serial)
        }

        // Setter using a MotoGPAdmin.Admin lock to set the max for a mint guard
        //
        pub fun setMax(adminRef: &MotoGPAdmin.Admin, max: UInt64) {
            self.max = max
        }

        // constructor - takes a max mint amount
        //
        init(max: UInt64) {
            self.max = max
            self.total = UInt64(0)
        }
    }

    pub enum MintObjectType: UInt8 {
        pub case MintGuard
        pub case MintProxy
    }

    pub enum PathType: UInt8 {
        pub case StorageType
        pub case PrivateType
        pub case PublicType
    }

    pub var pathIndex:UInt64
    pub let pathIndexToAddressMap:{UInt64:Address}
    pub let addressToPathIndexMap:{Address:UInt64}
    pub let whitelisted:{Address:Bool}
    pub let mintGuardPathPrefix:String 
    pub let mintProxyPathPrefix:String

    pub fun createMintGuard(adminRef: &MotoGPAdmin.Admin, targetAddress: Address, max: UInt64) {
        pre {
            adminRef != nil : "adminRef ref is nil"
            self.addressToPathIndexMap[targetAddress] == nil : "A mint guard has already been created for that target address"
        }
        self.pathIndex = self.pathIndex + 1
        self.pathIndexToAddressMap[self.pathIndex] =  targetAddress
        self.addressToPathIndexMap[targetAddress] = self.pathIndex

        let mintGuard <- create MintGuard(max: max)
        let storagePath = self.getStoragePath(address: targetAddress, objectType: MintObjectType.MintGuard)!
        let privatePath = self.getPrivatePath(address: targetAddress, objectType: MintObjectType.MintGuard)!
        let publicPath = self.getPublicPath(address: targetAddress, objectType: MintObjectType.MintGuard)!
        self.account.save(<- mintGuard, to: storagePath)
        self.account.link<&MintGuard{MintGuardPrivate}>(privatePath, target: storagePath)
        self.account.link<&MintGuard{MintGuardPublic}>(publicPath, target: storagePath)
        self.whitelisted[targetAddress] = true
    }

    pub fun createMintProxy(authAccount: AuthAccount) {
        pre {
            self.whitelisted[authAccount.address] == true : "authAccount.address is not whitelisted"
        }
        
        let mintProxy <- create MintProxy()
        let address = authAccount.address!
        let storagePath = self.getStoragePath(address: address, objectType: MintObjectType.MintProxy)
        let privatePath = self.getPrivatePath(address: address, objectType: MintObjectType.MintProxy)
        let publicPath = self.getPublicProxyPath(address: address)
        authAccount.save(<- mintProxy, to: storagePath)
        authAccount.link<&MintProxy{MintProxyPrivate}>(privatePath, target: storagePath)
        authAccount.link<&MintProxy{MintProxyPublic}>(publicPath, target: storagePath)
    }

    // Getter function to get storage MintGuard or MintProxy path for address
    //
    pub fun getStoragePath(address: Address, objectType: MintObjectType): StoragePath {
        let index = self.addressToPathIndexMap[address]!
        let identifier = objectType == MintObjectType.MintGuard ? self.mintGuardPathPrefix : self.mintProxyPathPrefix
        return StoragePath(identifier: identifier.concat(index.toString()))!  
    }

    // Getter function to get private MintGuard or MintProxy path for address
    //
    pub fun getPrivatePath(address: Address, objectType: MintObjectType): PrivatePath {
        let index = self.addressToPathIndexMap[address]!
        let identifier = objectType == MintObjectType.MintGuard ? self.mintGuardPathPrefix : self.mintProxyPathPrefix
        return PrivatePath(identifier: identifier.concat(index.toString()))!  
    }

    // Getter function to get public MintProxy path for address (mapped to index)
    // Always returns the Proxy path, since VaultGuards don't have a public path
    //
    pub fun getPublicProxyPath(address: Address): PublicPath {
        let index = self.addressToPathIndexMap[address]!
        return PublicPath(identifier: self.mintProxyPathPrefix.concat(index.toString()))!  
    }

    pub fun getPublicPath(address: Address, objectType: MintObjectType): PublicPath {
        let index = self.addressToPathIndexMap[address]!
        let identifier = objectType == MintObjectType.MintGuard ? self.mintGuardPathPrefix : self.mintProxyPathPrefix
        return PublicPath(identifier: identifier.concat(index.toString()))!
    }

    init() {
        self.mintGuardPathPrefix = "cardMintGuard"
        self.mintProxyPathPrefix = "cardMintProxy"
        self.pathIndex = 0;
        self.pathIndexToAddressMap = {}
        self.addressToPathIndexMap = {}
        self.whitelisted = {}
    }
}