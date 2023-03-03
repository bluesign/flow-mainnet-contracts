import MetadataViews from 0x1d7e57aa55817448
import Interfaces from 0x907a3b49797cca7a
import Helper from 0x907a3b49797cca7a

pub contract QueryStructs {

  pub struct BountyInfo {
    pub let id: UInt64
    pub let identifier: AnyStruct{Interfaces.BountyEntityIdentifier}
    pub let properties: {UInt8: Bool}
    pub let display: MetadataViews.Display
    pub let missionDetail: Interfaces.MissionDetail?
    pub let questDetail: Interfaces.QuestDetail?
    // bounty data
    pub let preconditions: [AnyStruct{Interfaces.UnlockCondition}]
    pub let participants: {Address: {String: AnyStruct}}
    pub let participantAmt: UInt64
    // reward info
    pub let rewardType: Helper.MissionRewardType
    pub let pointReward: Helper.PointReward?
    pub let floatReward: Helper.FLOATReward?

    init(
      id: UInt64,
      identifier: AnyStruct{Interfaces.BountyEntityIdentifier},
      properties: {UInt8: Bool},
      display: MetadataViews.Display,
      missionDetail: Interfaces.MissionDetail?,
      questDetail: Interfaces.QuestDetail?,
      preconditions: [AnyStruct{Interfaces.UnlockCondition}],
      participants: {Address: {String: AnyStruct}},
      participantAmt: UInt64,
      rewardType: Helper.MissionRewardType,
      pointReward: Helper.PointReward?,
      floatReward: Helper.FLOATReward?,
    ) {
      self.id = id
      self.identifier = identifier
      self.properties = properties
      self.display = display
      self.missionDetail = missionDetail
      self.questDetail = questDetail
      self.preconditions = preconditions
      self.participants = participants
      self.participantAmt = participantAmt
      self.rewardType = rewardType
      self.pointReward = pointReward
      self.floatReward = floatReward
    }
  }

  pub struct MissionData {
    pub let identifier: AnyStruct{Interfaces.BountyEntityIdentifier}
    pub let display: MetadataViews.Display
    pub let detail: Interfaces.MissionDetail

    init(
      identifier: AnyStruct{Interfaces.BountyEntityIdentifier},
      display: MetadataViews.Display,
      detail: Interfaces.MissionDetail,
    ) {
      self.identifier = identifier
      self.display = display
      self.detail = detail
    }
  }

  pub struct QuestData {
    pub let identifier: AnyStruct{Interfaces.BountyEntityIdentifier}
    pub let display: MetadataViews.Display
    pub let detail: Interfaces.QuestDetail

    init(
      identifier: AnyStruct{Interfaces.BountyEntityIdentifier},
      display: MetadataViews.Display,
      detail: Interfaces.QuestDetail
    ) {
        self.identifier = identifier
        self.display = display
        self.detail = detail
    }
  }
}
