export const idlFactory = ({ IDL }) => {
  const Errors = IDL.Variant({ 'Insufficient_Funds' : IDL.Null });
  const Result = IDL.Variant({ 'ok' : IDL.Record({}), 'err' : Errors });
  return IDL.Service({ 'register' : IDL.Func([], [Result], []) });
};
export const init = ({ IDL }) => { return []; };
