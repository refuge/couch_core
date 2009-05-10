// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License.  You may obtain a copy
// of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations under
// the License.

couchTests.view_errors = function(debug) {
  var db = new CouchDB("test_suite_db");
  db.deleteDb();
  db.createDb();
  if (debug) debugger;

  var doc = {integer: 1, string: "1", array: [1, 2, 3]};
  T(db.save(doc).ok);

  // emitting a key value that is undefined should result in that row not
  // being included in the view results
  var results = db.query(function(doc) {
    emit(doc.undef, null);
  });
  T(results.total_rows == 0);

  // if a view function throws an exception, its results are not included in
  // the view index, but the view does not itself raise an error
  var results = db.query(function(doc) {
    doc.undef(); // throws an error
  });
  T(results.total_rows == 0);

  // if a view function includes an undefined value in the emitted key or
  // value, an error is logged and the result is not included in the view
  // index, and the view itself does not raise an error
  var results = db.query(function(doc) {
    emit([doc._id, doc.undef], null);
  });
  T(results.total_rows == 0);
  
  // querying a view with invalid params should give a resonable error message
  var xhr = CouchDB.request("POST", "/test_suite_db/_temp_view?startkey=foo", {
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({language: "javascript", 
      map : "function(doc){emit(doc.integer)}"
    })
  });
  T(JSON.parse(xhr.responseText).error == "invalid_json");
  
  // views should ignore Content-Type, like the rest of CouchDB
  var xhr = CouchDB.request("POST", "/test_suite_db/_temp_view", {
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: JSON.stringify({language: "javascript", 
      map : "function(doc){}"
    })
  });
  T(xhr.status == 200);
  
  var map = function (doc) {emit(doc.integer, doc.integer);};
  
  try {
      db.query(map, null, {group: true});
      T(0 == 1);
  } catch(e) {
      T(e.error == "query_parse_error");
  }
  
  // reduce=false on map views doesn't work, so group=true will
  // never throw for temp reduce views.
  
  var designDoc = {
    _id:"_design/test",
    language: "javascript",
    views: {
      "no_reduce": {map:"function(doc) {emit(doc._id, null);}"},
      "with_reduce": {
        map:"function (doc) {emit(doc.integer, doc.integer)};",
        reduce:"function (keys, values) { return sum(values); };"}
    }
  };
  T(db.save(designDoc).ok);
  
  var designDoc2 = {
    _id:"_design/testbig",
    language: "javascript",
    views: {
      "reduce_too_big"  : {
        map:"function (doc) {emit(doc.integer, doc.integer)};",
        reduce:"function (keys, values) { var chars = []; for (var i=0; i < 1000; i++) {chars.push('wazzap');};return chars; };"}
    }
  };
  T(db.save(designDoc2).ok);
  
  
  try {
      db.view("test/no_reduce", {group: true});
      T(0 == 1);
  } catch(e) {
      T(e.error == "query_parse_error");
  }
  
  try {
    db.view("test/no_reduce", {reduce: true});
    T(0 == 1);
  } catch(e) {
    T(db.last_req.status == 400);
    T(e.error == "query_parse_error");
  }

  try {
      db.view("test/with_reduce", {group: true, reduce: false});
      T(0 == 1);
  } catch(e) {
      T(e.error == "query_parse_error");
  }

  // Check error responses for invalid multi-get bodies.
  var path = "/test_suite_db/_design/test/_view/no_reduce";
  var xhr = CouchDB.request("POST", path, {body: "[]"});
  T(xhr.status == 400);
  result = JSON.parse(xhr.responseText);
  T(result.error == "bad_request");
  T(result.reason == "Request body must be a JSON object");
  var data = "{\"keys\": 1}";
  xhr = CouchDB.request("POST", path, {body:data});
  T(xhr.status == 400);
  result = JSON.parse(xhr.responseText);
  T(result.error == "bad_request");
  T(result.reason == "`keys` member must be a array.");

  // if the reduce grows to fast, throw an overflow error
  var path = "/test_suite_db/_design/testbig/_view/reduce_too_big";
  xhr = CouchDB.request("GET", path);
  T(xhr.status == 500);
  result = JSON.parse(xhr.responseText);
  T(result.error == "reduce_overflow_error");
};
