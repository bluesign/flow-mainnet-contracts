pub contract HelloWorld {
    pub var greeting: String

    pub fun changeGreeting(newGreeting: String) {
        self.greeting = newGreeting
    }

    init() {
    self.greeting = "This is just a test contract."
    }
}
 