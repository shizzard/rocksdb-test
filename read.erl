#!/usr/bin/env escript

-record(opts, {
    repaired = false
}).

main([Filename]) ->
    ok = code:add_pathsa([os:getenv("DIR_ROCKSDB_EBIN")]),
    {module, _} = code:ensure_loaded(rocksdb),
    case try_db(Filename, #opts{}) of
        ok -> halt(0);
        error -> halt(1)
    end;

main(_) ->
    io:format("./~ts <rocksdb_filename>~n", [escript:script_name()]),
    halt(1).

try_db(Filename, Opts) ->
    case rocksdb:open(Filename, [{create_if_missing, false}]) of
        {ok, Db} ->
            try_verify(Filename, Db, Opts);
        {error, Reason} when not Opts#opts.repaired ->
            io:format("Failed to open database, attempting to repair: ~p~n", [Reason]),
            case try_repair(Filename) of
                ok -> try_db(Filename, Opts#opts{repaired = true});
                {error, _Reason} -> error
            end;
        {error, Reason} ->
            io:format("Failed to open database after repair: ~p~n", [Reason]),
            error
    end.

try_verify(Filename, Db, Opts) ->
    try
        {ok, Iterator} = rocksdb:iterator(Db, []),
        verify_keys(Iterator, Db)
    catch
        _:Error ->
            io:format("Exception during verification: ~p~n", [Error]),
            rocksdb:close(Db),
            case  Opts#opts.repaired of
                true ->
                    io:format("Failed to verify database~n"),
                    error;
                false ->
                    io:format("Failed to verify database, attempting to repair~n"),
                    case try_repair(Filename) of
                        ok -> try_db(Filename, Opts#opts{repaired = true});
                        {error, _Reason} -> error
                    end
            end
    end.

verify_keys(Iterator, Db) ->
    case rocksdb:iterator_move(Iterator, first) of
        done ->
            io:format("No keys found in the database~n"),
            ok;
        {ok, _Key, _Value} ->
            verify_all(Iterator, Db);
        {error, Reason} ->
            io:format("Error moving iterator to first key: ~p~n", [Reason]),
            error(Reason)
    end.

verify_all(Iterator, Db) ->
    case rocksdb:iterator_move(Iterator, next) of
        {ok, _Key, _Value} ->
            verify_all(Iterator, Db);
        done ->
            io:format("Successfully traversed all keys~n"),
            ok;
        {error, Reason} ->
            io:format("Error reading from database: ~p~n", [Reason]),
            error(Reason)
    end.

try_repair(Filename) ->
    case rocksdb:repair(Filename, []) of
        ok ->
            io:format("Database repaired successfully~n"),
            ok;
        {error, Reason} ->
            io:format("Failed to repair database: ~p~n", [Reason]),
            {error, Reason}
    end.
