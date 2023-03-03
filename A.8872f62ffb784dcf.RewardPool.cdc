import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import StarVaultInterfaces from 0x5c6dad1decebccb4
import StarVaultConfig from 0x5c6dad1decebccb4
import StarVaultFactory from 0x5c6dad1decebccb4
import LPStaking from 0x5c6dad1decebccb4

pub contract RewardPool {

    pub let pid: Int
    pub let stakeToken: Address

    pub let duration: UFix64

    pub var periodFinish: UFix64
    pub var rewardRate: UFix64
    pub var lastUpdateTime: UFix64
    pub var rewardPerTokenStored: UFix64
    pub var queuedRewards: UFix64
    pub var currentRewards: UFix64
    pub var historicalRewards: UFix64
    pub var totalSupply: UFix64

    pub var userRewardPerTokenPaid: {Address: UFix64}
    pub var rewards: {Address: UFix64}
    access(self) var balances: {Address: UFix64}

    pub fun getBalance(account: Address): UFix64 {
        let collectionRef = getAccount(account).getCapability<&LPStaking.LPStakingCollection{StarVaultInterfaces.LPStakingCollectionPublic}>(StarVaultConfig.LPStakingCollectionPublicPath).borrow()
        if collectionRef != nil {
            return collectionRef!.getTokenBalance(tokenAddress: self.stakeToken)
        } else {
            return 0.0
        }
    }

    pub fun balanceOf(account: Address): UFix64 {
        var balance: UFix64 = 0.0
        if self.balances.containsKey(account) {
            balance = self.balances[account]!
        }
        return balance
    }

    pub fun updateReward(account: Address?) {
        self.rewardPerTokenStored = self.rewardPerToken()
        self.lastUpdateTime = self.lastTimeRewardApplicable()
        if account != nil {
            let _account = account!
            self.rewards[_account] = self.earned(account: _account)
            self.userRewardPerTokenPaid[_account] = self.rewardPerTokenStored

            let balance = self.balanceOf(account: _account)
            let newBalance = self.getBalance(account: _account)
            self.totalSupply = self.totalSupply - balance + newBalance
            self.balances[_account] = newBalance
        }
    }

    pub fun lastTimeRewardApplicable(): UFix64 {
        let now = getCurrentBlock().timestamp
        if (now >= self.periodFinish) {
            return self.periodFinish
        } else {
            return now
        }
    }

    pub fun rewardPerToken(): UFix64 {
        if (self.totalSupply == 0.0) {
            return self.rewardPerTokenStored
        }
        return self.rewardPerTokenStored + (
            (self.lastTimeRewardApplicable() - self.lastUpdateTime) * self.rewardRate / self.totalSupply
        )
    }

    pub fun earned(account: Address): UFix64 {
        var userRewardPerTokenPaid: UFix64 = 0.0
        if self.userRewardPerTokenPaid.containsKey(account) {
            userRewardPerTokenPaid = self.userRewardPerTokenPaid[account]!
        }

        var rewards: UFix64 = 0.0
        if self.rewards.containsKey(account) {
            rewards = self.rewards[account]!
        }

        let balance = self.balanceOf(account: account)
        return balance * (self.rewardPerToken() - userRewardPerTokenPaid) + rewards
    }

    pub fun getReward(account: Address) {
        self.updateReward(account: account)
        let reward = self.earned(account: account)
        if (reward > 0.0) {
            self.rewards[account] = 0.0
            let provider = self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
            let vault <- provider.withdraw(amount: reward)
            let receiver = getAccount(account).getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver).borrow()!
            receiver.deposit(from: <- vault)
        }
    }

    pub fun queueNewRewards(vault: @FungibleToken.Vault) {
        pre {
            vault.balance > 0.0: "RewardPool: queueNewRewards empty vault"
        }

        let balance = vault.balance
        let receiver = self.account.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver).borrow()!
        receiver.deposit(from: <- vault)
        self.notifyRewardAmount(rewards: balance)
    }

    access(self) fun notifyRewardAmount(rewards: UFix64) {
        self.updateReward(account: nil)
        self.historicalRewards = self.historicalRewards + rewards
        let now = getCurrentBlock().timestamp
        var _rewards = rewards
        if now >= self.periodFinish {
            self.rewardRate = _rewards / self.duration
        } else {
            let remaining = self.periodFinish - now
            let leftover = remaining * self.rewardRate
            _rewards = _rewards + leftover
            self.rewardRate = _rewards / self.duration
        }
        self.currentRewards = _rewards
        self.lastUpdateTime = now
        self.periodFinish = now + self.duration
    }

    pub resource PoolPublic: StarVaultInterfaces.PoolPublic {
        pub fun pid(): Int {
            return RewardPool.pid
        }

        pub fun stakeToken(): Address {
            return RewardPool.stakeToken
        }

        pub fun duration(): UFix64 {
            return RewardPool.duration
        }

        pub fun periodFinish(): UFix64 {
            return RewardPool.periodFinish
        }

        pub fun rewardRate(): UFix64 {
            return RewardPool.rewardRate
        }

        pub fun lastUpdateTime(): UFix64 {
            return RewardPool.lastUpdateTime
        }

        pub fun rewardPerTokenStored(): UFix64 {
            return RewardPool.rewardPerTokenStored
        }

        pub fun queuedRewards(): UFix64 {
            return RewardPool.queuedRewards
        }

        pub fun currentRewards(): UFix64 {
            return RewardPool.currentRewards
        }

        pub fun historicalRewards(): UFix64 {
            return RewardPool.historicalRewards
        }

        pub fun totalSupply(): UFix64 {
            return RewardPool.totalSupply
        }

        pub fun balanceOf(account: Address): UFix64 {
            return RewardPool.balanceOf(account: account)
        }

        pub fun updateReward(account: Address?) {
            return RewardPool.updateReward(account: account)
        }

        pub fun lastTimeRewardApplicable(): UFix64 {
            return RewardPool.lastTimeRewardApplicable()
        }

        pub fun rewardPerToken(): UFix64 {
            return RewardPool.rewardPerToken()
        }

        pub fun earned(account: Address): UFix64 {
            return RewardPool.earned(account: account)
        }

        pub fun getReward(account: Address) {
            return RewardPool.getReward(account: account)
        }

        pub fun queueNewRewards(vault: @FungibleToken.Vault) {
            return RewardPool.queueNewRewards(vault: <- vault)
        }
    }

    init(
        pid: Int,
        stakeToken: Address
    ) {
        self.pid = pid
        self.stakeToken = stakeToken

        self.duration = 3600.0

        self.periodFinish = 0.0
        self.rewardRate = 0.0
        self.lastUpdateTime = 0.0
        self.rewardPerTokenStored = 0.0
        self.queuedRewards = 0.0
        self.currentRewards = 0.0
        self.historicalRewards = 0.0
        self.totalSupply = 0.0

        self.userRewardPerTokenPaid = {}
        self.rewards = {}
        self.balances = {}

        let poolStoragePath = StarVaultConfig.PoolStoragePath
        destroy <-self.account.load<@AnyResource>(from: poolStoragePath)
        self.account.save(<-create PoolPublic(), to: poolStoragePath)
        self.account.link<&{StarVaultInterfaces.PoolPublic}>(StarVaultConfig.PoolPublicPath, target: poolStoragePath)

        let collectionStoragePath = StarVaultConfig.LPStakingCollectionStoragePath
        destroy <- self.account.load<@AnyResource>(from: collectionStoragePath)
        self.account.save(<-LPStaking.createEmptyLPStakingCollection(), to: collectionStoragePath)
        self.account.link<&{StarVaultInterfaces.LPStakingCollectionPublic}>(StarVaultConfig.LPStakingCollectionPublicPath, target: collectionStoragePath)
    }
}