-module(pocketenv_crypto_ffi).
-export([box_seal/2]).

%% Implements libsodium crypto_box_seal (anonymous sealed box) without libsodium:
%%
%%   1. Generate ephemeral X25519 keypair via :crypto
%%   2. Derive nonce = BLAKE2b-24(eph_pk || recipient_pk)  — matches libsodium exactly
%%   3. Encrypt with NaCl crypto_box via Kcl
%%   4. Output = eph_pk (32 bytes) || ciphertext
box_seal(Message, RecipientPK) ->
    {EphPK, EphSK} = crypto:generate_key(ecdh, x25519),
    Nonce = crypto:hash({blake2b, 24}, <<EphPK/binary, RecipientPK/binary>>),
    {Ciphertext, _State} = 'Elixir.Kcl':box(Message, Nonce, EphSK, RecipientPK),
    <<EphPK/binary, Ciphertext/binary>>.
