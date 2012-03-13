% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

-module(couch_httpd_changes).
-include_lib("couch/include/couch_db.hrl").

-export([handle_changes_req/2]).

handle_changes_req(#httpd{method='POST'}=Req, Db) ->
    couch_httpd:validate_ctype(Req, "application/json"),
    handle_changes_req1(Req, Db);
handle_changes_req(#httpd{method='GET'}=Req, Db) ->
    handle_changes_req1(Req, Db);
handle_changes_req(#httpd{path_parts=[_,<<"_changes">>]}=Req, _Db) ->
    couch_httpd:send_method_not_allowed(Req, "GET,HEAD,POST").

handle_changes_req1(Req, #db{name=DbName}=Db) ->
    AuthDbName = ?l2b(couch_config:get("couch_httpd_auth",
            "authentication_db")),
    case AuthDbName of
    DbName ->
        case (catch couch_db:check_is_admin(Db)) of
        ok ->
            do_changes_req(Req, Db);
        _ ->
            throw({forbidden, <<"Only admins can access _users">>})
        end;
    _ ->
        do_changes_req(Req, Db)
    end.

do_changes_req(Req, Db) ->
    MakeCallback = fun(Resp) ->
        fun({change, Change, _}, "continuous") ->
            couch_httpd:send_chunk(Resp, [?JSON_ENCODE(Change) | "\n"]);
        ({change, Change, Prepend}, _) ->
            couch_httpd:send_chunk(Resp, [Prepend, ?JSON_ENCODE(Change)]);
        (start, "continuous") ->
            ok;
        (start, _) ->
            couch_httpd:send_chunk(Resp, "{\"results\":[\n");
        ({stop, EndSeq}, "continuous") ->
            couch_httpd:send_chunk(
                Resp,
                [?JSON_ENCODE({[{<<"last_seq">>, EndSeq}]}) | "\n"]
            ),
            couch_httpd:end_json_response(Resp);
        ({stop, EndSeq}, _) ->
            couch_httpd:send_chunk(
                Resp,
                io_lib:format("\n],\n\"last_seq\":~w}\n", [EndSeq])
            ),
            couch_httpd:end_json_response(Resp);
        (timeout, _) ->
            couch_httpd:send_chunk(Resp, "\n")
        end
    end,
    ChangesArgs = parse_changes_query(Req),
    ChangesFun = couch_changes:handle_changes(ChangesArgs, Req, Db),

    couch_stats_collector:increment(
        {httpd, clients_requesting_changes}),
    try
        do_changes_req(Db, Req, ChangesArgs, ChangesFun, MakeCallback)
    after
        couch_stats_collector:decrement(
            {httpd, clients_requesting_changes})
    end.


do_changes_req(Db, Req, #changes_args{feed=normal}, ChangesFun, MakeCallback) ->
    {ok, Info} = couch_db:get_db_info(Db),
    CurrentEtag = couch_httpd:make_etag(Info),
    couch_httpd:etag_respond(Req, CurrentEtag, fun() ->
                {ok, Resp} = couch_httpd:start_json_response(Req, 200,
                    [{"ETag", CurrentEtag}]),
                ChangesFun(MakeCallback(Resp))
        end);
do_changes_req(Db, Req, _ChangesArgs, ChangesFun, MakeCallback) ->
    % "longpoll" or "continuous"
    {ok, Resp} = couch_httpd:start_json_response(Req, 200),
    ChangesFun(MakeCallback(Resp)).

parse_changes_query(Req) ->
    lists:foldl(fun({Key, Value}, Args) ->
        case {Key, Value} of
        {"feed", _} ->
            Args#changes_args{feed=Value};
        {"descending", "true"} ->
            Args#changes_args{dir=rev};
        {"since", _} ->
            Args#changes_args{since=list_to_integer(Value)};
        {"limit", _} ->
            Args#changes_args{limit=list_to_integer(Value)};
        {"style", _} ->
            Args#changes_args{style=list_to_existing_atom(Value)};
        {"heartbeat", "true"} ->
            Args#changes_args{heartbeat=true};
        {"heartbeat", _} ->
            Args#changes_args{heartbeat=list_to_integer(Value)};
        {"timeout", _} ->
            Args#changes_args{timeout=list_to_integer(Value)};
        {"include_docs", "true"} ->
            Args#changes_args{include_docs=true};
        {"conflicts", "true"} ->
            Args#changes_args{conflicts=true};
        {"filter", _} ->
            Args#changes_args{filter=Value};
        _Else -> % unknown key value pair, ignore.
            Args
        end
    end, #changes_args{}, couch_httpd:qs(Req)).