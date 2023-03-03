//This is not in use because of complexity issues, we cannot access playEditions if it is too large
pub contract BurnRegistry {

	access(self) let playEditions : {UInt64: [UInt64]}


	access(account) fun burnEdition(playId: UInt64, edition: UInt64){
		if self.playEditions[edition] != nil{
			self.playEditions[edition]!.append(edition)
			return
		}
		self.playEditions[edition] = [edition]
	}

	pub fun getBurnRegistry() : {UInt64:[UInt64]} {
		return self.playEditions
	}

	pub fun getNumbersBurned(_ playId:UInt64) : Int {
		if let burned = self.playEditions[playId] {
			return burned.length
		}
		return 0
	}

	pub fun getBurnedEditions(_ playId:UInt64) : [UInt64] {
		return self.playEditions[playId] ?? []
	}

	init() {
		self.playEditions={}

	}


}
