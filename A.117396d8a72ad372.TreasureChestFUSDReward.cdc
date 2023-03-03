// FUSD Reward for claiming The Inspected Treasure Chest
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import NFTDayTreasureChest from 0x117396d8a72ad372

pub contract TreasureChestFUSDReward {
    
    // -----------------------------------------------------------------------
    // TreasureChestFUSDReward Events
    // -----------------------------------------------------------------------
    pub event BonusAdded(wallet: Address, amount: UFix64, bonus: String)
    pub event RewardClaimed(wallet: Address, reward: UFix64)
    pub event AdminRewardReclaim(chestID: UInt64, rewardAmount: UFix64)
    pub event RewardCreated(chestID: UInt64)

    // -----------------------------------------------------------------------
    // Named Paths
    // -----------------------------------------------------------------------
    pub let CentralizedInboxStoragePath: StoragePath
    pub let CentralizedInboxPrivatePath: PrivatePath
    pub let CentralizedInboxPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // TreasureChestFUSDReward Fields
    // -----------------------------------------------------------------------

    pub resource interface Public {
        pub fun getClaimed(): {UInt64: Address}
        pub fun getChestIDs(): [UInt64]
        pub fun getBonusRewards(): {Address: String}
        pub fun addBonus(wallet: Address, amount: UFix64)
        pub fun claimReward(recipient: &FUSD.Vault{FungibleToken.Receiver}, chest: @NFTDayTreasureChest.NFT): @NFTDayTreasureChest.NFT
    }

    pub resource CentralizedInbox: Public {
        // List of claimed chests and which address claimed it
        access(self) var claimed: {UInt64: Address}
        // The chest and the vault with the reward amount
        access(self) var rewards: @{UInt64: FUSD.Vault}
        // List of addresses and their bonus rewards
        access(self) var bonusRewards: {Address: String}

        init() {
            self.claimed = {}
            self.rewards <- {}
            self.bonusRewards = {}
            
        }

        pub fun getClaimed(): {UInt64: Address} {
            return self.claimed
        }

        pub fun getChestIDs(): [UInt64] {
            return self.rewards.keys
        }

        pub fun getBonusRewards(): {Address: String} {
            return self.bonusRewards
        }

        pub fun addBonus(wallet: Address, amount: UFix64) {
            pre {
                self.bonusRewards[wallet] == nil: "Cannot add bonus: Bonus has already been added"
            }
            var bonus = "Starter Pack"
            if(amount == 6.9) {
                bonus = "Saber Merch"
            }
            if(amount == 69.00) {
                bonus = "Cursed Black Pack"
            }
            self.bonusRewards[wallet] = bonus

            emit BonusAdded(wallet: wallet, amount: amount, bonus: bonus)
        }

        pub fun claimReward(recipient: &FUSD.Vault{FungibleToken.Receiver}, chest: @NFTDayTreasureChest.NFT): @NFTDayTreasureChest.NFT {
            pre {
                self.rewards[chest.id] != nil: "Can't claim reward: Chest doesn't have a reward to claim"
                !self.claimed.keys.contains(chest.id): "Can't claim reward: Reward from chest has already been claimed"
            }
            let wallet = recipient.owner!.address

            let vaultRef: auth &FUSD.Vault = (&self.rewards[chest.id] as auth &FUSD.Vault?)!

            let amount = vaultRef.balance

            recipient.deposit(from: <- vaultRef.withdraw(amount: vaultRef.balance))

            // Add to claimed list
            self.claimed[chest.id] = wallet

            emit RewardClaimed(wallet: wallet, reward: amount)

            return <- chest
        }

        // -----------------------------------------------------------------------
        // Admin Functions
        // -----------------------------------------------------------------------

        pub fun getBalance(chestID: UInt64): UFix64? {
            if(self.rewards[chestID] != nil) {
                let vaultRef: auth &FUSD.Vault = (&self.rewards[chestID] as auth &FUSD.Vault?)!
                return vaultRef.balance
            } else {
                return nil
            }
        }

        pub fun adminReclaimReward(chestID: UInt64, recipient: &FUSD.Vault{FungibleToken.Receiver}) {
            pre {
                self.rewards[chestID] != nil: "Can't reclaim reward: Chest doesn't have a reward to reclaim"
            }

            let vaultRef: auth &FUSD.Vault = (&self.rewards[chestID] as auth &FUSD.Vault?)!
            
            let amount = vaultRef.balance

            recipient.deposit(from: <- vaultRef.withdraw(amount: vaultRef.balance))

            emit AdminRewardReclaim(chestID: chestID, rewardAmount: amount)

        }

        pub fun createReward(chestID: UInt64, reward: @FUSD.Vault) {
            pre {
                self.rewards[chestID] == nil: "Can't create rewards: Reward has already been created"
            }
            self.rewards[chestID] <-! reward

            emit RewardCreated(chestID: chestID)
        }

        pub fun createNewCentralizedInbox(): @CentralizedInbox {
            return <-create CentralizedInbox()
        }

        destroy() {
            pre {
                self.rewards.length == 0: "Can't destroy: rewards are left in the inbox"
            }
            destroy self.rewards
        }
    }

    init() {
        // Set named paths
        self.CentralizedInboxStoragePath = /storage/BasicBeastsTreasureChestFUSDReward
        self.CentralizedInboxPrivatePath = /private/BasicBeastsTreasureChestFUSDRewardUpgrade
        self.CentralizedInboxPublicPath = /public/BasicBeastsTreasureChestFUSDReward

        // Put CentralizedInbox in storage
        self.account.save(<-create CentralizedInbox(), to: self.CentralizedInboxStoragePath)

        self.account.link<&TreasureChestFUSDReward.CentralizedInbox>(self.CentralizedInboxPrivatePath, target: self.CentralizedInboxStoragePath) 
                                                ?? panic("Could not get a capability to the Centralized Inbox")

        self.account.link<&TreasureChestFUSDReward.CentralizedInbox{Public}>(self.CentralizedInboxPublicPath, target: self.CentralizedInboxStoragePath) 
                                                ?? panic("Could not get a capability to the Centralized Inbox")
    }
}