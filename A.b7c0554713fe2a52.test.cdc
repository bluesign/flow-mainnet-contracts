import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61


pub contract test {
	pub var array: [{String: UInt32}]
	pub fun getArray(): [{String: UInt32}] {
		return self.array
	}
	pub fun testGas2() {
		let tmp = self.array
		tmp.append({"tmp":0})
	}

	pub fun add(_ item: {String: UInt32}) {
		self.array.append(item)
	}
	pub fun remove(_ index: Int) {
		self.array.remove(at: index)
	}
	pub fun insert(_ index: Int, item: {String: UInt32}) {
		self.array.insert(at: index, item)
	}
	pub fun testGas1(batch: Int) {
		var i = 0
		while(i < batch) {
			self.array.append({"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": 1})
			i = i + 1
		}
	}

	pub fun assign() {
		let tmp = self.array
		
		//self.array = tmp
	}


	init() {
		self.array = []
	}

}