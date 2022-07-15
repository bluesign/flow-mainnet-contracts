import FungibleToken from 0xf233dcee88fe0abe
import JoyrideMultiToken from 0xecfad18ba9582d4f

pub contract JoyrideAccounts {

    access(contract) var gameToDeveloperAccount : {String: Address}
    access(contract) var playerIDToPlayer : {String: Address}
    access(contract) var treasuryCapability : Capability<&JoyrideMultiToken.PlatformAdmin>?
    access(contract) var playerAccounts : @{String: PlayerAccount}
    access(contract) var playerIdByAddress : {Address: String}

    pub event AccountCreated(playerID: String, referralID: String?, accountAddress: Address)
    pub event LinkDeveloperAccount(accountAddress: Address, gameID: String)
    pub event AccountAlreadyExists(playerID: String, accountAddress: Address)
    pub event InsufficientBalance(playerID: String, txID: String, amount: UFix64, currentBalance: UFix64)
    init() {
        self.playerIDToPlayer = {}
        self.gameToDeveloperAccount = {}
        self.playerAccounts <- {}
        self.treasuryCapability = nil
        self.playerIdByAddress = {}

        self.account.save(<- create JoyrideAccountsAdmin(), to: /storage/JoyrideAccountsAdmin)
        let cap = self.account.link<&JoyrideAccountsAdmin{GrantsTokenRewards, SharesProfits, PlayerAccounts}>(/private/JoyrideAccountsAdmin, target: /storage/JoyrideAccountsAdmin)
    }

    //Pretty sure this is safe to be public, since a valid Capability<&{JRXToken.Treasury}> can only be created by the JRXToken contract account.
    pub fun linkTreasuryCapability(treasuryCapability: Capability<&JoyrideMultiToken.PlatformAdmin>) {
        if(!treasuryCapability.check()) {panic("Capability from Invalid Source")}
        self.treasuryCapability = treasuryCapability
    }

    pub fun PlayerRegisterCapability(capability:Capability<&JoyrideMultiToken.Vault>) {
        let playerID = JoyrideAccounts.playerIdByAddress[capability.address] ?? panic("PlayerID not Found by Address")
        let playerAccount <- JoyrideAccounts.playerAccounts.remove(key: playerID)  ?? panic("PlayerID not found in JoyrideAccounts")
        playerAccount.RegisterVaultCapability(capability: capability)
        destroy JoyrideAccounts.playerAccounts.insert(key: playerID, <-playerAccount)
	}

    pub fun getPlayerAccount(playerID: String) : PublicAccount {
        if(self.playerIDToPlayer[playerID] == nil) { panic("Player not found for playerID: ".concat(playerID)) }
        return getAccount(self.playerIDToPlayer[playerID]!)
    }

    pub resource interface ReceivesPlayerRewards {
        access(contract) fun ReceiveRewards(totalRewards: UFix64, rewardID: String, tokenContext: String) : Bool
    }

    pub resource PlayerAccount : ReceivesPlayerRewards {
        pub let playerID: String
        pub var accountAddress: Address?
        access(self) var vaultCapability: Capability<&JoyrideMultiToken.Vault>?

        init(playerID: String, referralID: String?) {
            self.playerID = playerID
            self.accountAddress = nil
            self.vaultCapability = nil
        }

        access(contract) fun ReceiveRewards(totalRewards: UFix64, rewardID: String, tokenContext: String) : Bool {
            if(self.vaultCapability == nil || JoyrideAccounts.treasuryCapability == nil) { return false }

            let playerVault = self.vaultCapability!.borrow()
            let treasury = JoyrideAccounts.treasuryCapability!.borrow()
            if(playerVault == nil || treasury == nil) { return false }

            let rewardVault <- treasury!.withdraw(vault: JoyrideMultiToken.Vaults.treasury, tokenContext: tokenContext, amount: totalRewards, purpose: rewardID)
            if(rewardVault == nil) {
                destroy rewardVault
                return false
            }
            else {
                playerVault!.depositToken(from: <-rewardVault!)
                return true
            }
        }

        //This must be called if the resource is ever transfered to another account.
        access(contract) fun AssociatePaymentAddress(address: Address) {
            JoyrideAccounts.playerIDToPlayer[self.playerID] = address
            self.accountAddress = address
            JoyrideAccounts.playerIdByAddress[address] = self.playerID
        }

        access(contract) fun WithdrawTokensForPayment(playerID: String, txID: String, amount: UFix64, tokenContext: String): @FungibleToken.Vault? {
            if(self.vaultCapability == nil) {
                return nil
            }

            let vault = self.vaultCapability!.borrow()
            if(vault == nil) {
                return nil
            }
            let currentBalance: UFix64 = vault?.balanceOf(tokenContext: tokenContext) ?? 0.0;
            if(currentBalance < amount){
                emit InsufficientBalance(playerID:playerID, txID:txID, amount:amount, currentBalance:currentBalance)
                return nil;
            }

            let withdrawal <- vault?.withdrawToken(tokenContext: tokenContext, amount: amount)
            if(withdrawal?.balance != amount) {
                destroy <- withdrawal!
                return nil
            } else {
                return <- withdrawal
            }
        }

        access(contract) fun DepositTokens(vault: @FungibleToken.Vault) {
            let playerVault = (self.vaultCapability ?? panic("No Capability Registered")).borrow() ?? panic("Capability could not be borrowed!")
            playerVault.depositToken(from: <- vault)
        }

        access(contract) fun RegisterVaultCapability(capability:Capability<&JoyrideMultiToken.Vault>) {
            if(capability.address != self.accountAddress) {panic("Cannot register capability to incorrect address")}
            self.vaultCapability = capability
        }
    }

    //Rewards and Payments Interfaces
    //
    //
    //

    pub resource interface GrantsTokenRewards {
        pub fun GrantTokenRewards(playerID: String, amount: UFix64, tokenContext: String, rewardID: String) : Bool
    }

    pub resource interface SharesProfits {
        pub fun ShareProfits(profits:@FungibleToken.Vault, inGameID: String, fromPlayerID: String) : @FungibleToken.Vault
    }

    pub resource interface PlayerAccounts {
         pub fun GetPlayerJRXAccount(playerID: String) : &PlayerAccount?
         pub fun AddPlayerAccount(playerID: String, referralID: String?, account: PublicAccount)
         pub fun EscrowWithdraw(playerID: String, amount:UFix64, tokenContext: String): @FungibleToken.Vault?
         pub fun PlayerDeposit(playerID: String, vault:@FungibleToken.Vault) : @FungibleToken.Vault?
         pub fun EscrowWithdrawWithTnxId(playerID: String, txID: String, amount:UFix64, tokenContext: String): @FungibleToken.Vault?
    }

    pub resource JoyrideAccountsAdmin : GrantsTokenRewards, SharesProfits, PlayerAccounts {
        pub fun GrantTokenRewards(playerID: String, amount: UFix64, tokenContext: String, rewardID: String) : Bool {
            let playerAccount <- JoyrideAccounts.playerAccounts.remove(key: playerID)
            if(playerAccount == nil) {
                destroy playerAccount
                return false
            } else {
                playerAccount?.ReceiveRewards(totalRewards: amount, rewardID: rewardID, tokenContext: tokenContext)
                destroy JoyrideAccounts.playerAccounts.insert(key: playerID, <-playerAccount!)
                return true
            }
        }

        pub fun AddPlayerAccount(playerID: String, referralID: String?, account: PublicAccount) {
            var checkAccount <- JoyrideAccounts.playerAccounts.remove(key: playerID)
            if(checkAccount == nil){
                destroy checkAccount
                var playerAccount <-create PlayerAccount(playerID: playerID, referralID: referralID)
                playerAccount.AssociatePaymentAddress(address: account.address)
                destroy JoyrideAccounts.playerAccounts.insert(key: playerID, <-playerAccount)
                emit AccountCreated(playerID: playerID, referralID: referralID, accountAddress: account.address)
            }else {
                checkAccount?.AssociatePaymentAddress(address: account.address)
                destroy JoyrideAccounts.playerAccounts.insert(key: playerID, <-checkAccount!)
                emit AccountAlreadyExists(playerID: playerID, accountAddress: account.address)
            }
        }

        pub fun AddDeveloperAccount(address: Address, gameID: String) {
            JoyrideAccounts.gameToDeveloperAccount[gameID] = address
            emit LinkDeveloperAccount(accountAddress: address, gameID: gameID)
        }

        pub fun TransferPlayerAccount(playerID: String, to: PublicAccount) {
            let checkAccount <- JoyrideAccounts.playerAccounts.remove(key: playerID) ?? panic("PlayerID not found!")
            checkAccount.AssociatePaymentAddress(address: to.address)
            destroy JoyrideAccounts.playerAccounts.insert(key: playerID, <-checkAccount)
        }

        pub fun GetPlayerJRXAccount(playerID: String) : &PlayerAccount? {
            if(JoyrideAccounts.playerAccounts.containsKey(playerID)) {
                let playerAccount <- JoyrideAccounts.playerAccounts.remove(key: playerID)!
                let reference = &playerAccount as  &PlayerAccount
                destroy JoyrideAccounts.playerAccounts.insert(key: playerID, <- playerAccount)
                return reference
            }
            return nil
        }

        pub fun ShareProfits(profits:@FungibleToken.Vault, inGameID: String, fromPlayerID: String) : @FungibleToken.Vault {
            let playerAddress = JoyrideAccounts.playerIDToPlayer[fromPlayerID]
            let playerAccount = self.GetPlayerJRXAccount(playerID:fromPlayerID)

            let developerStaking = JoyrideAccounts.gameToDeveloperAccount[inGameID]
            if(developerStaking == nil) {
                return <- profits
            }
            else {
                let vaultCapability = getAccount(developerStaking!).getCapability<&{JoyrideMultiToken.Receiver}>(JoyrideMultiToken.UserPublicPath).borrow()
                if(vaultCapability == nil) {
                    return <- profits
                }
                else {
                    let devShare <- profits.withdraw(amount: profits.balance * 0.8)
                    vaultCapability!.depositToken(from: <- devShare)
                    return <- profits
                }
            }
        }

        pub fun EscrowWithdraw(playerID: String, amount:UFix64, tokenContext: String): @FungibleToken.Vault? {
            let playerAccount = self.GetPlayerJRXAccount(playerID:playerID)
            if(playerAccount == nil) {
                return nil
            }
            return <- playerAccount!.WithdrawTokensForPayment(playerID: playerID, txID:"", amount:amount, tokenContext: tokenContext)
        }

        pub fun EscrowWithdrawWithTnxId(playerID: String, txID: String, amount:UFix64, tokenContext: String): @FungibleToken.Vault? {
           let playerAccount = self.GetPlayerJRXAccount(playerID:playerID)
           if(playerAccount == nil) {
              return nil
           }
           return <- playerAccount!.WithdrawTokensForPayment(playerID: playerID, txID:txID, amount:amount, tokenContext: tokenContext)
        }

        pub fun PlayerDeposit(playerID: String, vault:@FungibleToken.Vault) : @FungibleToken.Vault? {
            let playerAccount = self.GetPlayerJRXAccount(playerID:playerID)
            if(playerAccount != nil) {
                playerAccount!.DepositTokens(vault: <-vault)
                return nil
            } else {
                return <- vault
            }
        }
    }

    pub struct CreateAccountTransactionData {
        pub var playerID: String
        pub var referralID: String

        init(playerID: String, referralID: String) {
            self.playerID = playerID
            self.referralID = referralID
        }
    }
}
