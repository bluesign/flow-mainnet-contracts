// forked from bjartek's Clock.cdc: https://github.com/findonflow/find/blob/main/contracts/Clock.cdc
pub contract Clock{
	access(contract) var mockClock: UFix64
	access(contract) var enabled: Bool

    pub event ContractInitialized()
    pub event MockTimeEnabled()
    pub event MockTimeDisabled()
    pub event MockTimeAdvanced(amount: UFix64)

    pub let ClockManagerStoragePath: StoragePath

    pub resource ClockManager {

        pub fun turnMockTimeOn() {
            pre {
                Clock.enabled == false : "mock time is already ON"
            }

            Clock.enabled = true
            emit MockTimeEnabled()

        }

        pub fun turnMockTimeOff() {
            pre {
                Clock.enabled == true : "mock time is already OFF"
            }

            Clock.enabled = false
            emit MockTimeDisabled()
        }

        pub fun advanceClock(_ duration: UFix64) {
            pre {
                Clock.enabled == true : "mock time keeping is not enabled"
            }

            Clock.mockClock = Clock.mockClock + duration
            emit MockTimeAdvanced(amount: duration)
        }

    }

	pub fun getTime() : UFix64 {
		if self.enabled {
			return self.mockClock 
		}
		return getCurrentBlock().timestamp
	}

	init() {
		self.mockClock = 0.0
		self.enabled = false

        self.ClockManagerStoragePath = /storage/kissoClockManager

        let clockManager <- create ClockManager()
        self.account.save(<- clockManager, to: self.ClockManagerStoragePath)

        emit ContractInitialized()
	}

}