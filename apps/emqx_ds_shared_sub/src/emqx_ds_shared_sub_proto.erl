%%--------------------------------------------------------------------
%% Copyright (c) 2024-2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_ds_shared_sub_proto).

-include("emqx_ds_shared_sub_proto.hrl").

-include_lib("snabbkaffe/include/snabbkaffe.hrl").

-export([
    agent_connect_leader/4,
    agent_update_stream_states/4,
    agent_update_stream_states/5,
    agent_disconnect/4,

    leader_lease_streams/5,
    leader_renew_stream_lease/3,
    leader_renew_stream_lease/4,
    leader_update_streams/5,
    leader_invalidate/2,

    leader_lease_streams_v2/5,
    leader_renew_stream_lease_v2/3,
    leader_renew_stream_lease_v2/4,
    leader_update_streams_v2/5,
    leader_invalidate_v2/2
]).

-export([
    agent/3
]).

-type agent() :: ?agent(
    emqx_persistent_session_ds_shared_subs_agent:subscription_id(),
    emqx_persistent_session_ds:id(),
    pid()
).
-type leader() :: pid().
-type share_topic_filter() :: emqx_persistent_session_ds:share_topic_filter().
-type group() :: emqx_types:group().
-type version() :: non_neg_integer().
-type agent_metadata() :: #{
    id := emqx_persistent_session_ds:id()
}.

-type leader_stream_progress() :: #{
    stream := emqx_ds:stream(),
    progress := emqx_persistent_session_ds_shared_subs:progress()
}.

-type agent_stream_progress() :: emqx_persistent_session_ds_shared_subs:agent_stream_progress().

-export_type([
    agent/0,
    leader/0,
    group/0,
    version/0,
    leader_stream_progress/0,
    agent_stream_progress/0,
    agent_metadata/0
]).

-define(log_agent_msg(ToLeader, Msg),
    ?tp(debug, agent_to_leader, #{
        to_leader => ToLeader,
        proto_msg => ?format_agent_msg(Msg)
    })
).

-define(log_leader_msg(ToAgent, Msg),
    ?tp(debug, leader_to_agent, #{
        to_agent => ToAgent,
        proto_msg => ?format_leader_msg(Msg)
    })
).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

%% agent -> leader messages

-spec agent_connect_leader(leader(), agent(), agent_metadata(), share_topic_filter()) -> ok.
agent_connect_leader(ToLeader, FromAgent, AgentMetadata, ShareTopicFilter) when
    ?is_local_leader(ToLeader)
->
    send_agent_msg(ToLeader, ?agent_connect_leader(FromAgent, AgentMetadata, ShareTopicFilter));
agent_connect_leader(ToLeader, FromAgent, AgentMetadata, ShareTopicFilter) ->
    emqx_ds_shared_sub_proto_v2:agent_connect_leader(
        ?leader_node(ToLeader), ToLeader, FromAgent, AgentMetadata, ShareTopicFilter
    ).

-spec agent_update_stream_states(leader(), agent(), list(agent_stream_progress()), version()) -> ok.
agent_update_stream_states(ToLeader, FromAgent, StreamProgresses, Version) when
    ?is_local_leader(ToLeader)
->
    send_agent_msg(ToLeader, ?agent_update_stream_states(FromAgent, StreamProgresses, Version));
agent_update_stream_states(ToLeader, FromAgent, StreamProgresses, Version) ->
    emqx_ds_shared_sub_proto_v2:agent_update_stream_states(
        ?leader_node(ToLeader), ToLeader, FromAgent, StreamProgresses, Version
    ).

-spec agent_update_stream_states(
    leader(), agent(), list(agent_stream_progress()), version(), version()
) -> ok.
agent_update_stream_states(ToLeader, FromAgent, StreamProgresses, VersionOld, VersionNew) when
    ?is_local_leader(ToLeader)
->
    send_agent_msg(
        ToLeader, ?agent_update_stream_states(FromAgent, StreamProgresses, VersionOld, VersionNew)
    );
agent_update_stream_states(ToLeader, FromAgent, StreamProgresses, VersionOld, VersionNew) ->
    emqx_ds_shared_sub_proto_v2:agent_update_stream_states(
        ?leader_node(ToLeader), ToLeader, FromAgent, StreamProgresses, VersionOld, VersionNew
    ).

agent_disconnect(ToLeader, FromAgent, StreamProgresses, Version) when
    ?is_local_leader(ToLeader)
->
    send_agent_msg(ToLeader, ?agent_disconnect(FromAgent, StreamProgresses, Version));
agent_disconnect(ToLeader, FromAgent, StreamProgresses, Version) ->
    emqx_ds_shared_sub_proto_v2:agent_disconnect(
        ?leader_node(ToLeader), ToLeader, FromAgent, StreamProgresses, Version
    ).

