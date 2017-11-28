-module(network).

-export([ run/0 ]).

-define(OUTFILE, "out_network.hrl").

% The network contains of a single observer process that sets up and then
% observes the different network nodes.
run() ->

  % register self as global observer
  global:register_name(observer, self()),

  {{Year, Month, Day}, {Hour, Minute, _}} = erlang:localtime(),
  file:write_file(?OUTFILE, io_lib:format("~p-~p-~p ~p:~p | creating random network~n", [Year, Month, Day, Hour, Minute]), [write]),
  % 1. create random network
  %   1.1 deploy nodes on TEDA
  {ok, [_|Enodes]} = file:consult('./enodes.conf'),
  Nodes = deploy_nodes(Enodes),

  %   1.2 initialize network connections
  initialize_random_network(Nodes),

  observe_network().

observe_network() ->
  receive
    {node_status, Node, ConnectedClients, LinkedNodes} -> io:format("~p: Clients: ~p, Links: ~p~n", [Node, ConnectedClients, LinkedNodes]);
    {client_connected, Node, Client} -> io:format("~p: client ~p connected~n", [Node, Client]);
    {client_disconnected, Node, Client} -> io:format("~p: client ~p disconnected~n", [Node, Client]);
    {route_msg, Recipient, From, To} -> io:format("~p: routing message from ~p to ~p~n", [Recipient, From, To])
  end,
  observe_network().

deploy_nodes(Enodes) ->
  [ deploy_node(Enode) || Enode <- Enodes ].

deploy_node(Enode) ->
  spawn(Enode, node, init, []).

% For each Enode, set up network connections to other nodes
initialize_random_network(Enodes) ->
  [ initialize_random_network_links(Node, Enodes) || Node <- Enodes ].

initialize_random_network_links(Node, Enodes) ->
   OtherNodes = lists:delete(Node, Enodes),
   % removes 33% of the links
   RandomNodes = lists:filter(fun(_) -> random:uniform(3) /= 1 end, OtherNodes),
  Node ! { initialize_links, RandomNodes }.

