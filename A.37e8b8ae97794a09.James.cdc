import Gun from 0x37e8b8ae97794a09
pub contract James {
    pub var name: String

    pub init() {
        self.name = "my name is Bond.... James Bond..."
    }

    pub fun sayHi(): String {
        return self.name.concat(Gun.sayHi())
    }
}