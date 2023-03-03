import os
import json

codes = {}
for c in open("contracts.txt").read().split("\n"):
    if c.find("A.")!=0: continue
    A, address, contract = c.split(".")
    codes[address]=""

for address in codes.keys():
    cmd = f"flow accounts get {address} -n mainnet --include contracts -o json"
    j = json.loads(os.popen(cmd).read())

    for contract in j["code"].keys():
        c = j["code"][contract]
        print(c)
        filename = ".".join(["A", address, contract, "cdc"])
        print(filename)
        open(filename,"wb").write(c.encode("utf8"))
        print(address, contract)

