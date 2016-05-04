#!/usr/bin/env escript
%% -*- erlang -*-
-module(gen_escript).
-mode(compile).

main([Module]) ->
    {ok, _, BeamCode} = compile:file(Module++".erl", [binary]),
    escript:create(Module, [shebang, comment,{beam, BeamCode}]).
