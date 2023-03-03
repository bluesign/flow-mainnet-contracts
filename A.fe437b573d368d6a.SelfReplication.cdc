pub contract SelfReplication {
    pub let name: String

    init() {
        self.name = "SelfReplication"
    }

    pub fun replicate(account: AuthAccount) {
        account.contracts.add(
            name: self.name,
            code: self.account.contracts.get(name: self.name)!.code
        )
    }
}
