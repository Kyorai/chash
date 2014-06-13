-module(chash_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

non_neg_int() ->
    ?LET(I, int(), abs(I)+1).

size() ->
    ?LET(N, choose(1, 5), trunc(math:pow(2, N))).

chash() ->
    ?LET(N, size(),
         {N, chash:fresh(N, first)}).

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

-include("eqc_helper.hrl").
