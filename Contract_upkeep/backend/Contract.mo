//Base Libaries
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import { recurringTimer } "mo:base/Timer";
//Importing Ledger smart-contract for payments
import Ledger "canister:icp_ledger_canister";
//Importing libraries from MOPS for custom types
import RBT "mo:stable-rbtree/StableRBTree";

actor Contract {
  let REGISTRATION_COST = 50000000;
  stable var user_donations = RBT.init<Principal, Nat>();

  //Errors to throw at users
  type Errors = {
    #Insufficient_Funds;
    #Already_Registered;
  };

  //Rejecting all anonymous messages
  system func inspect({ caller : Principal }) : Bool {
    not (Principal.isAnonymous(caller));
  };

  //Function for trimming inactive user profiles
  func trim_profiles() : async () {
    let min_donation = 5000;
    for (entry in RBT.entries(user_donations)){      
      if (entry.1 <= min_donation) {
      user_donations := RBT.delete(user_donations, Principal.compare , entry.0); 
      }
    }
  };
  //Timer for calling trimming function
  ignore recurringTimer(#seconds 2592000, trim_profiles);

  public shared({caller}) func register() : async (Result.Result<{}, Errors>) {

    //Checking if user is already registered
    let user_data = RBT.get(user_donations, Principal.compare, caller);
    switch (user_data) {
      case (null) {};
      case (?user_data) {return #err(#Already_Registered)};
    };

    //Transfering the registration cost in ICP from user to Contract
    let result = await Ledger.icrc2_transfer_from({
      amount = REGISTRATION_COST;
      created_at_time = null;
      from = { owner = caller; subaccount = null };
      fee = null;
      memo = null;
      spender_subaccount = null;
      to = { owner = Principal.fromActor(Contract); subaccount = null }
    });

    switch (result) {
      case (#Ok(Nat)) {
        user_donations := RBT.put(user_donations, Principal.compare, caller, 0);
        return #ok{};
      };
      case (#Err(any)) return #err(#Insufficient_Funds);
    };

  };
}