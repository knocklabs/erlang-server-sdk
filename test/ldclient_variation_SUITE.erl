-module(ldclient_variation_SUITE).

-include_lib("common_test/include/ct.hrl").

%% ct functions
-export([all/0]).
-export([init_per_testcase/2]).
-export([end_per_testcase/2]).

%% Tests
-export([
    sampling_zero_drops_events/1,
    sampling_one_sends_events/1,
    sampling_uses_probability/1
]).

all() ->
    [
        sampling_zero_drops_events,
        sampling_one_sends_events,
        sampling_uses_probability
    ].

init_per_testcase(_, Config) ->
    meck:new(ldclient_eval, [passthrough]),
    meck:new(ldclient_event_server, [passthrough]),
    meck:expect(ldclient_eval, flag_key_for_context,
        fun(_Tag, _FlagKey, _Context, _DefaultValue) ->
            {{0, true, fallthrough}, [event]}
        end),
    meck:expect(ldclient_event_server, add_event,
        fun(_Tag, _Event, _Options) ->
            ok
        end),
    Config.

end_per_testcase(_, _Config) ->
    meck:unload().

sampling_zero_drops_events(_) ->
    true = ldclient:variation(<<"flag">>, context(), false, #{event_sampling => 0.0}),
    true = ldclient:variation(<<"flag">>, context(), false, #{event_sampling => 0}),
    0 = meck:num_calls(ldclient_event_server, add_event, '_').

sampling_one_sends_events(_) ->
    true = ldclient:variation(<<"flag">>, context(), false, custom, #{event_sampling => 1.0}),
    true = ldclient:variation(<<"flag">>, context(), false, custom, #{event_sampling => 1}),
    2 = meck:num_calls(ldclient_event_server, add_event, [custom, event, #{}]).

sampling_uses_probability(_) ->
    meck:expect(ldclient_eval, flag_key_for_context,
        fun(_Tag, _FlagKey, _Context, _DefaultValue) ->
            {{0, true, fallthrough}, [first_event, second_event]}
        end),
    meck:new(rand, [unstick, passthrough]),
    meck:expect(rand, uniform, 0, 0.25),
    true = ldclient:variation(<<"flag">>, context(), false, #{event_sampling => 0.5}),
    2 = meck:num_calls(ldclient_event_server, add_event, '_'),
    1 = meck:num_calls(rand, uniform, []),

    meck:expect(rand, uniform, 0, 0.75),
    true = ldclient:variation(<<"flag">>, context(), false, #{event_sampling => 0.5}),
    2 = meck:num_calls(ldclient_event_server, add_event, '_'),
    2 = meck:num_calls(rand, uniform, []).

context() ->
    #{
        kind => <<"user">>,
        key => <<"user-key">>
    }.
