
pub contract test{
    pub struct interface op{
        pub fun f()
    }
    pub let m:{String:{op}}

    pub fun setM(k:String,v:{op}){
        self.m[k]=v
    }
    pub struct o: op{
        pub fun f(){}
    }
    init() {
        self.m={"aa": o()}
    }
}
