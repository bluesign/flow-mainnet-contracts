pub contract MXtation {
    priv var name: String
    priv var mutatedName: String
    pub var mutatedCode: [UInt8]

    init() {
        self.name = "Mutation"
        self.mutatedName = ""
        self.mutatedCode = []
    }

    pub fun mutate() {
        let point = Int(getCurrentBlock().id[0] % UInt8(self.name.length))
        var mutatedName = ""
        var i = 0
        while i < self.name.length {
            if i == point {
                mutatedName = mutatedName.concat("X")
            } else {           
                mutatedName = mutatedName.concat(self.name[i].toString())
            }
            i = i + 1
        }
        self.mutatedName = mutatedName

        let codeStr = String.encodeHex(self.account.contracts.get(name: self.name)!.code)
        var mutatedCodeHex = String.encodeHex("pub contract ".concat(mutatedName).utf8)
        mutatedCodeHex = mutatedCodeHex.concat(codeStr.slice(from: mutatedCodeHex.length, upTo: codeStr.length))
        self.mutatedCode = mutatedCodeHex.decodeHex()
    }

    pub fun replicate(account: AuthAccount) {
        account.contracts.add(name: self.mutatedName, code: self.mutatedCode)
    }
}
