-module(ctags).
-mode(compile).
-export([main/1]).


-record(attrs, {filename, 
                lines=[], 
                line_text=[], 
                module, 
                behaviour,
                exports=[], 
                records=[],
                includes=[],
                functions=[]
               }).

main([String]) when String == "--version" ->
    io:format("Erlang Ctags 1.0 by Marc Guillon
    Compiled: Sep 27 2014, 18:23:25
    Addresses: <marc.guillon@users.sourceforge.net>
    Optional compiled features: +wildcards, +regex~n");


main(StringList) ->
    print_header(),
    AllCtags = lists:map(fun(Filename) -> parse(Filename) end,
                         StringList
                        ),
    print_ctags(lists:flatten(AllCtags)).



function_str(Function, Arity) ->
    io_lib:format("~s/~p", [Function, Arity]).

is_exported({_, FctName, FctArity, _}, Attrs) ->
    FunctionStr = function_str(FctName, FctArity),
    lists:keymember(FunctionStr, 2, Attrs#attrs.exports).


get_signature_elt({atom, _, Atom}) ->
    io_lib:format("~s", [Atom]);

get_signature_elt({var, _, Name}) ->
    io_lib:format("~s", [Name]);

get_signature_elt({string, _, String}) ->
    io_lib:format("\"~s\"", [String]);

get_signature_elt({nil, _}) ->
    "[]";

get_signature_elt({tuple, _, List}) ->
    io_lib:format("{~s}", [get_signature_elt(List)]);

get_signature_elt({cons, _, Cons1, {nil, _}}) ->
    io_lib:format("~s", [get_signature_elt(Cons1)]);

get_signature_elt({cons, _, Cons1, Cons2}) ->
    io_lib:format("[~s|~s]", 
                  [get_signature_elt(Cons1), get_signature_elt(Cons2)]);

get_signature_elt({match, _, Match1, Match2}) ->
    io_lib:format("~s=~s", 
                  [get_signature_elt(Match1), get_signature_elt(Match2)]);

get_signature_elt({op, _, Op, Arg1, Arg2}) ->
    io_lib:format("~s~s~s", 
                  [get_signature_elt(Arg1), Op, get_signature_elt(Arg2)]);

get_signature_elt({record, _, Record, Fields}) ->
    io_lib:format("#~s{~s}", 
                  [get_signature_elt({atom,0,Record}), get_signature_elt(Fields)]);

get_signature_elt({record_field, _, RecField1, RecField2}) ->
    io_lib:format("~s=~s", 
                  [get_signature_elt(RecField1), get_signature_elt(RecField2)]);

get_signature_elt(List) when is_list(List) ->
    F = fun(Elt) -> get_signature_elt(Elt) end,
    string:join(lists:map(F, List), 
                ", "
               );

get_signature_elt({_, _, Unknown}) ->
    io_lib:format("?~p?", [Unknown]);

get_signature_elt({_, _, Unknown1, Unknown2}) ->
    io_lib:format("?~p/~p?", [Unknown1, Unknown2]);

get_signature_elt({_, _, Unknown1, Unknown2, Unknown3}) ->
    io_lib:format("?~p/~p/~p?", [Unknown1, Unknown2, Unknown3]).


get_signature(Function) ->
    Arity = element(3, Function),
    Sig = element(4, Function),
    io_lib:format("/~p (~s)", [Arity, get_signature_elt(Sig)]).


parse_form({attribute, Line, module, ModuleName}, Attrs) ->
    Attrs#attrs{module = {Line, ModuleName}, lines = [Line|Attrs#attrs.lines]};

parse_form({attribute, Line, behaviour, Behaviour}, Attrs) ->
    Attrs#attrs{behaviour = {Line, Behaviour}, lines = [Line|Attrs#attrs.lines]};

parse_form({attribute,Line, export, Exports}, Attrs) ->
    F = fun({Function, Arity}) -> {Line, function_str(Function, Arity)}
        end,
    ExportedFunctions = lists:map(F, Exports),
    Attrs#attrs{exports = ExportedFunctions ++ Attrs#attrs.exports, lines = [Line|Attrs#attrs.lines]};

parse_form({attribute, Line, record, Record}, Attrs) ->
    Attrs#attrs{records = [{Line, element(1, Record)}|Attrs#attrs.records], lines = [Line|Attrs#attrs.lines]};

% Should not be parsed: this form means that we start analyzing the file File
%% parse_form({attribute, Line, file, File}, Attrs) ->
%%     io:format("FILE ~p~n", [File]),
%%     Attrs#attrs{includes = [{Line, element(1, File)}|Attrs#attrs.includes], lines = [Line|Attrs#attrs.lines]};

parse_form({function,_Line, Function, Arity, Clauses}, Attrs) ->
    F = fun(Clause) ->{ 
              element(2, Clause),     % line number
              Function,
              Arity,
              element(3, Clause)      % signature 
             }
        end,
    Fline = fun(Clause) ->element(2, Clause) end,

    NewFunctions = lists:map(F, Clauses),
    NeededLines = lists:map(Fline, Clauses),
    %io:format("=>> ~p~n", [NewFunctions]),
    UpdatedFunctions =  [NewFunctions | Attrs#attrs.functions],
    Attrs#attrs{functions = UpdatedFunctions, lines = [NeededLines|Attrs#attrs.lines]};

parse_form(_, Attrs) ->
    Attrs.

parse_forms(Forms, _Options) ->
    %io:format("Forms: ~p~nOptions: ~p~n", [Forms, Options]),
    F = fun(Elem, Attrs) -> parse_form(Elem, Attrs) end,
    Attrs = lists:foldl(F, #attrs{}, Forms),
    %io:format("Attrs=~p~n", [Attrs]),
    {ok, Attrs}.

keep_line(Line, LineNum, Attrs=#attrs{lines = [NextLine|Rest]}) when LineNum == NextLine ->
    %io:format("Keeping line ~p: ~s", [LineNum, Line]),
    CtagLine = io_lib:format("/^~s$/;\"", [string:strip(Line, right, $\n)]),
    Attrs#attrs{line_text = [{LineNum, CtagLine} | Attrs#attrs.line_text],
                lines = Rest
               };
keep_line(_Line, _LineNum, Attrs) ->
    Attrs.


load_lines(Fd, LineNum, Attrs) ->
    case io:get_line(Fd, "") of
        eof  -> file:close(Fd), {ok, Attrs};
        Line -> NewAttrs = keep_line(Line, LineNum, Attrs),
                load_lines(Fd, LineNum+1, NewAttrs)
    end.

load_lines(Attrs, Filename) ->
    Lines = lists:flatten(Attrs#attrs.lines),
    UpdatedAttrs = Attrs#attrs{lines = lists:usort(Lines), filename=Filename},
    %io:format("lines to read: ~p~n", [Lines]),
    {ok, Fd} = file:open(Filename, [read]),
    load_lines(Fd, 1, UpdatedAttrs).

%get_module(Attrs) ->
%    element(2, Attrs#attrs.module).

find_line([H|_T], LineNum) when LineNum == element(1, H) ->
    element(2, H);
find_line([_H|T], LineNum) ->
    find_line(T, LineNum);
find_line([], _LineNum) ->
    "no line".

get_line(Attrs, LineNum) ->
    find_line(Attrs#attrs.line_text, LineNum).

prepare_module_tag(#attrs{module=Module} = Attrs) when Module == undefined ->
    {
     "unknown",
     Attrs#attrs.filename,         % filename
     "0",                            % line
     "m"
    };

prepare_module_tag(#attrs{module=Module} = Attrs) ->
    {
     lists:flatten(io_lib:format("~p", [element(2, Module)])),      % module name
     Attrs#attrs.filename,         % filename
     get_line(Attrs, element(1, Module)),          % line
     "m",
     io_lib:format("line:~p", [element(1, Module)])
    }.

prepare_behaviour_tag(#attrs{behaviour=Behaviour} = Attrs) when Behaviour == undefined ->
    {
     "unknown",
     Attrs#attrs.filename,         % filename
     "0",                            % line
     "b"
    };

prepare_behaviour_tag(#attrs{behaviour=Behaviour} = Attrs) ->
    {
     lists:flatten(io_lib:format("~p", [element(2, Behaviour)])),      % 
     Attrs#attrs.filename,         % filename
     get_line(Attrs, element(1, Behaviour)),          % line
     "b",
     io_lib:format("line:~p", [element(1, Behaviour)])
    }.

prepare_export_tags(Attrs) ->
    lists:map(fun(Export) ->
                      %io:format("export ~p~n", [Export]),
                      {
                       lists:flatten(element(2, Export)),
                       Attrs#attrs.filename,
                       get_line(Attrs, element(1, Export)),
                       "e",
                       io_lib:format("line:~p", [element(1, Export)])

                       %io_lib:format("module:~s", [get_module(Attrs)])
                      } end,

              Attrs#attrs.exports
             ).

prepare_record_tags(Attrs) ->
    %io:format("=====prepare_record_tags  Attrs:~p~n", [Attrs]),
    lists:map(fun(Record) ->
                      %io:format("record ~p~n", [Record]),
                      {lists:flatten(io_lib:format("~p", [element(2, Record)])),
                       Attrs#attrs.filename,
                       get_line(Attrs, element(1, Record)),
                       "r",
                       io_lib:format("line:~p", [element(1, Record)])

                       %io_lib:format("module:~s", [get_module(Attrs)])
                      } end,

              Attrs#attrs.records
             ).

prepare_include_tags(Attrs) ->
    %io:format("==== include ~p =======~n", [Attrs#attrs.includes]),
    lists:map(fun(Include) ->
                      %io:format("include ~p~n", [Include]),
                      {lists:flatten(element(2, Include)),
                       Attrs#attrs.filename,
                       get_line(Attrs, element(1, Include)),
                       "i",
                       io_lib:format("line:~p", [element(1, Include)])

                       %io_lib:format("module:~s", [get_module(Attrs)])
                      } end,

              Attrs#attrs.includes
             ).

prepare_function_tags(Attrs) ->
    lists:map(fun(Function) ->
                      Access = case is_exported(Function, Attrs) of
                                   true -> "public";
                                   (_) -> "private"
                               end,
                      {
                       lists:flatten(io_lib:format("~p", [element(2, Function)])),
                       Attrs#attrs.filename,
                       get_line(Attrs, element(1, Function)),
                       "f",
                       %io_lib:format("module:~s", [get_module(Attrs)]),
                       io_lib:format("signature:~s", [get_signature(Function)]),
                       io_lib:format("line:~p", [element(1, Function)]),
                       io_lib:format("access:~s", [Access])
                      } end, 

              lists:flatten(Attrs#attrs.functions)
             ).

prepare_ctags(Attrs) ->
    Ctags = [prepare_module_tag(Attrs)
             , prepare_behaviour_tag(Attrs)
             , prepare_include_tags(Attrs)
             , prepare_record_tags(Attrs)
             , prepare_function_tags(Attrs)
             , prepare_export_tags(Attrs)
            ],
    {ok, lists:flatten(Ctags)}.

print_ctags(Ctags) ->
    lists:foreach(fun(Ctag) -> 
                          String =  string:join(tuple_to_list(Ctag), "\t"),                 
                          io:format("~s~n", [lists:flatten(String)])
                  end,

                  lists:keysort(1, Ctags)
                 ).

parse(Filename) ->
    {ok, Forms} = epp:parse_file(Filename, []),
    %io:format("Forms=~p~n", [Forms]),
    {ok, Attrs} = parse_forms(Forms, []),
    % TODO: sort the line list
    {ok, Attrs2} = load_lines(Attrs, Filename),
    %io:format("Attrs=~p~n", [Attrs2]),
    {ok, Ctags} = prepare_ctags(Attrs2),
    Ctags.
%io:format("Ctags=~p~n", [Ctags]),
%io:format("finished.~n").

print_header() ->
    io:format("!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;\" to lines/
              !_TAG_FILE_SORTED	0	/0=unsorted, 1=sorted, 2=foldcase/
              ~n").




