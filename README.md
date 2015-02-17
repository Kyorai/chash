# Riak's Consistant Hashing Library

This library is an extraction of the chash functionality from [riak_core](https://github.com/basho/riak_core).

## Use

    CH = chash:fresh(64, mariano).
    CHB = chashbin:create(CH).
    Key = {<<"foo">>, <<"bar">>},
    DocIdx = chash:key_of(Key).
    Itr = chashbin:iterator(DocIdx, CHB).
    N = 3.
    {Primaries, _} = chashbin:itr_pop(N, Itr).

change N to a different value to get a different amount of partitions.

## Test

    make test
    make qc

## License

Apache Public License 2.0, see LICENSE for details
