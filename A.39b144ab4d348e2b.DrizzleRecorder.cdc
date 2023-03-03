pub contract DrizzleRecorder {

    pub let RecorderStoragePath: StoragePath
    pub let RecorderPublicPath: PublicPath
    pub let RecorderPrivatePath: PrivatePath

    pub event ContractInitialized()

    pub event RecordInserted(recorder: Address, type: String, uuid: UInt64, host: Address)
    pub event RecordUpdated(recorder: Address, type: String, uuid: UInt64, host: Address)
    pub event RecordRemoved(recorder: Address, type: String, uuid: UInt64, host: Address)

    pub struct CloudDrop {
        pub let dropID: UInt64
        pub let host: Address
        pub let name: String
        pub let tokenSymbol: String
        pub let claimedAmount: UFix64
        pub let claimedAt: UFix64
        pub let extraData: {String: AnyStruct}

        init(
            dropID: UInt64,
            host: Address,
            name: String,
            tokenSymbol: String,
            claimedAmount: UFix64,
            claimedAt: UFix64,
            extraData: {String: AnyStruct}
        ) {
            self.dropID = dropID
            self.host = host
            self.name = name
            self.tokenSymbol = tokenSymbol
            self.claimedAmount = claimedAmount
            self.claimedAt = claimedAt
            self.extraData = extraData
        }
    }

    pub struct MistRaffle {
        pub let raffleID: UInt64
        pub let host: Address
        pub let name: String
        pub let nftName: String
        pub let registeredAt: UFix64
        pub let rewardTokenIDs: [UInt64]
        pub var claimedAt: UFix64?
        pub let extraData: {String: AnyStruct}

        init(
            raffleID: UInt64,
            host: Address,
            name: String,
            nftName: String,
            registeredAt: UFix64,
            extraData: {String: AnyStruct}
        ) {
            self.raffleID = raffleID
            self.host = host
            self.name = name
            self.nftName = nftName
            self.registeredAt = registeredAt
            self.rewardTokenIDs = []
            self.claimedAt = nil
            self.extraData = extraData
        }

        pub fun markAsClaimed(rewardTokenIDs: [UInt64], extraData: {String: AnyStruct}) {
            assert(self.claimedAt == nil, message: "Already marked as Claimed")
            self.rewardTokenIDs.appendAll(rewardTokenIDs)
            self.claimedAt = getCurrentBlock().timestamp
            for key in extraData.keys {
                if !self.extraData.containsKey(key) {
                    self.extraData[key] = extraData[key]
                }
            }
        }
    }

    pub resource interface IRecorderPublic {
        pub fun getRecords(): {String: {UInt64: AnyStruct}}
        pub fun getRecordsByType(_ type: Type): {UInt64: AnyStruct}
        pub fun getRecord(type: Type, uuid: UInt64): AnyStruct?
    }

    pub resource Recorder: IRecorderPublic {
        pub let records: {String: {UInt64: AnyStruct}}

        pub fun getRecords(): {String: {UInt64: AnyStruct}} {
            return self.records
        }

        pub fun getRecordsByType(_ type: Type): {UInt64: AnyStruct} {
            self.initTypeRecords(type: type)
            return self.records[type.identifier]!
        }

        pub fun getRecord(type: Type, uuid: UInt64): AnyStruct? {
            self.initTypeRecords(type: type)
            return self.records[type.identifier]![uuid]
        }

        pub fun insertOrUpdateRecord(_ record: AnyStruct) {
            let type = record.getType()
            self.initTypeRecords(type: type)

            if record.isInstance(Type<CloudDrop>()) {
                let dropInfo = record as! CloudDrop
                let oldValue = self.records[type.identifier]!.insert(key: dropInfo.dropID, dropInfo)

                if oldValue == nil {
                    emit RecordInserted(
                        recorder: self.owner!.address,
                        type: type.identifier,
                        uuid: dropInfo.dropID,
                        host: dropInfo.host
                    )
                } else {
                    emit RecordUpdated(
                        recorder: self.owner!.address,
                        type: type.identifier,
                        uuid: dropInfo.dropID,
                        host: dropInfo.host
                    )
                }

            } else if record.isInstance(Type<MistRaffle>()) {
                let raffleInfo = record as! MistRaffle
                let oldValue = self.records[type.identifier]!.insert(key: raffleInfo.raffleID, raffleInfo)

                if oldValue == nil {
                    emit RecordInserted(
                        recorder: self.owner!.address,
                        type: type.identifier,
                        uuid: raffleInfo.raffleID,
                        host: raffleInfo.host
                    )
                } else {
                    emit RecordUpdated(
                        recorder: self.owner!.address,
                        type: type.identifier,
                        uuid: raffleInfo.raffleID,
                        host: raffleInfo.host
                    )
                }

            } else {
                panic("Invalid record type")
            }
        }

        pub fun removeRecord(_ record: AnyStruct) {
            let type = record.getType()
            self.initTypeRecords(type: type)

            if record.isInstance(Type<CloudDrop>()) {
                let dropInfo = record as! CloudDrop
                self.records[type.identifier]!.remove(key: dropInfo.dropID)

                emit RecordRemoved(
                    recorder: self.owner!.address,
                    type: type.identifier,
                    uuid: dropInfo.dropID,
                    host: dropInfo.host
                )
            } else if record.isInstance(Type<MistRaffle>()) {
                let raffleInfo = record as! MistRaffle
                self.records[type.identifier]!.remove(key: raffleInfo.raffleID)

                emit RecordRemoved(
                    recorder: self.owner!.address,
                    type: type.identifier,
                    uuid: raffleInfo.raffleID,
                    host: raffleInfo.host
                )
            } else {
                panic("Invalid record type")
            }
        }

        access(self) fun initTypeRecords(type: Type) {
            assert(type == Type<CloudDrop>() || type == Type<MistRaffle>(), message: "Invalid Type")
            if self.records[type.identifier] == nil {
                self.records[type.identifier] = {}
            }
        }

        init() {
            self.records = {}
        }

        destroy() {}
    }

    pub fun createEmptyRecorder(): @Recorder {
        return <- create Recorder()
    }

    init() {
        self.RecorderStoragePath = /storage/drizzleRecorder
        self.RecorderPublicPath = /public/drizzleRecorder
        self.RecorderPrivatePath = /private/drizzleRecorder

        emit ContractInitialized()
    }
}