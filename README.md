# lc-bfeditor-rest


### REST services for BIBFRAME Editor application

#### Bootstrap and Deployment

This is a Roxy-based deployment, set for an app-type of "rest" as opposed to "bare".  This provides the MarkLogic REST API extension framework capabilities.

Only a single host local laptop/desktop environment has been accounted for at present.

* Edit deploy/build.config for settings.
* See deploy/ml-config.xml for added range indexes, enabled triple index, and security model settings.
* ./ml bootstrap
* ./ml deploy modules (this also handles setting up the REST API)
* No URL rewriting has been attempted yet for providing cleaner, RESTful URIs.  TODO.

#### Sample calls:

The REST endpoint currently lives at port 8287.

__Endpoint:__ /v1/resources/interface-bfeditor?

##### PUT 

* __Use:__ For ingesting a new graph, or overwriting an existing graph (via delete and new insertion).  Requires BFE presentation or middle tier to supply both a UUID and a cataloging username, like khes, ntra, or cred.
* __Outcome:__ Persists the named graph, with accompanying range-indexed document properties, as managed triples into the MarkLogic triple store, and returns a JSON response showing the document URI locations of the stored files.
* __Sample request:__ /v1/resources/interface-bfeditor?rs:user={user}&rs:uuid={uuid} (same as POST)
* __Request parameters:__
* * rs:user=(A cataloging/user shortname)
* * rs:uuid=(A UUID)
* __Request headers:__ Content-Type: text/turtle 
* __Request payload/body:__ A BIBFRAME graph, in Turtle serialization.  Use editor.ttl for test.
* __Response codes:__ 201 Created (application/json); 400 Bad Request (text/plain); 500 Internal Server Error (application/xml)
* __Sample output: (201 application/json)__  

```
{
    "namedGraph": "/editor/cred/778cb924-2388-11e7-93ae-92361f002671",
    "uuid": "778cb924-2388-11e7-93ae-92361f002671",
    "insertedDocuments":[
    	[${inserted triplestore doc URIs}]
    ]
}
```

##### POST

* __Use:__ For ingesting a new graph, or updating an existing graph.  Requires BFE presentation or middle tier to supply both a UUID and a cataloging username, like khes, ntra, or cred.
* __Outcome:__ Persists the new named graph, or adds triples to the existing named graph, with accompanying range-indexed document properties, as managed triples into the MarkLogic triple store, and returns a JSON response showing the document URI locations of the stored files.
* __Sample request:__ /v1/resources/interface-bfeditor?rs:user={user}&rs:uuid={uuid} (same as PUT)
* __Request parameters:__
* * rs:user=(A cataloging/user shortname)
* * rs:uuid=(A UUID)
* __Request headers:__ Content-Type: text/turtle 
* __Request payload/body:__ A BIBFRAME graph, in Turtle serialization. Use post-update.ttl or editor.ttl for test.
* __Response codes:__ 200 OK (application/json); 400 Bad Request (text/plain); 500 Internal Server Error (application/xml)
* __Sample output: (200 application/json)__  

```
{
    "namedGraph": "/editor/cred/778cb924-2388-11e7-93ae-92361f002671",
    "uuid": "778cb924-2388-11e7-93ae-92361f002671",
    "insertedDocuments":[
    	[${inserted/updated triplestore doc URIs}]
    ]
}
```

##### GET List Graphs

* __Use:__ For deleting an existing named graph.  Requires BFE presentation or middle tier to supply both a UUID and a cataloging username, like khes, ntra, or cred.
* __Outcome:__ Persists the new named graph, or adds triples to the existing named graph, with accompanying range-indexed document properties, as managed triples into the MarkLogic triple store, and returns a JSON response showing the document URI locations of the stored files.
* __Sample request:__ /v1/resources/interface-bfeditor?rs:type=ListGraphs&rs:user=(user)&rs:sort=decending&rs:limit=10&rs:dateTime=2017-05-01T15:11:36.0791-04:00
* __Request parameters:__
* * rs:type=ListGraphs
* * rs:user=(A cataloging/user shortname)
* * rs:sort=(ascending or descending)
* * rs:limit=(default page length, integer)
* * rs:dateTime=(a xs:dateTime stamp to determine a basis for a point in time to return graphs)
* __Request headers:__ None 
* __Request payload/body:__ None
* __Response codes:__ 200 OK (application/json); 400 Bad Request (text/plain); 404 Not Found (text/plain); 500 Internal Server Error (application/xml)
* __Sample output: (200 content-negotiable)__ 

```
{
    "matchingGraphs": [
     {
         "graphIri": ${graphIRI}
         "graphIngestDateTime": ${xs:dateTime},
         "user": ${cataloger/user},
         "representsWork": ${BIBFRAME Work IRI},
         "workChangeDate": ${BIBFRAME Work change date},
         "workLabel": ${BIBFRAME Work rdfs:label},
         "docUris": [
         	[${deleted triplestore doc URIs}]
         ]
     }
    ],
    "elapsedTime": ${xs:duration of execution runtime},
    "requestedSortOrder": ${user requested sort order},
    "ascendingResumptionToken": ${earliest graphIngestDateTime},
    "descendingResumptionToken": ${latest graphIngestDateTime}
}

```

##### GET Named Graph

* __Use:__ For deleting an existing named graph.  Requires BFE presentation or middle tier to supply both a UUID and a cataloging username, like khes, ntra, or cred.
* __Outcome:__ Persists the new named graph, or adds triples to the existing named graph, with accompanying range-indexed document properties, as managed triples into the MarkLogic triple store, and returns a JSON response showing the document URI locations of the stored files.
* __Sample request:__ /v1/resources/interface-bfeditor?rs:graph={named-graph IRI}&rs:type=GetGraph
* __Request parameters:__
* * rs:type=GetGraph
* * rs:graph=(Named Graph IRI, '/editor/user/uuid')
* __Request headers:__ Accept: (various RDF serializations) 
* __Request payload/body:__ None
* __Response codes:__ 200 OK (application/json); 400 Bad Request (text/plain); 404 Not Found (text/plain); 500 Internal Server Error (application/xml)
* __Sample output: (200 content-negotiable)__ 

```
Varied RDF serializations, depends on requested "Accept" type

```

##### DELETE

* __Use:__ For deleting an existing named graph.  Requires BFE presentation or middle tier to supply both a UUID and a cataloging username, like khes, ntra, or cred.
* __Outcome:__ Persists the new named graph, or adds triples to the existing named graph, with accompanying range-indexed document properties, as managed triples into the MarkLogic triple store, and returns a JSON response showing the document URI locations of the stored files.
* __Sample request:__ /v1/resources/interface-bfeditor?rs:uuid={uuid} 
* __Request parameters:__
* * rs:uuid (A UUID)
* __Request headers:__ None 
* __Request payload/body:__ None
* __Response codes:__ 200 OK (application/json); 404 Not Found (text/plain); 500 Internal Server Error (application/xml)
* __Sample output: (200 application/json)__ 

```
{
    "namedGraph": $graph-iri, 
    "uuid": $uuid, 
    "deletedDocuments": [
    	${deleted triplestore doc URIs}
    ]
}

```
