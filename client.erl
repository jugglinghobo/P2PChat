-module(client).
-export([run/0]).
-define(OUTFILE, "out_client.hrl").

run() ->
  {ok, [Cookie|Enodes]} = file:consult('./enodes.conf'),

  Username = get_username(),

  net_kernel:start([Username, longnames]),

  ACookie = list_to_atom(integer_to_list(Cookie)),
  erlang:set_cookie(node(), ACookie),

  ChosenEnode = choose_node(Enodes),
  ConnectedNode = connect_client(Username, ChosenEnode),
  io:format("connectedNode: ~p~n", [ConnectedNode]),
  % we can only access the global information after connecting
  spawn(ui, start, [self(), get_available_clients(ConnectedNode)]),

  maintain_connection(Username, ConnectedNode).

maintain_connection(Username, ConnectedNode) ->
  receive
    ping -> ping();
    {outgoing_msg, Msg, To} ->
      send_chat_msg(Msg, ConnectedNode, Username, To);
      % ui:prompt(self(), get_available_clients(ConnectedNode));

    {incoming_msg, Msg, From} ->
      global:send(observer, {route_msg, self(), From, Username, ConnectedNode, Msg}),
      ui:render_msg(Msg, From);
      % ui:prompt(self(), get_available_clients(ConnectedNode));
    quit -> quit(Username, ConnectedNode);
    list_users ->
      ui:render_peers(self(), get_available_clients(ConnectedNode))
  end,
  maintain_connection(Username, ConnectedNode).


connect_client(Username, Enode) ->
  io:format("Connecting to ~p...~n", [Enode]),
  net_kernel:connect_node(Enode),
  % sync global state (although this should happen automatically?)
  io:format("Syncing global state...~n"),
  global:sync(),
  io:format("Global after sync: ~p~n", [global:registered_names()]),
  io:format("Lookup Enode PID... "),
  ConnectedNode = global:whereis_name(Enode),
  io:format("~p~n", [ConnectedNode]),
  io:format("Sending {connect_client} Msg...~n"),
  ConnectedNode ! {connect_client, Username, self()},
  io:format("Done.~n"),
  ConnectedNode.

ping() ->
  io:format("PING~n").

send_chat_msg(Msg, ConnectedNode, Username, Peername) ->
  try
    global:send(observer, {route_msg, self(), Username, Peername, ConnectedNode, Msg}),
    ConnectedNode ! {route_msg, Username, Peername, Msg}
  catch
    {badarg, _} ->
      % TODO: Error handling
      io:format("ERROR: The chat message could not be sent.")
  end.

quit(Username, ConnectedNode) ->
  ConnectedNode ! {disconnect_client, Username, self()},
  receive
    {disconnect_successful, Node} -> io:format("Disconnected from ~p~n", [Node])
  end,
  global:unregister_name(node()),
  init:stop().

get_available_clients(ConnectedNode) ->
  io:format("connectedNode: ~p~n", [ConnectedNode]),
  ConnectedNode ! { request_available_clients, self() },
  receive
    {available_clients, AvailableClients} -> AvailableClients
  end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% HELPERS

% TODO: improve error handling
choose_node(Enodes) ->
  io:format("There are currently ~p Nodes in the network. ", [length(Enodes)]),
  io:format("Which one do you want to connect to?~n"),
  EnodeList = lists:zip(lists:seq(1, length(Enodes)), Enodes),
  [ io:format("~2.. B. ~p~n", [I, Enode]) || {I, Enode} <- EnodeList ],
  case io:fread("> ", "~d") of
    {ok, [Int]} ->
      {_, Choice} = lists:keyfind(Int, 1, EnodeList),
      Choice;
    {error, _} ->
      io:format("ERROR: please enter a number between 1 and ~p~n", [length(Enodes)]),
      choose_node(Enodes)
  end.

get_username() ->
  case io:fread("Please enter your username (atomic): ", "~a") of
    {ok, [Username]} -> Username;
    {error, _} ->
      io:format("ERROR: non-atomic username detected."),
      get_username()
  end.
