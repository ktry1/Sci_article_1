module {
    public type ListingData = {
        price: Nat;
        listed_time: Int;
    };

    public type Transaction = {
        from : Principal;
        to : Principal;
        price : Nat;
        time: Int;
    };

    public type Errors = {
        #Already_Initialized;
        #Unauthorized;
        #NFT_Not_Listed;
        #Self_Buy;
        #Insufficient_Funds;
        #Other_User_Transaction_In_Process;
        #Not_Owner;
        #NFT_Already_Listed;
        #NFT_Does_Not_Exist;
        #Invalid_Price;
    };
}