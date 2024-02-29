//React Elements
import { useEffect, useState } from 'react';
import './App.css';
//Importing Dfinity libraries
import { Actor, HttpAgent } from "@dfinity/agent";
import { AuthClient } from "@dfinity/auth-client";
import { Principal } from "@dfinity/principal";
//Importing the contract interface
import {idlFactory as Contract_interface} from "./declarations/Contract";
import {idlFactory as Ledger_interface} from "./declarations/icp_ledger_canister";

//Options for creating AuthClient and authentication
let createOptions = {
  idleOptions: {
    disableIdle: false,
    idleTimeout: 6000000
  },
};
let loginOptions = {
  //How long the authentication will be valid in nanoseconds
  maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
  //Address of the Internet Identity service - global and local for tests 
  identityProvider:
  process.env.DFX_NETWORK === "ic"? "https://identity.ic0.app/#authorize": `http://localhost:4943?canisterId=${import.meta.env.CANISTER_ID_INTERNET_IDENTITY}#authorize`
};
const REGISTRATION_FEE =  50010000 //Registration cost including Ledger fee

function App() {

  const [contractActor, setContractActor] = useState<any>(null);
  const [ledgerActor, setLedgerActor] = useState<any>(null);

  async function connect() {
    let authClient = await AuthClient.create(createOptions);
    //Perform authentication using Internet Identity
    await authClient.login({...loginOptions});
    let identity = await authClient.getIdentity(); //Getting the user's identity
    //Creating an agent to interact with contracts
    let agent = new HttpAgent({
      host: import.meta.env.DFX_NETWORK === 'local' ? 'http://127.0.0.1:4943' : 'https://icp-api.io',
      identity
    });
    //If this is a test version on a local network, we get the public key of the subnet
    if (import.meta.env.DFX_NETWORK === 'local') {
      await agent.fetchRootKey();
    };

    //Importing contract id and Ledger using Vite env variables
    let contractId = import.meta.env.CONTRACT_ID;
    let ledgerId = import.meta.env.CANISTER_ID_ICP_LEDGER_CANISTER;
    //We create objects for authenticated interaction with contracts and save them to state variables
    let Contract_actor = Actor.createActor(Contract_interface, {
      agent: agent,
      canisterId: contractId
    });
    setContractActor(Contract_actor);
    let Ledger_actor = Actor.createActor(Ledger_interface, {
      agent: agent,
      canisterId: ledgerId
    });
    setLedgerActor(Ledger_actor);
  };

  async function approve_registration_cost() {
    //Importing the contract address using Vite env variables
    let Contract_principal = Principal.fromText(
      import.meta.env.CANISTER_ID,
    );
    //We approve the use of currency by contract
    let result = await ledgerActor.icrc2_approve({
      fee: [],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: REGISTRATION_FEE,
      expected_allowance: [],
      expires_at: [],
      spender: { owner: Contract_principal, subaccount: []},
    });
    //We print the result to the console or display it as a notification
    console.log(result);
  };

  async function register() {
    //Calling our contract to register
    let result = await contractActor.register();
    //Printing out result of the call
    console.log(result);
  };

  return (
  <>
    <button onClick={connect}>Connect</button>
    <button onClick={approve_registration_cost}>Approve registration cost</button>
    <button onClick={register}>Register</button>
  </>
  )
  
}

export default App;
