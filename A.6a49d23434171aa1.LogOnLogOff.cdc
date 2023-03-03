access(all) contract LogOnLogOff {
 
    // Declare a public field of type String.
    //
    // All fields must be initialized in the init() function.
    pub enum LogType: UInt8 {
        pub case logOff
        pub case logOn
    }
 
    priv var email: String
    priv var name: String
    priv var surName: String
    priv var logType: LogType
    priv var transactionTime: String
    priv var transactionTimeNumber: UInt256

    // The init() function is required if the contract contains any fields.
    init() {
        self.email= ""
        self.name= ""
        self.surName= ""
        self.logType= LogType.logOn
        self.transactionTime= ""
        self.transactionTimeNumber= 0
    }
 
    // Public function that returns our friendly greeting!
    access(self) fun getEmail(): String {
        return self.email
    }
 
    access(self) fun getName(): String {
        return self.name
    }
 
        access(self) fun getSurname(): String {
        return self.surName
    }
 
    access(all) fun set(email: String, name: String, surname: String, logtype: UInt8, transactionTime: String, transactionTimeNumber: UInt256) {
        self.email= email
        self.name= name
        self.surName= surname
        var selectedLog = LogType.logOn
        if LogType.logOn.rawValue==logtype{
            selectedLog=LogType.logOn
            }
            else if LogType.logOff.rawValue==logtype
            {
              selectedLog=LogType.logOff
            }
        self.logType = selectedLog
        self.transactionTime = transactionTime
        self.transactionTimeNumber = transactionTimeNumber
    }
}
