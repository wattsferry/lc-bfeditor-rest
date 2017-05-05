xquery version "1.0-ml";

module namespace app = "http://marklogic.com/rest-api/resource/interface-bfeditor";
import module namespace edit = "http://marklogic.com/modules/lib/interface-bfeditor" at "/helpers/module.BFEditorREST.xqy";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";
declare namespace roxy = "http://marklogic.com/roxy";
declare namespace rapi = "http://marklogic.com/rest-api";

(:
 : To add parameters to the functions, specify them in the params annotations.
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") app:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :
 : To report errors in your extension, use fn:error(). For details, see
 : http://docs.marklogic.com/guide/rest-dev/extensions#id_33892, but here's
 : an example from the docs:
 : fn:error(
 :   (),
 :   "RESTAPI-SRVEXERR",
 :   ("415","Raven","nevermore"))
 :)

declare 
%roxy:params("type=xs:string", "graph=xs:string", "user=xs:string", "limit=xs:int", "dateTime=xs:dateTime", "sort=xs:string")
function app:get($context as map:map, $params as map:map) as document-node()* {
    let $_ := xdmp:log($context, "debug")
    let $accept := map:get($context, "accept-types")
    let $type := map:get($params, "type")
    let $get := 
        if (fn:matches($type, "GetGraph")) then
            edit:operation-get-graph($params, $accept)
        else if (fn:matches($type, "ListGraphs")) then
            edit:operation-get-list-graphs($params)
        else
            null-node{}
    return
        if ($get instance of element(error:error)) then
            (
                map:put($context, "output-types", "application/xml"),
                map:put($context, "output-status", (500, "Internal Server Error")),
                document{$get}
            )
        else if ($get instance of empty-sequence()) then
            (
                map:put($context, "output-types", "text/plain"),
                map:put($context, "output-status", (404, "Not Found")),
                document{"Graph Not Found"}
            )
        else if ($get instance of null-node()) then
            (
                map:put($context, "output-types", "text/plain"),
                map:put($context, "output-status", (400, "Bad Request")),
                document{"Bad Request"}
            )
        else
            (
                map:put($context, "output-types", $accept),
                map:put($context, "output-status", (200, "OK")),
                document{$get}
            )
};

declare 
%roxy:params("uri=xs:string", "format=xs:string", "user=xs:string", "uuid=xs:string")
function app:put($context as map:map, $params as map:map, $input as document-node()*) as document-node()? {
    let $contenttype := map:get($context, "input-types")
    let $put := edit:operation-insert-or-update($params, $input, "PUT", $contenttype)
    return
        if ($put instance of element(error:error)) then
            (
                map:put($context, "output-types", "application/xml"),
                map:put($context, "output-status", (500, "Internal Server Error")),
                document{$put}
            )
        else if ($put instance of object-node()) then
            (
                map:put($context, "output-types", "application/json"), 
                map:put($context, "output-status", (201, "Created")), 
                document{$put}
            )
        else
            (
                map:put($context, "output-types", "text/plain"),
                map:put($context, "output-status", (400, "Bad Request")),
                document{"Bad Request"}
            )
};

declare 
%roxy:params("uri=xs:string", "format=xs:string", "user=xs:string", "uuid=xs:string")
%rapi:transaction-mode("update")
function app:post($context as map:map, $params as map:map, $input as document-node()*) as document-node()* {
    let $contenttype := map:get($context, "input-types")
    let $post := edit:operation-insert-or-update($params, $input, "POST", $contenttype)
    return
        if ($post instance of element(error:error)) then
            (
                map:put($context, "output-types", "application/xml"),
                map:put($context, "output-status", (500, "Internal Server Error")),
                document{$post}
            )
        else if ($post instance of object-node()) then
            (
                map:put($context, "output-types", "application/json"), 
                map:put($context, "output-status", (200, "OK")), 
                document{$post}
            )
        else
            (
                map:put($context, "output-types", "text/plain"),
                map:put($context, "output-status", (400, "Bad Request")),
                document{"Bad Request"}
            )
};

declare 
%roxy:params("graph=xs:string")
function app:delete($context as map:map, $params as map:map) as document-node()? {
    let $graph := map:get($params, "graph")
    let $delete := edit:operation-delete($params)
    let $log := xdmp:log("DELETE operation called for named graph: " || $graph, "debug")
    return
        if ($delete instance of element(error:error)) then
            (
                map:put($context, "output-types", "application/xml"), 
                map:put($context, "output-status", (500, "Internal Server Error")),
                document{$delete}
            )
        else if ($delete instance of object-node() and fn:count($delete/deletedDocuments) gt 0) then
            (
                map:put($context, "output-types", "application/json"), 
                map:put($context, "output-status", (200, "OK")), 
                document{$delete}
            )
        else (: $delete instance of null-node() :)
            (
                map:put($context, "output-types", "text/plain"), 
                map:put($context, "output-status", (404, "Not Found")),        
                document{"Operation failed because graph " || $graph || " not found."}
            )
};