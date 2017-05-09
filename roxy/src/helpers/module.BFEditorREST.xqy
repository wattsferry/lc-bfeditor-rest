xquery version "1.0-ml";

module namespace edit = "http://marklogic.com/modules/lib/interface-bfeditor";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";
declare namespace idx = "info:lc/bibframe/editor/idx#";
declare variable $edit:permissions := (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update"));
declare variable $edit:spawn-options := <options xmlns="xdmp:eval"><transaction-mode>update-auto-commit</transaction-mode></options>;
declare variable $edit:mimes as element(sem:serializations) :=
    <sem:serializations>
        <sem:accept parse="n3">
            <sem:mimetype>text/n3</sem:mimetype>
        </sem:accept>
        <sem:accept parse="nquad">
            <sem:mimetype>application/n-quads</sem:mimetype>
        </sem:accept>
        <sem:accept parse="ntriple">
            <sem:mimetype>application/n-triples</sem:mimetype>
        </sem:accept>
        <sem:accept parse="rdfjson">
            <sem:mimetype>application/rdf+json</sem:mimetype>
        </sem:accept>
        <sem:accept parse="rdfxml">
            <sem:mimetype>application/rdf+xml</sem:mimetype>
        </sem:accept>
        <sem:accept parse="trig">
            <sem:mimetype>application/trig</sem:mimetype>
        </sem:accept>
        <sem:accept parse="triplexml">
            <sem:mimetype>application/vnd.marklogic.triples+xml</sem:mimetype>
        </sem:accept>
        <sem:accept parse="turtle">
            <sem:mimetype>text/turtle</sem:mimetype>
        </sem:accept>
    </sem:serializations>;
    
declare function edit:operation-get-graph($params as map:map, $accept as xs:string) as item()* {
    try {
        let $graph-iri := map:get($params, "graph")
        (: For some reason, sem:graph(sem:iri($graph-iri)) returns back duplicate triples per collection in parallel to the graph triple itself, so using cts:triples instead to de-dupe. :)
        (: A SPARQL named graph query with DESCRIBE or SELECT ?s ?p ?o also de-dupes, but cts:triples is faster. :)
        let $triples := cts:triples((), (), (), (), (), cts:collection-query($graph-iri))
        return
            if ($triples instance of empty-sequence()) then
                $triples
            else
                sem:rdf-serialize($triples, edit:parse-type($accept))
    } catch($e) {
        let $_ := xdmp:log($e, "error")
        return
           $e
    }
};

declare function edit:operation-get-list-graphs($params as map:map) as node() {
    try {
        let $start := xdmp:elapsed-time()
        let $user := map:get($params, "user")
        let $limit := (: limit 10 by default :)
            if (map:get($params, "limit") instance of empty-sequence()) then
                "limit=10"
            else
                "limit=" || map:get($params, "limit") cast as xs:string
        let $sort := (:ascending or descending:)
            if (fn:matches(map:get($params, "sort"), "ascending", "i")) then
                ("ascending", ">=")
            else
                ("descending", "<=")
        let $dateTime :=
            if (map:get($params, "dateTime")  castable as xs:dateTime) then
                map:get($params, "dateTime") cast as xs:dateTime
            else
                (:fn:current-dateTime():) xs:dateTime("2016-12-12T00:00:00Z")
        let $query := cts:properties-fragment-query(
            cts:and-query((
                cts:element-range-query(xs:QName("idx:graph-ingest-dt"), $sort[2], $dateTime), 
                cts:element-value-query(xs:QName("idx:graph-user"), $user)
            ))
        )
        let $_ := xdmp:log($query, "debug")
        let $earliest-tuple := cts:value-tuples(cts:element-reference(xs:QName("idx:graph-ingest-dt"), "type=dateTime"), ("limit=1", "ascending", "concurrent"))
        let $latest-tuple := cts:value-tuples(cts:element-reference(xs:QName("idx:graph-ingest-dt"), "type=dateTime"), ("limit=1", "descending", "concurrent"))
        let $edt := if ($earliest-tuple instance of empty-sequence()) then null-node{} else json:array-values($earliest-tuple)
        let $ldt := if ($latest-tuple instance of empty-sequence()) then null-node{} else json:array-values($latest-tuple)
        let $tuples := cts:value-tuples(
            (
                cts:element-reference(xs:QName("idx:graph-ingest-dt"), "type=dateTime"),
                cts:uri-reference(),
                cts:element-reference(xs:QName("idx:graph-user")),
                cts:element-reference(xs:QName("idx:graph-represents-work")),
                cts:element-reference(xs:QName("idx:graph-work-change-date")),
                cts:element-reference(xs:QName("idx:graph-work-label"))
            ), ($limit, $sort[1], "properties", "concurrent"), $query
        )
        let $graph-objects :=
            if (fn:count($tuples) gt 0) then
                array-node{
                    for $t in $tuples
                    return
                        object-node{
                            "graphIri": $t[2],
                            "graphIngestDateTime": $t[1],
                            "user": $t[3],
                            "representsWork": $t[4],
                            "workChangeDate": $t[5],
                            "workLabel": $t[6],
                            "docUris": array-node{
                                cts:uris((), (), cts:collection-query($t[2]))
                            }
                        }
                    }
            else
                null-node{}
        let $next-graph-dateTime := 
            if ($graph-objects instance of null-node()) then
                $graph-objects
            else if ($sort[1] eq "descending") then
                json:array-values($tuples[fn:last()])[1]
            else if ($sort[1] eq "ascending") then
                json:array-values($tuples[1])[1]
            else
                null-node{}
        return
            object-node{
                "matchingGraphs": $graph-objects,
                "elapsedTime": xdmp:elapsed-time() - $start,
                "requestedSortOrder": $sort[1],
                "requestedLimit": fn:substring-after($limit, "limit="),
                "requestedDateTime": $dateTime,
                "earliestDateTime": $edt,
                "latestDateTime": $ldt,
                "nextDateTime": $next-graph-dateTime
            }
    } catch($e) {
        let $_ := xdmp:log($e, "error")
        return
           $e
    }
};

declare function edit:operation-delete($params as map:map) as node() {
    try {
        let $graph-iri := sem:iri(map:get($params, "graph"))
        let $uuid := fn:tokenize($graph-iri, "/")[fn:last()]
        let $doc-uris := cts:uris((), (), cts:collection-query($graph-iri))
        return
            if (fn:count($doc-uris) gt 0) then
                let $delete := sem:graph-delete($graph-iri)
                let $response := object-node{
                    "namedGraph": $graph-iri, 
                    "uuid": $uuid, 
                    "deletedDocuments": array-node{$doc-uris}
                }
                return 
                    $response
            else
                null-node{}
    } catch($e) {
        let $_ := xdmp:log($e, "error")
        return
           $e
    }
};

declare function edit:operation-insert-or-update($params as map:map, $input as document-node()*, $method as xs:string, $contenttype as xs:string) as node() {
    try {
        let $cdt := fn:current-dateTime()
        let $date := (:fn:format-dateTime($cdt, "[Y0001]-[M01]-[D01]"):) $cdt cast as xs:string
        let $uuid := map:get($params, "uuid")
        let $user := map:get($params, "user")
        let $user-editor := "/editor/" || $user || "/"
        let $user-date := $user-editor || $date || "/"
        let $graph-iri := sem:iri($user-editor || $uuid)
        let $graph-cln-q := cts:collection-query($graph-iri cast as xs:string)
        let $graph-exists := cts:collections((), ("limit=1"), $graph-cln-q)
        let $collections := ($graph-iri cast as xs:string, "/editor/", "/editor/" || $date || "/", $user-editor, $user-date, "originalBF")
        let $triples := sem:rdf-parse($input, edit:parse-type($contenttype))
        let $insert := 
            if ($graph-exists instance of empty-sequence()) then
                (
                    sem:graph-insert($graph-iri, $triples, $edit:permissions, $collections),
                    xdmp:spawn-function(function() {
                        xdmp:document-set-properties($graph-iri, edit:graph-properties($triples, $graph-iri, $user, $uuid))
                    }, $edit:spawn-options)
                )
            else
                if (fn:matches($method, "PUT", "i")) then
                    (
                        xdmp:spawn-function(function() {sem:graph-delete($graph-iri)}, $edit:spawn-options),
                        sem:graph-insert($graph-iri, $triples, $edit:permissions, $collections),
                        xdmp:spawn-function(function() {
                            xdmp:document-set-properties($graph-iri, edit:graph-properties($triples, $graph-iri, $user, $uuid))
                        }, $edit:spawn-options)
                    )
                else (:POST:)
                    (
                        sem:graph-insert($graph-iri, $triples, $edit:permissions, $collections),
                        xdmp:spawn-function(function() {
                            xdmp:document-set-properties($graph-iri, edit:graph-properties((sem:graph($graph-iri), $triples), $graph-iri, $user, $uuid))
                        }, $edit:spawn-options)
                    )
        let $response := object-node{
            "namedGraph": $graph-iri, 
            "uuid": $uuid, 
            "insertedDocuments": array-node{$insert}
         }
         return 
            $response
    } catch($e) {
        let $_ := xdmp:log($e, "error")
        return
            $e
    }
};

declare private function edit:parse-type($thismime as xs:string) as xs:string {
    fn:normalize-space($edit:mimes/sem:accept[sem:mimetype eq $thismime]/@parse)
};

declare private function edit:graph-properties($triples as sem:triple*, $graph-iri as sem:iri, $user as xs:string, $uuid as xs:string) as element()* {
    let $store := sem:in-memory-store($triples)
    let $sparql := '
        PREFIX bf: <http://id.loc.gov/ontologies/bibframe/>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        SELECT ?work ?label ?changeDate WHERE {
            ?work rdf:type bf:Work ; rdfs:label ?label ; bf:adminMetadata/bf:changeDate ?changeDate .
        }'
    let $exec := sem:sparql($sparql, (), (), $store)
    let $graph-details :=
        if (fn:exists(map:get($exec, "work")) and fn:exists(map:get($exec, "changeDate")) and fn:exists(map:get($exec, "label"))) then
            (
                <idx:graph-represents-work>{map:get($exec, "work")}</idx:graph-represents-work>,
                <idx:graph-work-change-date>{map:get($exec, "changeDate")}</idx:graph-work-change-date>,
                <idx:graph-work-label>{map:get($exec, "label")}</idx:graph-work-label>,
                <idx:graph-status>populated</idx:graph-status>
            )
        else
            <idx:graph-status>unpopulated</idx:graph-status>
    let $_ := xdmp:log($exec, "debug")
    let $properties := (
        <idx:graph-ingest-dt>{fn:current-dateTime()}</idx:graph-ingest-dt>, 
        <idx:graph-uuid>{$uuid}</idx:graph-uuid>,
        <idx:graph-user>{$user}</idx:graph-user>,
        $graph-details
    )
    let $_ := xdmp:log($properties, "debug")
    return
        $properties
};