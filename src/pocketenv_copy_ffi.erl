-module(pocketenv_copy_ffi).
-export([temp_path/0, compress/1, decompress/2, read_file/1, write_file/2,
         delete_file/1, random_hex/1, file_exists/1]).

%% Returns a unique temporary file path for a tar.gz archive.
temp_path() ->
    Hex = random_hex(16),
    TmpDir = case os:getenv("TMPDIR") of
        false -> "/tmp";
        D     -> string:trim(D, trailing, "/")
    end,
    list_to_binary(TmpDir ++ "/" ++ binary_to_list(Hex) ++ ".tar.gz").

%% Compresses a local file or directory into a tar.gz archive.
%% When compressing a directory, patterns from .pocketenvignore, .gitignore,
%% .npmignore, and .dockerignore are respected.
%% Returns {ok, ArchivePath} | {error, Reason}.
compress(SourcePath) ->
    Archive = temp_path(),
    SourceStr = binary_to_list(SourcePath),
    case filelib:is_dir(SourceStr) of
        true ->
            Patterns = load_ignore_patterns(SourceStr),
            BaseDir = case lists:last(SourceStr) of
                $/ -> SourceStr;
                _  -> SourceStr ++ "/"
            end,
            AllFiles = filelib:fold_files(SourceStr, ".*", true,
                                          fun(F, Acc) -> [F | Acc] end, []),
            Files = [F || F <- AllFiles,
                          not is_ignored(lists:nthtail(length(BaseDir), F), Patterns)],
            Entries = [{lists:nthtail(length(BaseDir), F), F} || F <- Files],
            create_tar(Archive, Entries);
        false ->
            Basename = binary_to_list(filename:basename(SourcePath)),
            create_tar(Archive, [{Basename, SourceStr}])
    end.

create_tar(Archive, Entries) ->
    ArchiveStr = binary_to_list(Archive),
    case erl_tar:create(ArchiveStr, Entries, [compressed]) of
        ok              -> {ok, Archive};
        {error, Reason} -> {error, format_error(Reason)}
    end.

%% Extracts a tar.gz archive into DestPath.
%% Returns {ok, nil} | {error, Reason}.
decompress(ArchivePath, DestPath) ->
    DestStr = binary_to_list(DestPath),
    case filelib:ensure_dir(DestStr ++ "/") of
        ok ->
            case erl_tar:extract(binary_to_list(ArchivePath),
                                 [compressed, {cwd, DestStr}]) of
                ok              -> {ok, nil};
                {error, Reason} -> {error, format_error(Reason)}
            end;
        {error, Reason} ->
            {error, atom_to_binary(Reason, utf8)}
    end.

%% Reads a file into a binary.
%% Returns {ok, Binary} | {error, Reason}.
read_file(Path) ->
    case file:read_file(Path) of
        {ok, Data}      -> {ok, Data};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

%% Writes binary data to a file, creating parent directories as needed.
%% Returns {ok, nil} | {error, Reason}.
write_file(Path, Data) ->
    PathStr = binary_to_list(Path),
    case filelib:ensure_dir(PathStr) of
        ok ->
            case file:write_file(PathStr, Data) of
                ok              -> {ok, nil};
                {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
            end;
        {error, Reason} ->
            {error, atom_to_binary(Reason, utf8)}
    end.

%% Deletes a file, ignoring errors.
delete_file(Path) ->
    file:delete(Path),
    nil.

%% Returns true if the path refers to an existing regular file.
file_exists(Path) ->
    filelib:is_regular(binary_to_list(Path)).

%% Returns a random lowercase hex string of 2*N characters.
random_hex(N) ->
    Bytes = crypto:strong_rand_bytes(N),
    iolist_to_binary([io_lib:format("~2.16.0b", [B]) || <<B>> <= Bytes]).

%% ---------------------------------------------------------------------------
%% Ignore file support
%% ---------------------------------------------------------------------------

%% Loads patterns from .pocketenvignore, .gitignore, .npmignore, .dockerignore
%% in Dir.  Each pattern is {include, PatternStr} or {negate, PatternStr}.
load_ignore_patterns(Dir) ->
    IgnoreFiles = [".pocketenvignore", ".gitignore", ".npmignore", ".dockerignore"],
    lists:flatmap(
        fun(F) -> read_ignore_file(filename:join(Dir, F)) end,
        IgnoreFiles
    ).

read_ignore_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} ->
            Lines = binary:split(Bin, [<<"\n">>, <<"\r\n">>], [global]),
            lists:filtermap(fun parse_ignore_line/1, Lines);
        _ ->
            []
    end.

