pub contract HelloWorld {

    pub var greeting: String

    // The init() function is required if the contract contains any fields.
    init() {
        self.greeting = "Hello, World NFTPL!"
    }

    pub fun changeGreeting(newGreeting: String) {
        self.greeting = newGreeting
    }

    pub fun show(): String {
        return self.greeting
    }
}
 