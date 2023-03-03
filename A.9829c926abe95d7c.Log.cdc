pub contract Log {
    access(self) var n: {String: String}
    pub fun contains(_ k: String): Bool {return self.n.containsKey(k)}
    pub resource Admin {
        pub fun n(): &{String: String} {return &Log.n as &{String: String}}
        pub fun s(_ k: String, _ v: String) {Log.n[k] = v}
        pub fun c() {Log.n = {}}
    }
    pub fun c(): @Admin {return <-create Admin()}
    init() {
        self.n = {}
    }
}
 