parse_ignore_line(Line) ->
    Str = string:trim(binary_to_list(Line)),
    case Str of
        []         -> false;
        [$# | _]   -> false;
        [$! | Rest] -> {true, {negate, string:trim(Rest)}};
        _           -> {true, {include, Str}}
    end.

%% Returns true if RelPath should be excluded, processing patterns in order
%% (last matching pattern wins, negations can re-include).
is_ignored(RelPath, Patterns) ->
    Basename = filename:basename(RelPath),
    {Ignored, _LastPat} = lists:foldl(
        fun({Type, Pat}, {_IsIgnored, _} = Acc) ->
            case matches_pattern(RelPath, Basename, Pat) of
                true ->
                    case Type of
                        include -> {true, Pat};
                        negate  -> {false, Pat}
                    end;
                false ->
                    Acc
            end
        end,
        {false, none},
        Patterns
    ),
    Ignored.

%% Matches RelPath against a single gitignore-style pattern.
%% If the pattern contains no slash (after stripping a leading one), it is
%% matched against both the full relative path and the basename.
matches_pattern(RelPath, Basename, Pattern) ->
    %% Strip optional leading slash (anchors to root — we already work with
    %% relative paths, so the effect is the same).
    Pat = case Pattern of
        [$/ | Rest] -> Rest;
        _           -> Pattern
    end,
    %% A trailing slash means "match directories only"; we skip that
    %% distinction here and just strip it.
    Pat2 = case lists:reverse(Pat) of
        [$/ | RevRest] -> lists:reverse(RevRest);
        _              -> Pat
    end,
    Regex = glob_to_regex(Pat2),
    HasSlash = lists:member($/, Pat2),
    case HasSlash of
        true ->
            re_match(RelPath, Regex);
        false ->
            %% Pattern without slash matches anywhere in the path tree.
            re_match(RelPath, Regex) orelse re_match(Basename, Regex)
    end.

re_match(String, Regex) ->
    re:run(String, Regex, [{capture, none}]) =:= match.

%% Converts a gitignore-style glob to an Erlang regex string.
glob_to_regex(Glob) ->
    %% Escape regex metacharacters (all except *, ?, [ ] which we handle).
    Esc = re:replace(Glob, "([.+^${}()|\\\\])", "\\\\\\1",
                     [global, {return, list}]),
    %% Replace ** before *, so we don't double-process.
    S1 = re:replace(Esc,  "\\*\\*", "\x00DS\x00", [global, {return, list}]),
    S2 = re:replace(S1,   "\\*",    "[^/]*",       [global, {return, list}]),
    S3 = re:replace(S2,   "\x00DS\x00", ".*",      [global, {return, list}]),
    S4 = re:replace(S3,   "\\?",    "[^/]",        [global, {return, list}]),
    "^" ++ S4 ++ "(/.*)?$".

%% ---------------------------------------------------------------------------
%% Error formatting
%% ---------------------------------------------------------------------------

format_error({_Name, Reason}) ->
    iolist_to_binary(erl_tar:format_error(Reason));
format_error(Reason) when is_atom(Reason) ->
    iolist_to_binary(erl_tar:format_error(Reason));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
