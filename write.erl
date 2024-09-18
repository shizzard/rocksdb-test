#!/usr/bin/env escript

-record(state, {
  db,
  value
}).

main([Filename]) ->
  ok = code:add_pathsa([os:getenv("DIR_ROCKSDB_EBIN")]),
  {module, _} = code:ensure_loaded(rocksdb),
  {ok, Db} = get_db(Filename),
  {ok, Value} = get_random_value(4096),
  write_endlessly(#state{db = Db, value = Value});

main(_) ->
  io:format("./~ts <rocksdb_filename>~n", [escript:script_name()]).



get_db(Filename) ->
  Options = [{create_if_missing, true}, {sync, true}],
  {ok, Db} = rocksdb:open(Filename, Options),
  {ok, Db}.

get_random_value(Length) ->
  {ok, crypto:strong_rand_bytes(Length)}.

write_endlessly(#state{db = Db, value = Value} = S0) ->
  {ok, Key} = get_random_value(512),
  rocksdb:put(Db, Key, Value, []),
  %io:put_chars("."),
  write_endlessly(S0).
