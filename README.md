# lc-bfeditor-rest


### REST services for BIBFRAME Editor application

#### Bootstrap and Deployment

This is a Roxy-based deployment, set for a app-type=rest as opposed to "bare".  

Only a single host local laptop/desktop environment has been accounted for at present.

* Edit deploy/build.config for settings.
* ./ml bootstrap
* ./ml deploy modules (this also handles setting up the REST API)

#### Sample calls:

The REST endpoint currently lives at port 8287.

No URL rewriting has been attempted yet.  TODO.

__Endpoint:__ /v1/resources/interface-bfeditor?

##### PUT 

* __Use:__ For ingesting a new graph, or overwriting and existing graph.  Requires BFE presentation or middle tier to supply both a UUID and a cataloging username, like khes, ntra, or cred.
* __Sample request:__ /v1/resources/interface-bfeditor?rs:user={user}&rs:uuid={uuid}
* __Request headers:__ Content-Type: text/turtle 
* __Body:__ A BIBFRAME graph, in Turtle serialization.
* __Response codes:__ 201 Created (application/json); 400 Bad Request (text/plain); 500 Internal Server Error (application/xml)
* __Sample output:__  

```
{
	"namedGraph": "/editor/cred/778cb924-2388-11e7-93ae-92361f002671",
    "uuid": "778cb924-2388-11e7-93ae-92361f002671",
    "insertedDocuments":["/triplestore/54e44924-2388-11ff-93bb-98d31f00e584.xml"]
}
```




