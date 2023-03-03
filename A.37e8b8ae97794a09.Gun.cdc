
pub contract Gun {
    pub var effect: String

    pub init() {
        self.effect = "peew peew"
    }

    pub fun sayHi(): String {
        return self.effect
    }
}