%% leader -> agent messages

-spec leader_lease_streams_v2(
    agent(), group(), leader(), list(leader_stream_progress()), version()
) ->
    ok.
leader_lease_streams_v2(ToAgent, OfGroup, Leader, Streams, Version) when ?is_local_agent(ToAgent) ->
    send_leader_msg(ToAgent, ?leader_lease_streams(OfGroup, Leader, Streams, Version));
leader_lease_streams_v2(ToAgent, OfGroup, Leader, Streams, Version) ->
    emqx_ds_shared_sub_proto_v2:leader_lease_streams(
        ?agent_node(ToAgent), ToAgent, OfGroup, Leader, Streams, Version
    ).

-spec leader_renew_stream_lease_v2(agent(), group(), version()) -> ok.
leader_renew_stream_lease_v2(ToAgent, OfGroup, Version) when ?is_local_agent(ToAgent) ->
    send_leader_msg(ToAgent, ?leader_renew_stream_lease(OfGroup, Version));
leader_renew_stream_lease_v2(ToAgent, OfGroup, Version) ->
    emqx_ds_shared_sub_proto_v2:leader_renew_stream_lease(
        ?agent_node(ToAgent), ToAgent, OfGroup, Version
    ).

-spec leader_renew_stream_lease_v2(agent(), group(), version(), version()) -> ok.
leader_renew_stream_lease_v2(ToAgent, OfGroup, VersionOld, VersionNew) when
    ?is_local_agent(ToAgent)
->
    send_leader_msg(ToAgent, ?leader_renew_stream_lease(OfGroup, VersionOld, VersionNew));
leader_renew_stream_lease_v2(ToAgent, OfGroup, VersionOld, VersionNew) ->
    emqx_ds_shared_sub_proto_v2:leader_renew_stream_lease(
        ?agent_node(ToAgent), ToAgent, OfGroup, VersionOld, VersionNew
    ).

-spec leader_update_streams_v2(
    agent(), group(), version(), version(), list(leader_stream_progress())
) ->
    ok.
leader_update_streams_v2(ToAgent, OfGroup, VersionOld, VersionNew, StreamsNew) when
    ?is_local_agent(ToAgent)
->
    send_leader_msg(ToAgent, ?leader_update_streams(OfGroup, VersionOld, VersionNew, StreamsNew));
leader_update_streams_v2(ToAgent, OfGroup, VersionOld, VersionNew, StreamsNew) ->
    emqx_ds_shared_sub_proto_v2:leader_update_streams(
        ?agent_node(ToAgent), ToAgent, OfGroup, VersionOld, VersionNew, StreamsNew
    ).

-spec leader_invalidate_v2(agent(), group()) -> ok.
leader_invalidate_v2(ToAgent, OfGroup) when ?is_local_agent(ToAgent) ->
    send_leader_msg(ToAgent, ?leader_invalidate(OfGroup));
leader_invalidate_v2(ToAgent, OfGroup) ->
    emqx_ds_shared_sub_proto_v2:leader_invalidate(
        ?agent_node(ToAgent), ToAgent, OfGroup
    ).

%% leader -> agent messages, v1, ignore

-spec leader_lease_streams(term(), group(), leader(), list(leader_stream_progress()), version()) ->
    ok.
leader_lease_streams(_ToAgent, _OfGroup, _Leader, _Streams, _Version) -> ok.

-spec leader_renew_stream_lease(term(), group(), version()) -> ok.
leader_renew_stream_lease(_ToAgent, _OfGroup, _Version) -> ok.

-spec leader_renew_stream_lease(term(), group(), version(), version()) -> ok.
leader_renew_stream_lease(_ToAgent, _OfGroup, _VersionOld, _VersionNew) -> ok.

-spec leader_update_streams(term(), group(), version(), version(), list(leader_stream_progress())) ->
    ok.
leader_update_streams(_ToAgent, _OfGroup, _VersionOld, _VersionNew, _StreamsNew) -> ok.

-spec leader_invalidate(term(), group()) -> ok.
leader_invalidate(_ToAgent, _OfGroup) -> ok.

%%--------------------------------------------------------------------
%% Internal API
%%--------------------------------------------------------------------

agent(SessionId, SubscriptionId, Pid) ->
    _ = SessionId,
    ?agent(SessionId, SubscriptionId, Pid).

send_agent_msg(ToLeader, Msg) ->
    ?log_agent_msg(ToLeader, Msg),
    _ = erlang:send(ToLeader, Msg),
    ok.

send_leader_msg(ToAgent, Msg) ->
    ?log_leader_msg(ToAgent, Msg),
    _ = emqx_persistent_session_ds_shared_subs_agent:send(
        ?agent_pid(ToAgent), ?agent_subscription_id(ToAgent), Msg
    ),
    ok.
