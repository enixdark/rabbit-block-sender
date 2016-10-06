-module(rabbit_block_sender_worker).
%-behaviour(gen_server).

-export([start_link/0]).
-export([init/1]).

% -export([init/1, handle_call/3, handle_cast/2, handle_info/2,
%         terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").

-record(state, {channel, exchange, process}).

start_link() ->
    io:format("starting event"),
    gen_server:start_link({global, ?MODULE}, ?MODULE, [], []).

%---------------------------
% Gen Server Implementation
% --------------------------

init([]) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_direct{}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {ok, Exchange} = application:get_env(rabbitmq_block_sender, exchange),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange,
                                                   type = <<"topic">>}),
    % amqp_channel:call(Channel, #'exchange.declare'{exchange = <<"test">>,
    %                                                 type = <<"topic">>}),

    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{queue = <<"sender">>, exclusive = false}),
    amqp_channel:call(Channel, #'queue.bind'{exchange = Exchange, routing_key = <<"#">>, queue = Queue}),
    amqp_channel:call(Channel, #'queue.bind'{exchange = Exchange, routing_key = <<"test">>, queue = Queue}),
    amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue,
                                                     no_ack = true}, self()),
    {ok, Process} = rabbit_block_sender_process:start_link(),
    % {ok, #state{channel = Channel, exchange = Exchange}}.
    loop(#state{channel = Channel, exchange = Exchange, process = Process}),
    {ok, #state{channel = Channel, exchange = Exchange, process = Process}}.



loop(State = #state{channel = Channel, exchange = Exchange, process = Process}) ->
    receive
        {#'basic.deliver'{routing_key = <<"#">>, delivery_tag = _}, #amqp_msg{payload = Body}} ->
            io:format(" [x] ~p:~p~n", [<<"#">>, Body]),
            rabbit_block_sender_process:process(Process, Channel, Exchange),
            loop(State)
        % {#'basic.deliver'{routing_key = <<"test">>, delivery_tag = _}, #amqp_msg{payload = Body}} ->
        %     io:format(" -> [x] ~p:~p~n", [<<"test">>, Body]),
        %     loop(State),
end.

