-module(pocketenv_crypto_ffi).
-export([box_seal/2]).

%% Implements libsodium crypto_box_seal (anonymous sealed box) without libsodium:
%%
%%   1. Generate ephemeral X25519 keypair via :crypto
%%   2. Derive nonce = first 24 bytes of BLAKE2b(eph_pk || recipient_pk)
%%   3. Encrypt with NaCl crypto_box via Kcl
%%   4. Output = eph_pk (32 bytes) || ciphertext
box_seal(Message, RecipientPK) ->
    {EphPK, EphSK} = crypto:generate_key(ecdh, x25519),
    FullHash = crypto:hash(blake2b, <<EphPK/binary, RecipientPK/binary>>),
    <<Nonce:24/binary, _/binary>> = FullHash,
    {Ciphertext, _State} = 'Elixir.Kcl':box(Message, Nonce, EphSK, RecipientPK),
    <<EphPK/binary, Ciphertext/binary>>.
