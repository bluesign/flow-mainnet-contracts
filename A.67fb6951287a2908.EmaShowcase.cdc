import MessageCard from 0xf38fadaba79009cc

pub contract EmaShowcase {
    pub struct Ema {
        pub let id: UInt64
        pub let owner: Address

        init(id: UInt64, owner: Address) {
            self.id = id
            self.owner = owner
        }
    }

    access(account) var emas: [Ema]
    access(account) var exists: {UInt64: Bool}
    access(account) var max: Int
    access(account) var paused: Bool
    access(account) var allowedTemplateIds: {UInt64: Bool}

    pub resource Admin {
        pub fun updateMax(max: Int) {
            EmaShowcase.max = max
            while EmaShowcase.emas.length > EmaShowcase.max {
                let lastEma = EmaShowcase.emas.removeLast()
                EmaShowcase.exists.remove(key: lastEma.id)
            }
        }

        pub fun updatePaused(paused: Bool) {
            EmaShowcase.paused = paused
        }

        pub fun addAllowedTemplateId(templateId: UInt64) {
            EmaShowcase.allowedTemplateIds[templateId] = true
        }

        pub fun removeAllowedTemplateId(templateId: UInt64) {
            EmaShowcase.allowedTemplateIds.remove(key: templateId)
        }

        pub fun clearEmas() {
            EmaShowcase.emas = []
            EmaShowcase.exists = {}
        }
    }

    pub fun addEma(id: UInt64, collectionCapability: Capability<&MessageCard.Collection{MessageCard.CollectionPublic}>) {
        pre {
            !EmaShowcase.paused: "Paused"
            !EmaShowcase.exists.containsKey(id): "Already Existing"
            collectionCapability.borrow()?.borrowMessageCard(id: id) != nil: "Not Found"
            EmaShowcase.allowedTemplateIds.containsKey(collectionCapability.borrow()!.borrowMessageCard(id: id)!.templateId): "Not Allowed Template"
        }
        EmaShowcase.emas.insert(at: 0, Ema(id: id, owner: collectionCapability.address))
        EmaShowcase.exists[id] = true
        if EmaShowcase.emas.length > EmaShowcase.max {
            let lastEma = EmaShowcase.emas.removeLast()
            EmaShowcase.exists.remove(key: lastEma.id)
        }
    }

    pub fun getEmas(from: Int, upTo: Int): [Ema] {
        if from >= EmaShowcase.emas.length {
            return []
        }
        if upTo >= EmaShowcase.emas.length {
            return EmaShowcase.emas.slice(from: from, upTo: EmaShowcase.emas.length - 1)
        }
        return EmaShowcase.emas.slice(from: from, upTo: upTo)
    }

    init() {
        self.emas = []
        self.exists = {}
        self.max = 1000
        self.paused = false
        self.allowedTemplateIds = {}

        self.account.save(<- create Admin(), to: /storage/EmaShowcaseAdmin)
    }
}
