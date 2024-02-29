import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export type Errors = { 'Insufficient_Funds' : null };
export type Result = { 'ok' : {} } |
  { 'err' : Errors };
export interface _SERVICE { 'register' : ActorMethod<[], Result> }
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: ({ IDL }: { IDL: IDL }) => IDL.Type[];
