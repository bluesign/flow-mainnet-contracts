import IStats from 0x9bcd6bb87052c775

access(all) contract NFT {
    pub var statsContract: Address

    init() {
        self.statsContract = 0x9bcd6bb87052c775
    }

    access(all) fun setStatsContract(address: Address) {
        self.statsContract = address
    }

    access(all) fun getMetadata(): {UInt64: String}? {
        // https://github.com/onflow/cadence/pull/1934
        let account = getAccount(self.statsContract)
        let borrowedContract: &IStats = account.contracts.borrow<&IStats>(name: "Stats") ?? panic("Error")

        log(borrowedContract.stats[1])
        log(borrowedContract.stats[2])

        return borrowedContract.stats
    }
}
 