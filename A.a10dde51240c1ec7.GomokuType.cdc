pub contract GomokuType {

    pub enum VerifyDirection: UInt8 {
        pub case vertical
        pub case horizontal
        pub case diagonal // "/"
        pub case reversedDiagonal // "\"
    }

    pub enum Role: UInt8 {
        pub case host
        pub case challenger
    }

    pub enum StoneColor: UInt8 {
        // block stone go first
        pub case black
        pub case white
    }

    pub enum Result: UInt8 {
        pub case hostWins
        pub case challengerWins
        pub case draw
    }

    pub resource interface Stoning {
        pub let color: StoneColor
        pub let location: StoneLocation

        pub fun key(): String

        pub fun convertToData(): AnyStruct{GomokuType.StoneDataing}
    }

    pub struct interface StoneDataing {
        pub let color: StoneColor
        pub let location: StoneLocation

        pub init(
            color: StoneColor,
            location: StoneLocation
        )
    }

    pub struct StoneLocation {

        pub let x: Int8
        pub let y: Int8

        pub init(x: Int8, y: Int8) {
            self.x = x
            self.y = y
        }

        pub fun key(): String {
            return self.x.toString().concat(",").concat(self.y.toString())
        }

        pub fun description(): String {
            return "x: ".concat(self.x.toString()).concat(", y: ").concat(self.y.toString())
        }

    }
}