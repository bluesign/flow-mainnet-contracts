import Clock from 0xc73076dd06d3b5b6

// we whitelist admins here
// utilizing an admin token resource gives us the opportunity to expire a given 
// whitelisted (in admin registry) account's resource automatically and in a single place instead of adding that logic to each resource
pub contract AdminToken {

    pub var totalSupply: UInt64
    access(contract) var adminRegistry: {Address: AdminDetails} // registry of authorized Admins

    pub event ContractInitialized()
    pub event Deposit(id: UInt64, to: Address?)
    pub event AdminAdded(address: Address)
    pub event AdminRemoved(address: Address)

    pub let TokenVaultStoragePath: StoragePath
    pub let TokenVaultPublicPath: PublicPath
    pub let TokenMinterStoragePath: StoragePath
    pub let SuperAdminManagerStoragePath: StoragePath

    pub struct AdminDetails {
        pub let created: UFix64
        pub let expires: UFix64

        init (expires: UFix64) {
            self.created = Clock.getTime()
            self.expires = expires
        }
    }
    
    pub resource Token {
        pub let id: UInt64
        pub let address: Address

        init(
            id: UInt64,
            address: Address
        ) {
            self.id = id
            self.address = address
        }
    
    }

    pub resource interface AdminTokenVaultPublic {
        pub fun deposit(token: @AdminToken.Token)
    }

    pub resource TokenVault: AdminTokenVaultPublic {

        pub var adminToken: @AdminToken.Token?

        init () {
            self.adminToken <- nil
        }

        pub fun deposit(token: @AdminToken.Token) {

            let token <- token as! @AdminToken.Token

            let id: UInt64 = token.id

            let oldToken <- self.adminToken <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun borrowAdminToken(): &AdminToken.Token? {
            if self.adminToken != nil {
                let ref = (&self.adminToken as auth &AdminToken.Token?)!
                return ref
            }
            return nil
        }

        destroy() {
            destroy self.adminToken
        }
    }

    pub fun createEmptyTokenVault(): @AdminToken.TokenVault {
        return <- create TokenVault()
    }

    pub fun checkAuthorizedAdmin(_ adminTokenRef: &AdminToken.Token?) {
        pre {
            adminTokenRef != nil : "A reference to an admin token is required"
            AdminToken.adminRegistry[adminTokenRef!.owner!.address] != nil : "Admin was not found in the admin registry"
        }

        if AdminToken.adminRegistry[adminTokenRef!.owner!.address] == nil {
            panic("The address on the Admin NFT is not for a registered admin")
        }

        if AdminToken.adminRegistry[adminTokenRef!.owner!.address]!.expires <= Clock.getTime() {
            panic("Admin token is expired!")
        }

    }

    pub fun getAdminDetails(address: Address): AdminToken.AdminDetails? {
        pre {
            AdminToken.adminRegistry[address] != nil: "Admin doesn't exists"
        }

        return AdminToken.adminRegistry[address] 
    }

    pub fun getAdminRegistryKeys(): [Address] {
        return AdminToken.adminRegistry.keys
    }

    pub resource TokenMinter {

        pub fun mintToken(
            recipient: &{AdminToken.AdminTokenVaultPublic}
        ) {

            var newToken <- create Token(
                id: AdminToken.totalSupply,
                address: recipient.owner!.address
            )

            recipient.deposit(token: <-newToken)

            AdminToken.totalSupply = AdminToken.totalSupply + 1
        }

    }

    pub resource SuperAdminManager {

        pub fun addNAdmin(address: Address, expires: UFix64) {
            pre {
                AdminToken.adminRegistry[address] == nil: "Admin already exists"
            }

            AdminToken.adminRegistry.insert(key: address, AdminToken.AdminDetails(expires: expires))

            emit AdminAdded(address: address)
        }

        pub fun removeAdmin(address: Address) {
            pre {
                AdminToken.adminRegistry[address] != nil: "Admin not found"
            }

            AdminToken.adminRegistry.remove(key: address)

            emit AdminRemoved(address: address)

        }
    }

    init() {
        self.totalSupply = 0
        self.adminRegistry = {}

        self.TokenVaultStoragePath = /storage/kissoAdminTokenTokenVault
        self.TokenVaultPublicPath = /public/kissoAdminTokenTokenVault
        self.TokenMinterStoragePath = /storage/kissoAdminTokenMinter
        self.SuperAdminManagerStoragePath = /storage/kissoSuperAdminManager

        let superAdminManager <- create SuperAdminManager()
        self.account.save(<- superAdminManager, to: self.SuperAdminManagerStoragePath)

        let tokenMinter <- create TokenMinter()
        self.account.save(<-tokenMinter, to: self.TokenMinterStoragePath)

        emit ContractInitialized()
    }
}
