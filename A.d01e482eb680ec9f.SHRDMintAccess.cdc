import SHRD from 0xd01e482eb680ec9f

pub contract SHRDMintAccess {

    pub fun getVersion(): String {
        return "1.0.0"
    }

    // Interface to allow the MintGuard owner to enable minting on another account's MintProxy
    //
    pub resource interface MintProxyPublic {
        pub fun setCapability(mintCapability: Capability<&MintGuard{MintGuardPrivate}>)
        pub fun getMax(): UFix64 
        pub fun getTotal(): UFix64 
    }

    // Interface to allow a contract to mint SHRD by holding a capability, while keeping the link private to not expose the minting function publicly
    //
    pub resource interface MintProxyPrivate {
        pub fun mint(amount: UFix64): @SHRD.Vault
    }

    pub resource MintProxy: MintProxyPublic, MintProxyPrivate {

        pub var mintCapability: Capability<&MintGuard{MintGuardPrivate}>?

        pub fun getMax(): UFix64 {
            return self.mintCapability!.borrow()!.max
        }

        pub fun getTotal(): UFix64 {
            return self.mintCapability!.borrow()!.total
        }

        // Can be called successfully only by a MintGuard owner, since the Capability type is based on a private link
        pub fun setCapability(mintCapability: Capability<&MintGuard{MintGuardPrivate}>){
            pre {
                mintCapability.check() == true : "mintCapability.check() is false"
            }
            self.mintCapability = mintCapability
        }

        pub fun mint(amount: UFix64): @SHRD.Vault {
            return <- self.mintCapability!.borrow()!.mint(amount: amount)
        }

        init() {
            self.mintCapability = nil
        }

    }

    // MintGuardPrivate
    // Use as interface for a link
    //
    pub resource interface MintGuardPrivate {
        pub fun mint(amount: UFix64): @SHRD.Vault
        pub var total: UFix64
        pub var max: UFix64
    }

    pub resource interface MintGuardPublic {
        pub fun getTotal(): UFix64
        pub fun getMax(): UFix64
    }

    // MintGuard
    //
    // The MintGuard's role is to be the source of a revokable link to the account's SHRD contract' mint function.
    //
    pub resource MintGuard: MintGuardPrivate, MintGuardPublic {
        
        // max is the largest total amount that can be withdrawn using the VaultGuard
        //
        pub var max: UFix64
        
        // total keeps track of how much has been withdrawn via the VaultGuard
        //
        pub var total: UFix64

        access(self) let mintCapability: Capability<&SHRD.SHRDMinter{SHRD.SHRDMinterPrivate}>

        pub fun getTotal(): UFix64 {
            return self.total
        }

        pub fun getMax(): UFix64 {
            return self.max
        }

        // mint - part of private interface. Should never be exposed publicly
        //
        pub fun mint(amount: UFix64): @SHRD.Vault {
            // check authoried amount
            pre {
                (amount + self.total) <= self.max : "Total of amount + previously withdrawn exceeds max (".concat(self.max.toString()).concat(") withdrawal.")
            }
            self.total = self.total + amount
            return <- self.mintCapability.borrow()!.mint(amount: amount)
        }

        // Setter using a SHRDMintAccess.Admin lock to set the max for a mint guard
        //
        pub fun setMax(adminRef: &Admin, max: UFix64) {
            self.max = max
        }

        // constructor - takes a SHRDMinter vault reference, and a max mint amount
        //
        init(privateMintCapability: Capability<&SHRD.SHRDMinter{SHRD.SHRDMinterPrivate}>, max: UFix64) {
            pre {
                privateMintCapability != nil : "privateMintCapability is nil in SHRDMintAccess.MintGuard init"
            }
            self.mintCapability = privateMintCapability
            self.max = max
            self.total = UFix64(0.0)
        }
    }

    // Admin resource
    //
    pub resource Admin { }

    pub enum MintObjectType: UInt8 {
        pub case MintGuard
        pub case MintProxy
    }

    pub enum PathType: UInt8 {
        pub case StorageType
        pub case PrivateType
        pub case PublicType
    }

    pub let AdminStoragePath: StoragePath

    pub var pathIndex:UInt64
    pub let pathIndexToAddressMap:{UInt64:Address}
    pub let addressToPathIndexMap:{Address:UInt64}
    pub let whitelisted:{Address:Bool}
    pub let mintGuardPathPrefix:String 
    pub let mintProxyPathPrefix:String

    pub fun createMintGuard(adminRef: &Admin, privateMintCapability: Capability<&SHRD.SHRDMinter{SHRD.SHRDMinterPrivate}>, targetAddress: Address, max: UFix64) {
        pre {
            adminRef != nil : "adminRef ref is nil"
            self.addressToPathIndexMap[targetAddress] == nil : "A mint guard has already been created for that target address"
        }
        
        self.pathIndex = self.pathIndex + 1
        self.pathIndexToAddressMap[self.pathIndex] =  targetAddress
        self.addressToPathIndexMap[targetAddress] = self.pathIndex

        let mintGuard <- create MintGuard(privateMintCapability: privateMintCapability, max: max)
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
        self.mintGuardPathPrefix = "shrdMintGuard"
        self.mintProxyPathPrefix = "shrdMintProxy"
        self.pathIndex = 0;
        self.pathIndexToAddressMap = {}
        self.addressToPathIndexMap = {}
        self.whitelisted = {}
        self.AdminStoragePath = /storage/shrdMinterAccessAdmin
        self.account.save(<- create Admin(), to: self.AdminStoragePath)
    }
}