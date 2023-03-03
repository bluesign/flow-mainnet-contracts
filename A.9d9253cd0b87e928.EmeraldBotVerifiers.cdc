import EmeraldPass from 0x6a07dbeb03167a13

pub contract EmeraldBotVerifiers {

    pub let VerifierCollectionStoragePath: StoragePath
    pub let VerifierCollectionPublicPath: PublicPath
    pub let VerifierCollectionPrivatePath: PrivatePath

    pub event ContractInitialized()

    pub event VerifierCreated(verifierId: UInt64, name: String, mode: UInt8, guildId: String, roleIds: [String])
    pub event VerifierDeleted(verifierId: UInt64)

    pub enum VerificationMode: UInt8 {
        pub case Normal
        pub case ShortCircuit
    }

    pub resource Verifier {
        pub let name: String
        pub let description: String
        pub let image: String
        pub let scriptCode: String
        pub let guildId: String
        pub let roleIds: [String]
        pub let verificationMode: VerificationMode
        pub let extra: {String: AnyStruct}

        init(
            name: String, 
            description: String, 
            image: String, 
            scriptCode: String, 
            guildId: String,
            roleIds: [String],
            verificationMode: VerificationMode,
            extra: {String: AnyStruct}
        ) {
            self.name = name
            self.description = description
            self.image = image
            self.scriptCode = scriptCode
            self.guildId = guildId
            self.roleIds = roleIds
            self.verificationMode = verificationMode
            self.extra = extra
        }
    }

    pub resource interface VerifierCollectionPublic {
        pub fun getVerifierIds(): [UInt64]
        pub fun getVerifier(verifierId: UInt64): &Verifier?
        pub fun getVerifiersByGuildId(guildId: String): [&Verifier?]
    }

    pub resource VerifierCollection: VerifierCollectionPublic {
        pub let verifiers: @{UInt64: Verifier}

        pub fun addVerifier(
            name: String, 
            description: String, 
            image: String,
            scriptCode: String,
            guildId: String,
            roleIds: [String],
            verificationMode: VerificationMode,
            extra: {String: AnyStruct}
        ) {
            pre {
                EmeraldPass.isActive(user: self.owner!.address) || self.verifiers.keys.length < 1: 
                    "You cannot have more than one verifier if you do not own Emerald Pass (https://pass.ecdao.org)."
            }

            let verifier <- create Verifier(
                name: name, 
                description: description, 
                image: image, 
                scriptCode: scriptCode, 
                guildId: guildId,
                roleIds: roleIds,
                verificationMode: verificationMode,
                extra: extra
            )
            emit VerifierCreated(verifierId: verifier.uuid, name: name, mode: verificationMode.rawValue, guildId: guildId, roleIds: roleIds)
            self.verifiers[verifier.uuid] <-! verifier
        }

        pub fun deleteVerifier(verifierId: UInt64) {
            emit VerifierDeleted(verifierId: verifierId)
            destroy self.verifiers.remove(key: verifierId)
        }

        pub fun getVerifierIds(): [UInt64] {
            return self.verifiers.keys
        }

        pub fun getVerifier(verifierId: UInt64): &Verifier? {
            return &self.verifiers[verifierId] as &Verifier?
        }

        pub fun getVerifiersByGuildId(guildId: String): [&Verifier?] {
            let response: [&Verifier?] = []
            for id in self.getVerifierIds() {
                let verifier = self.getVerifier(verifierId: id)!
                if verifier.guildId == guildId {
                    response.append(verifier)
                }
            }

            return response
        }

        init() {
            self.verifiers <- {}
        }

        destroy() {
            destroy self.verifiers
        }
    }

    pub fun createEmptyCollection(): @VerifierCollection {
        return <- create VerifierCollection()
    }

    init() {
        self.VerifierCollectionStoragePath = /storage/EmeraldBotVerifierCollection001
        self.VerifierCollectionPublicPath = /public/EmeraldBotVerifierCollection001
        self.VerifierCollectionPrivatePath = /private/EmeraldBotVerifierCollection001

        emit ContractInitialized()
    }
}
 