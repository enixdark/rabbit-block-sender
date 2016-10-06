-module(rabbit_block_sender_process).

-behavior(gen_server).

-export([start_link/0, init/1, process/3, handle_cast/2 , handle_call/3, terminate/2, handle_info/2, code_change/3]).
-include_lib("amqp_client/include/amqp_client.hrl").
-define(RKFormat,
        "~4.10.0B.~2.10.0B.~2.10.0B.~1.10.0B.~2.10.0B.~2.10.0B.~2.10.0B").
-record(state, {channel}).
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> 
    io:format("start process.....~n"),
	{ok, #state{}}.

process(Pid, Channel, Exchange) ->
	gen_server:cast(Pid, {process, Channel, Exchange}).

handle_call({process ,Channel, _}, _From , _State) ->
    {reply, ok, #state{channel = Channel}}.



handle_cast({process ,Channel, Exchange}, _State) ->
	Properties = #'P_basic'{content_type = <<"text/plain">>, delivery_mode = 1},
    {Date={Year,Month,Day},{Hour, Min,Sec}} = erlang:universaltime(),
    DayOfWeek = calendar:day_of_the_week(Date),
    RoutingKey = <<"test">>,

    io:format("processing...with ~s", [Exchange]),
    Message = list_to_binary(
                   io_lib:format(?RKFormat, [Year, Month, Day,
                                             DayOfWeek, Hour, Min, Sec])),
    BasicPublish = #'basic.publish'{exchange = Exchange,
                                    routing_key = RoutingKey},
    Content = #amqp_msg{props = Properties, payload = Message},
    amqp_channel:call(Channel, BasicPublish, Content),
	{noreply, #state{channel = Channel}}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_, #state{channel = Channel}) ->
    amqp_channel:call(Channel, #'channel.close'{}),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.