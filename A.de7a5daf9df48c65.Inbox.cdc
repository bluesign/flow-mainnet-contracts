import NonFungibleToken from 0x1d7e57aa55817448
import Pack from 0xde7a5daf9df48c65

// Purpose: This Inbox contract allows the admin to send pack NFTs to a centralized inbox held by the admin.
// This allows the recipients to claim their packs at any time.

pub contract Inbox {
    
    // -----------------------------------------------------------------------
    // Inbox Events
    // -----------------------------------------------------------------------
    pub event MailClaimed(address: Address, packID: UInt64)
    pub event PackMailCreated(address: Address, packIDs: [UInt64])
    pub event MailAdminClaimed(wallet: Address, packID: UInt64)

    // -----------------------------------------------------------------------
    // Named Paths
    // -----------------------------------------------------------------------
    pub let CentralizedInboxStoragePath: StoragePath
    pub let CentralizedInboxPrivatePath: PrivatePath
    pub let CentralizedInboxPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // Inbox Fields
    // -----------------------------------------------------------------------

    pub resource interface Public {
        pub fun getAddresses(): [Address]
        pub fun getIDs(wallet: Address): [UInt64]?
        pub fun borrowPack(wallet: Address, id: UInt64): &Pack.NFT{Pack.Public}?
        pub fun claimMail(recipient: &{NonFungibleToken.Receiver}, id: UInt64)
        pub fun getMailsLength(): Int
    }

    pub resource CentralizedInbox: Public {
        access(self) var mails: @{Address: Pack.Collection}

        init() {
            self.mails <- {}
        }

        pub fun getAddresses(): [Address] {
            return self.mails.keys
        }

        pub fun getIDs(wallet: Address): [UInt64]? {
            if(self.mails[wallet] != nil) {
                let collectionRef = (&self.mails[wallet] as auth &Pack.Collection?)!
                return collectionRef.getIDs()
            } else {
                return nil
            }
        }

        pub fun borrowPack(wallet: Address, id: UInt64): &Pack.NFT{Pack.Public}? {
            let collectionRef = (&self.mails[wallet] as auth &Pack.Collection?)!
            return collectionRef.borrowPack(id: id)
        }

        pub fun claimMail(recipient: &{NonFungibleToken.Receiver}, id: UInt64) {
            let wallet = recipient.owner!.address

            if(self.mails[wallet] != nil) {
                let collectionRef = (&self.mails[wallet] as auth &Pack.Collection?)!
                recipient.deposit(token: <-collectionRef.withdraw(withdrawID: id))
            }

            emit MailClaimed(address: wallet, packID: id)

        }

        pub fun getMailsLength(): Int {
            return self.mails.length
        }

        pub fun createPackMail(wallet: Address, packs: @Pack.Collection) {
            let IDs = packs.getIDs()

            if (self.mails[wallet] == nil) {
                self.mails[wallet] <-! Pack.createEmptyCollection() as! @Pack.Collection
            }

            let collectionRef = (&self.mails[wallet] as auth &Pack.Collection?)!

            for id in IDs {
                collectionRef.deposit(token: <- packs.withdraw(withdrawID: id))
            }

            destroy packs

            emit PackMailCreated(address: wallet, packIDs: IDs)

        }

        pub fun adminClaimMail(wallet: Address, recipient: &{NonFungibleToken.Receiver}, id: UInt64) {
            if(self.mails[wallet] != nil) {
                let collectionRef = (&self.mails[wallet] as auth &Pack.Collection?)!
                recipient.deposit(token: <-collectionRef.withdraw(withdrawID: id))
            }

            emit MailAdminClaimed(wallet: wallet, packID: id)

        }

        pub fun createNewCentralizedInbox(): @CentralizedInbox {
            return <-create CentralizedInbox()
        }

        destroy() {
            pre {
                self.mails.length == 0: "Can't destroy: mails are left in the inbox"
            }
            destroy self.mails
        }
    }

    init() {
        // Set named paths
        self.CentralizedInboxStoragePath = /storage/BasicBeastsCentralizedInbox
        self.CentralizedInboxPrivatePath = /private/BasicBeastsCentralizedInboxUpgrade
        self.CentralizedInboxPublicPath = /public/BasicBeastsCentralizedInbox

        // Put CentralizedInbox in storage
        self.account.save(<-create CentralizedInbox(), to: self.CentralizedInboxStoragePath)

        self.account.link<&Inbox.CentralizedInbox>(self.CentralizedInboxPrivatePath, target: self.CentralizedInboxStoragePath) 
                                                ?? panic("Could not get a capability to the Centralized Inbox")

        self.account.link<&Inbox.CentralizedInbox{Public}>(self.CentralizedInboxPublicPath, target: self.CentralizedInboxStoragePath) 
                                                ?? panic("Could not get a capability to the Centralized Inbox")
    }
}
 