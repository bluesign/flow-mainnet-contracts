/**
## The Interfaces of Flow Quest

> Author: Bohao Tang<tech@btang.cn>

*/
import MetadataViews from 0x1d7e57aa55817448
import Helper from 0x907a3b49797cca7a

pub contract Interfaces {

    // =================== Profile ====================

    pub struct LinkedIdentity {
        pub let platform: String
        pub let uid: String
        pub let display: MetadataViews.Display

        init(platform: String, uid: String, display: MetadataViews.Display) {
            self.platform = platform
            self.uid = uid
            self.display = display
        }
    }

    pub struct MissionStatus {
        pub let steps: [Bool]
        pub let completed: Bool

        init(
            steps: [Bool]
        ) {
            self.steps = steps
            var completed = true
            for one in steps {
                completed = one && completed
            }
            self.completed = completed
        }
    }

    // Profile
    pub resource interface ProfilePublic {
        // readable
        pub fun getId(): UInt64
        pub fun getReferredFrom(): Address?
        pub fun getReferralCode(): String?

        pub fun getIdentities(): [LinkedIdentity]
        pub fun getIdentity(platform: String): LinkedIdentity

        pub fun getBountiesCompleted(): {UInt64: UFix64}
        pub fun isBountyCompleted(bountyId: UInt64): Bool
        pub fun getMissionStatus(missionKey: String): MissionStatus
        pub fun getMissionsParticipanted(): [String]

        // season points
        pub fun isRegistered(seasonId: UInt64): Bool
        pub fun getSeasonsJoined(): [UInt64]
        pub fun getSeasonPoints(seasonId: UInt64): UInt64
        pub fun getProfilePoints(): UInt64

        // writable
        access(account) fun addPoints(seasonId: UInt64, points: UInt64)

        access(account) fun completeBounty(bountyId: UInt64)
        access(account) fun updateMissionNewParams(missionKey: String, step: Int, params: {String: AnyStruct})
        access(account) fun updateMissionVerificationResult(missionKey: String, step: Int, result: Bool)

        access(account) fun setupReferralCode(code: String)
    }

    // =================== Community ====================

    pub enum BountyType: UInt8 {
        pub case mission
        pub case quest
    }

    pub struct interface BountyEntityIdentifier {
        pub let category: BountyType
        // The offchain key of the mission
        pub let key: String
        // The community belongs to
        pub let communityId: UInt64
        // get Bounty Entity
        pub fun getBountyEntity(): &AnyStruct{BountyEntityPublic};
        // To simple string uid
        pub fun toString(): String {
            return self.communityId.toString().concat(":").concat(self.key)
        }
    }

    pub struct interface BountyEntityPublic {
        pub let category: BountyType
        // The offchain key of the mission
        pub let key: String
        // The community belongs to
        pub let communityId: UInt64

        // display
        pub fun getStandardDisplay(): MetadataViews.Display
        // To simple string uid
        pub fun toString(): String {
            return self.communityId.toString().concat(":").concat(self.key)
        }
    }

    pub struct interface MissionInfoPublic {
        pub fun getDetail(): MissionDetail
    }

    pub struct MissionDetail {
        pub let steps: UInt64
        pub let stepsCfg: String

        init(
            steps: UInt64,
            stepsCfg: String,
        ) {
            self.steps = steps
            self.stepsCfg = stepsCfg
        }
    }

    pub struct interface QuestInfoPublic {
        pub fun getDetail(): QuestDetail
    }

    pub struct QuestDetail {
        pub let missions: [AnyStruct{BountyEntityIdentifier}]
        pub let achievement: Helper.EventIdentifier?;

        init(
            missions: [AnyStruct{BountyEntityIdentifier}],
            achievement: Helper.EventIdentifier?
        ) {
            self.missions = missions
            self.achievement = achievement
        }
    }

    // =================== Competition ====================

    pub struct interface UnlockCondition {
        pub let type: UInt8;

        pub fun isUnlocked(_ params: {String: AnyStruct}): Bool;
    }

    // Bounty information
    pub resource interface BountyInfoPublic {
        pub fun getID(): UInt64

        pub fun getPreconditions(): [AnyStruct{UnlockCondition}]
        pub fun getIdentifier(): AnyStruct{BountyEntityIdentifier}

        pub fun getRequiredMissionKeys(): [String]

        pub fun getRewardType(): Helper.MissionRewardType
        pub fun getPointReward(): Helper.PointReward
        pub fun getFLOATReward(): Helper.FLOATReward
    }

    // Competition public interface
    pub resource interface CompetitionPublic {
        // status
        pub fun isActive(): Bool
        // information
        pub fun getSeasonId(): UInt64
        // leaderboard
        pub fun getRank(_ addr: Address): Int
        pub fun getLeaderboardRanking(limit: Int?): {UInt64: [Address]}
        // onProfile
        access(account) fun onProfileRegistered(acct: Address)
    }

    pub resource interface CompetitionServicePublic {
        pub fun getReferralAddress(_ code: String): Address?
        pub fun getReferralCode(_ addr: Address): String?

        // season
        pub fun getActiveSeasonID(): UInt64
        pub fun borrowSeason(seasonId: UInt64): &{CompetitionPublic}

        // bounties
        pub fun getBountyIDs(): [UInt64]
        pub fun getPrimaryBountyIDs(): [UInt64]
        pub fun hasBountyByKey(_ key: String): Bool
        pub fun checkBountyCompleteStatus(acct: Address, bountyId: UInt64): Bool

        pub fun borrowBountyInfo(_ bountyId: UInt64): &AnyResource{BountyInfoPublic}
        pub fun borrowMissionRef(_ missionKey: String): &AnyStruct{BountyEntityPublic, MissionInfoPublic}

        access(account) fun onBountyCompleted(bountyId: UInt64, acct: Address)
    }
}
