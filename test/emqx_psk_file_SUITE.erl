-module(emqx_psk_file_SUITE).

-compile(export_all).

-include_lib("emqx/include/emqx.hrl").

all() -> [{group, parser_encode},
          {group, parser_decode}
          ].

groups() ->
    RepeatOpt = {repeat_until_all_ok, 1},
    [
        {parser_encode, [RepeatOpt], [
            parser_dn_19_1_0
        ]},
        {parser_decode, [RepeatOpt], [
            parser_ad_19_0_0
        ]}
    ].

init_per_suite(Config) ->
    run_setup_steps(emqx),
    application:set_env(emqx_psk_file, parser,
                           [{worker_pool,8},
                            {call_timeout,5000},
                            {python,"python3"},
                            {path,local_path(["test"])}]),
    application:ensure_all_started(emqx_psk_file),
    Config.

end_per_suite(Config) ->
    timer:sleep(300),
    application:stop(emqx),
    Config.

parser_dn_19_1_0(_Config) ->
    OrgCommad = <<"{\"data_type\": \"requests\", \"data\": {\"request_type\": \"get_device_status\",\"request_id\": 1,\"parameters\": []}}">>,
    TranslatedCommand = <<"{\"cmd\": \"get\", \"req_id\": 1, \"res\": \"st\"}">>,

    emqx:subscribe(<<"dn/mqtt/tenantId/productId/deviceId/cmd/19/1/0">>),

    emqx:publish(emqx_message:make(<<"testclient">>, <<"dn/mqtt/tenantId/productId/deviceId/cmd/19/1/0">>, OrgCommad)),

    receive
      {dispatch,<<"dn/mqtt/tenantId/productId/deviceId/cmd/19/1/0">>,
                #mqtt_message{payload = TranslatedCommand}} ->
        ct:pal("received: ~p", [TranslatedCommand])
    after 1000 ->
        ct:fail({wait_msg_timeout, {mailbox, flush()}})
    end,
    ok.

parser_ad_19_0_0(_Config) ->
    OrgEvent = <<"[{\"tmp\": {\"ts\": 1547660823, \"v\": -3.7}}, {\"hmd\": {\"ts\": 1547660823, \"v\": 34}}]">>,
    TranslatedEvent = <<"{\"data_type\": \"events\", \"data\": [{\"temperature\": {\"time\": 1547660823, \"value\": -3.7}}, {\"humidity\": {\"time\": 1547660823, \"value\": 34}}]}">>,

    emqx:subscribe(<<"up/mqtt/tenantId/productId/deviceId/ad/19/0/0">>),

    emqx:publish(emqx_message:make(<<"testclient">>, <<"up/mqtt/tenantId/productId/deviceId/ad/19/0/0">>, OrgEvent)),

    receive
      {dispatch,<<"up/mqtt/tenantId/productId/deviceId/ad/19/0/0">>,
                #mqtt_message{payload = TranslatedEvent}} ->
        ct:pal("received: ~p", [TranslatedEvent])
    after 1000 ->
        ct:fail({wait_msg_timeout, {mailbox, flush()}})
    end,
    ok.

% =====================
run_setup_steps(App) ->
    NewConfig = generate_config(App),
    lists:foreach(fun set_app_env/1, NewConfig),
    {ok, _} = application:ensure_all_started(App).

generate_config(emqx) ->
    Schema = cuttlefish_schema:files([local_path(["deps","emqx", "priv", "emqx.schema"])]),
    Conf = conf_parse:file([local_path(["deps", "emqx","etc", "emqx.conf"])]),
    cuttlefish_generator:map(Schema, Conf).

get_base_dir(Module) ->
    {file, Here} = code:is_loaded(Module),
    filename:dirname(filename:dirname(Here)).

get_base_dir() ->
    get_base_dir(?MODULE).

local_path(Components, Module) ->
    filename:join([get_base_dir(Module) | Components]).

local_path(Components) ->
    local_path(Components, ?MODULE).

set_app_env({App, Lists}) ->
    lists:foreach(
      fun({acl_file, _Var}) ->
          application:set_env(App, acl_file, local_path(["deps", "emqx", "etc", "acl.conf"]));
        ({license_file, _Var}) ->
          application:set_env(App, license_file, local_path(["deps", "emqx", "etc", "emqx.lic"]));
        ({plugins_loaded_file, _Var}) ->
          application:set_env(App, plugins_loaded_file, local_path(["deps","emqx","test", "emqx_SUITE_data","loaded_plugins"]));
        ({Par, Var}) ->
          application:set_env(App, Par, Var)
      end, Lists).

flush() ->
    flush([]).
flush(Msgs) ->
    receive
        M -> flush([M|Msgs])
    after
        0 -> lists:reverse(Msgs)
    end.
