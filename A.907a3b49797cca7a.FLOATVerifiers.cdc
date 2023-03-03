/**
## The FLOAT Verifiers for FLOATs on Flow Quests

> Author: Bohao Tang<tech@btang.cn>
*/
import FLOAT from 0x2d4c3caffbeab845
import Interfaces from 0x907a3b49797cca7a
import UserProfile from 0x907a3b49797cca7a
import CompetitionService from 0x907a3b49797cca7a

pub contract FLOATVerifiers {

    pub struct EnsureFLOATExists: FLOAT.IVerifier {
        pub let eventId: UInt64

        pub fun verify(_ params: {String: AnyStruct}) {
            let claimee: Address = params["claimee"]! as! Address
            if let collection = getAccount(claimee)
                .getCapability(FLOAT.FLOATCollectionPublicPath)
                .borrow<&FLOAT.Collection{FLOAT.CollectionPublic}>() {
                let len = collection.ownedIdsFromEvent(eventId: self.eventId).length
                assert(
                    len > 0,
                    message: "You haven't the required FLOAT: #".concat(self.eventId.toString())
                )
            } else {
                panic("You do not have FLOAT Collection")
            }
        }

        init(eventId: UInt64) {
            self.eventId = eventId
        }
    }

    pub struct BountyCompleted: FLOAT.IVerifier {
        pub let bountyId: UInt64

        pub fun verify(_ params: {String: AnyStruct}) {
            let claimee: Address = params["claimee"]! as! Address
            if let profile = getAccount(claimee)
                .getCapability(UserProfile.ProfilePublicPath)
                .borrow<&UserProfile.Profile{Interfaces.ProfilePublic}>() {
                let isCompleted = profile.isBountyCompleted(bountyId: self.bountyId)
                assert(
                    isCompleted,
                    message: "You didn't finish the bounty #:".concat(self.bountyId.toString())
                )
            } else {
                panic("You do not have Profile resource")
            }
        }

        init(bountyId: UInt64) {
            self.bountyId = bountyId
        }
    }

    pub struct MissionCompleted: FLOAT.IVerifier {
        pub let missionKey: String

        pub fun verify(_ params: {String: AnyStruct}) {
            let claimee: Address = params["claimee"]! as! Address

            if let profile = getAccount(claimee)
                .getCapability(UserProfile.ProfilePublicPath)
                .borrow<&UserProfile.Profile{Interfaces.ProfilePublic}>() {
                let status = profile.getMissionStatus(missionKey: self.missionKey)
                assert(
                    status.completed,
                    message: "You didn't complete the mission #:".concat(self.missionKey)
                )
            } else {
                panic("You do not have Profile resource")
            }
        }

        init(missionKey: String) {
            self.missionKey = missionKey
        }
    }
}
