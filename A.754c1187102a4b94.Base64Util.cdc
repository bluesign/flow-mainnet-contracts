pub contract Base64Util {
    pub fun encodeFromDict(_ dict: {String: String}): String {
        let jsonStr = Base64Util.dictToJsonStr(dict)
        return Base64Util.encode(jsonStr)
    }

    pub fun encode(_ str: String): String {
        let base64Map: {UInt8: String} = {
            0: "A", 1: "B", 2: "C", 3: "D",
            4: "E", 5: "F", 6: "G", 7: "H",
            8: "I", 9: "J", 10: "K", 11: "L",
            12: "M", 13: "N", 14: "O", 15: "P",
            16: "Q", 17: "R", 18: "S", 19: "T",
            20: "U", 21: "V", 22: "W", 23: "X",
            24: "Y", 25: "Z", 26: "a", 27: "b",
            28: "c", 29: "d", 30: "e", 31: "f",
            32: "g", 33: "h", 34: "i", 35: "j",
            36: "k", 37: "l", 38: "m", 39: "n",
            40: "o", 41: "p", 42: "q", 43: "r",
            44: "s", 45: "t", 46: "u", 47: "v",
            48: "w", 49: "x", 50: "y", 51: "z",
            52: "0", 53: "1", 54: "2", 55: "3",
            56: "4", 57: "5", 58: "6", 59: "7",
            60: "8", 61: "9", 62: "+", 63: "/"
        }

        var res = "";
        let bytes = str.utf8
        let remainder = bytes.length % 3
        while bytes.length % 3 != 0 {
            bytes.append(0)
        }
        var i = 0
        while i < bytes.length {
            res = res.concat(base64Map[bytes[i] >> 2]!)
            res = res.concat(base64Map[((bytes[i] << 6) >> 2) + (bytes[i + 1] >> 4)]!)
            res = res.concat(base64Map[((bytes[i + 1] << 4) >> 2) + (bytes[i + 2] >> 6)]!)
            res = res.concat(base64Map[((bytes[i + 2] << 2) >> 2)]!)
            i = i + 3
        }
        if remainder > 0 {
            res = res.slice(from: 0, upTo: res.length - (remainder == 1 ? 2 : 1))
        }
        return res
    }

    priv fun dictToJsonStr(_ dict: {String: String}): String {
        var res = "{"
        var flag = false
        for key in dict.keys {
            if !flag {
                flag = true
            } else {
                res = res.concat(",")
            }
            res = res.concat("\"")
                    .concat(key)
                    .concat("\":\"")
                    .concat(Base64Util.escape(dict[key]!))
                    .concat("\"")
        }
        res = res.concat("}")
        return res
    }

    priv fun escape(_ str: String): String {
        var res = ""
        var i = 0
        while i < str.length {
            let s = str.slice(from: i, upTo: i + 1)
            if s == "\"" || s == "\\" {
            res = res.concat("\\")
            }
            res = res.concat(s)
            i = i + 1
        }
        return res
    }
}
