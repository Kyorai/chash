%% -------------------------------------------------------------------
%%
%% chash_eqc: QuickCheck tests for the chash module.
%%
%% Copyright (c) 2007-2011 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc  QuickCheck tests for the chash module

-module(chash_eqc).

-ifdef(TEST).
-ifdef(EQC).
-include_lib("eqc/include/eqc.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(RINGTOP, trunc(math:pow(2,160)-1)).  % SHA-1 space
-define(TEST_ITERATIONS, 50).
-define(QC_OUT(P),
        eqc:on_output(fun(Str, Args) -> io:format(user, Str, Args) end, P)).
-compile(export_all).

%% ====================================================================
%% eqc property
%% ====================================================================
prop_chash_next_index() ->
    ?FORALL(
       {PartitionExponent, Delta},
       {g_partition_exponent(), int()},
       ?TRAPEXIT(
          begin
              %% Calculate the number of paritions
              NumPartitions = trunc(math:pow(2, PartitionExponent)),
              %% Calculate the integer indexes around the ring
              %% for the number of partitions.
              Inc = ?RINGTOP div NumPartitions,
              Indexes = [Inc * X || X <- lists:seq(0, NumPartitions-1)],
              %% Create a chash tuple to use for calls to chash:successors/2
              %% and chash:next_index/2.
              %% The node value is not used and so just use the default
              %% localhost node value.
              Node = 'riak@127.0.0.1',
              CHash = {NumPartitions, [{Index, Node} || Index <- Indexes]},
              %% For each index around the ring add Delta to
              %% the index value and collect the results from calling
              %% chash:successors/2 and chash:next_index/2 for comparison.
              Results =
                  [{element(
                      1,
                      hd(chash:successors(<<(((Index + Delta) + ?RINGTOP)
                                             rem ?RINGTOP):160/integer>>,
                                          CHash))),
                    chash:next_index((((Index + Delta) + ?RINGTOP) rem ?RINGTOP),
                                     CHash)} ||
                      Index <- Indexes],
              {ExpectedIndexes, ActualIndexes} = lists:unzip(Results),
              ?WHENFAIL(
                 begin
                     io:format("ExpectedIndexes: ~p AcutalIndexes: ~p~n",
                               [ExpectedIndexes, ActualIndexes])
                 end,
                 conjunction(
                   [
                    {results, equals(ExpectedIndexes, ActualIndexes)}
                   ]))
          end
         )).

prop_size() ->
    ?FORALL(N, non_neg_int(),
            try
                chash:size(chash:fresh(N, the_node)) == N
            catch
                _:_ ->
                    not (N > 1 andalso (N band (N - 1) =:= 0))
            end).

prop_update() ->
    ?FORALL({N, CHash}, chash(),
            ?FORALL(Pos, choose(1, N),
                    begin
                        {Index, _} = lists:nth(Pos, chash:nodes(CHash)),
                        CHash1 = chash:update(Index, new, CHash),
                        lists:keyfind(Index, 1, chash:nodes(CHash1)) == {Index, new} andalso
                            length([new || new <- chash:members(CHash1)]) == 1 andalso
                            chash:contains_name(new, CHash1) andalso
                            chash:contains_name(first, CHash1) andalso
                            not chash:contains_name(new, CHash)
                    end)).

prop_successors_length() ->
    ?FORALL({Rand, {N, CHash}}, {int(), chash()},
            ?FORALL(Picks, choose(1, N),
                    length(chash:successors(chash:key_of(Rand), CHash, Picks)) == Picks)).

prop_inverse_pred() ->
    ?FORALL({Rand, {_, CHash}}, {int(), chash()},
            begin
                Key = chash:key_of(Rand),
                S = [I || {I,_} <- chash:successors(Key, CHash)],
                P = [I || {I,_} <- chash:predecessors(Key,CHash)],
                S == lists:reverse(P)
            end).

prop_next_index() ->
    ?FORALL({Rand, {_, CHash}}, {int(), chash()},
            begin
                <<I:160/integer>> = chash:key_of(Rand),
                I1 = chash:next_index(I, CHash),
                I =< I1 orelse I1 == 0
            end).

prop_predecessors_int() ->
    ?FORALL({Rand, {_, CHash}}, {int(), chash()},
            begin
                B = <<I:160/integer>> = chash:key_of(Rand),
                chash:predecessors(B, CHash) == chash:predecessors(I, CHash)
            end).

%%====================================================================
%% Generators
%%====================================================================

g_partition_exponent() ->
    choose(1, 12).

non_neg_int() ->
    ?LET(I, int(), abs(I)+1).

size() ->
    ?LET(N, choose(1, 5), trunc(math:pow(2, N))).

chash() ->
    ?LET(N, size(),
         {N, chash:fresh(N, first)}).


%%====================================================================
%% Helpers
%%====================================================================

test() ->
    test(100).

test(N) ->
    quickcheck(numtests(N, prop_chash_next_index())).

check() ->
    check(prop_chash_next_index(), current_counterexample()).

-include("eqc_helper.hrl").
-endif.
-endif.
