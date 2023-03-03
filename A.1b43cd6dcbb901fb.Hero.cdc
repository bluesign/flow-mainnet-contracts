 import HeroSurname from 0x1b43cd6dcbb901fb
 pub contract Hero {
    pub var name: String

    pub init() {
        self.name = "My name is Bond...".concat(HeroSurname.surname)
    }

    pub fun sayName(): String {
        return self.name
    }
 }