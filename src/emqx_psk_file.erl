%%--------------------------------------------------------------------
%% Copyright (c) 2013-2018 EMQ Enterprise, Inc. (http://emqtt.io)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_psk_file).

-include_lib("emqx/include/emqx.hrl").

-import(proplists, [get_value/2, get_value/3]).

-export([load/1, unload/0]).

%% Hooks functions
-export([on_psk_lookup/2]).

-define(TAB, ?MODULE).

%% Called when the plugin application start
load(Env) ->
    Tab = ets:new(?TAB, [set, named_table]),
    {ok, PskFile} = file:open(get_value(path, Env), [read, raw, binary, read_ahead]),
    preload_psks(Tab, PskFile, bin(get_value(delimiter, Env))),
    file:close(PskFile),
    emqx:hook('tls_handshake.psk_lookup', fun ?MODULE:on_psk_lookup/2, []).

%% Called when the plugin application stop
unload() ->
    emqx:unhook('tls_handshake.psk_lookup', fun ?MODULE:on_psk_lookup/2).

on_psk_lookup(ClientPSKID, UserState) ->
    {ok, UserState}.

preload_psks(Tab, FileHandler, Delimiter) ->
    case file:read_line(FileHandler) of
        {ok, Line} ->
            Result = binary:split(Line, Delimiter),
            logger:error("===== read result: ~p", [Result]);
        {error, Reason} ->
            logger:error("Read lines from PSK file: ~p", [Reason]),
            erlang:throw(read_psk_file, Reason)
    end.

bin(Str) when is_list(Str) -> list_to_binary(Str);
bin(Bin) when is_binary(Bin) -> Bin.