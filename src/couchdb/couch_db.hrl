% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License.  You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
% License for the specific language governing permissions and limitations under
% the License.

-define(LOCAL_DOC_PREFIX, "_local/").
-define(DESIGN_DOC_PREFIX0, "_design").
-define(DESIGN_DOC_PREFIX, "_design/").

-define(JSON_ENCODE(V), mochijson2:encode(V)).
-define(JSON_DECODE(V), mochijson2:decode(V)).

-define(b2l(V), binary_to_list(V)).
-define(l2b(V), list_to_binary(V)).

-define(DEFAULT_ATTACHMENT_CONTENT_TYPE, <<"application/octet-stream">>).
        
-define(LOG_DEBUG(Format, Args),
    case couch_log:debug_on() of
        true -> error_logger:info_report(couch_debug, {Format, Args});
        false -> ok
    end).

-define(LOG_INFO(Format, Args),
    case couch_log:info_on() of
        true -> error_logger:info_report(couch_info, {Format, Args});
        false -> ok
    end).

-define(LOG_ERROR(Format, Args),
    error_logger:info_report(couch_error, {Format, Args})).

-record(doc_info,
    {
    id = <<"">>,
    rev = <<"">>,
    update_seq = 0,
    summary_pointer = nil,
    conflict_revs = [],
    deleted_conflict_revs = [],
    deleted = false
    }).

-record(full_doc_info,
    {id = <<"">>,
    update_seq = 0,
    deleted = false,
    rev_tree = []
    }).

-record(httpd,
    {mochi_req,
    method,
    path_parts,
    db_url_handlers,
    user_ctx
    }).
    

-record(doc,
    {
    id = <<"">>,
    revs = [],

    % the json body object.
    body = {[]},

    % each attachment contains:
    %    {data, Type, <<binary>>}
    % or:
    %    {pointer, Type, {FileHandle, StreamPointer, Length}}
    attachments = [],

    deleted = false,

    % key/value tuple of meta information, provided when using special options:
    % couch_db:open_doc(Db, Id, Options).
    meta = []
    }).
    


-record(user_ctx,
    {name=null,
    roles=[]
    }).

% This should be updated anytime a header change happens that requires more
% than filling in new defaults.
%
% As long the changes are limited to new header fields (with inline
% defaults) added to the end of the file, then there is no need to increment
% the disk revision number.
%
% if the disk revision is incremented, then new upgrade logic will need to be
% added to couch_db_updater:init_db.

-define(LATEST_DISK_VERSION, 0).

-record(db_header,
    {disk_version = ?LATEST_DISK_VERSION,  
     update_seq = 0,
     summary_stream_state = nil,
     fulldocinfo_by_id_btree_state = nil,
     docinfo_by_seq_btree_state = nil,
     local_docs_btree_state = nil,
     purge_seq = 0,
     purged_docs = nil,
     admins_ptr = nil 
    }).

-record(db,
    {main_pid=nil,
    update_pid=nil,
    compactor_pid=nil,
    fd,
    header = #db_header{},
    summary_stream,
    fulldocinfo_by_id_btree,
    docinfo_by_seq_btree,
    local_docs_btree,
    update_seq,
    name,
    filepath,
    validate_doc_funs=[],
    admins=[],
    admins_ptr=nil,
    user_ctx=#user_ctx{}
    }).


-record(view_query_args, {
    start_key = nil,
    end_key = {},
    count = 10000000000, % a huge huge default number. Picked so we don't have
                         % to do different logic for when there is no count
                         % limit
    update = true,
    direction = fwd,
    start_docid = nil,
    end_docid = {},
    skip = 0,
    group_level = 0,
    reduce = true,
    include_docs = false
}).

-record(group,
    {sig=nil,
    db=nil,
    fd=nil,
    name,
    def_lang,
    views,
    id_btree=nil,
    current_seq=0,
    purge_seq=0,
    query_server=nil
    }).

-record(view,
    {id_num,
    map_names=[],
    def,
    btree=nil,
    reduce_funs=[]
    }).

-record(server,{
    root_dir = [],
    dbname_regexp,
    max_dbs_open=100,
    current_dbs_open=0,
    start_time=""
    }).

-record(index_header,
    {seq=0,
    purge_seq=0,
    id_btree_state=nil,
    view_states=nil
    }).

% small value used in revision trees to indicate the revision isn't stored
-define(REV_MISSING, []).
