CREATE TABLE users (
    id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    handle text,
    name text
);

INSERT INTO users (handle, name) VALUES ('johndoe', 'John');

INSERT INTO omni_httpd.listeners (port, query) VALUES (9000, $$
SELECT omni_httpd.http_response(headers => array[omni_httpd.http_header('content-type', 'text/html')], body => 'Hello, <b>' || users.name || '</b>!'), 1 AS priority
       FROM request
       INNER JOIN users ON string_to_array(request.path,'/', '') = array[NULL, 'users', users.handle]
UNION
SELECT omni_httpd.http_response(body => request.headers::text), 1 AS priority FROM request WHERE request.path = '/headers'
UNION
SELECT omni_httpd.http_response(body => request.body), 1 AS priority FROM request WHERE request.path = '/echo'
UNION
SELECT omni_httpd.http_response(status => 404, body => json_build_object('method', request.method, 'path', request.path, 'query_string', request.query_string)), 0 AS priority
       FROM request
ORDER BY priority DESC
$$);

-- Now, the actual tests

-- FIXME: for the time being, since there's no "request" extension yet, we're shelling out to curl

\! curl --retry-connrefused --retry 10  --retry-max-time 10 --silent -w '\n%{response_code}\nContent-Type: %header{content-type}\n\n' http://localhost:9000/test?q=1

\! curl --retry-connrefused --retry 10  --retry-max-time 10 --silent -w '\n%{response_code}\nContent-Type: %header{content-type}\n\n' -d 'hello world' http://localhost:9000/echo

\! curl --retry-connrefused --retry 10  --retry-max-time 10 --silent -w '\n%{response_code}\nContent-Type: %header{content-type}\n\n' http://localhost:9000/users/johndoe

\! curl --retry-connrefused --retry 10  --retry-max-time 10 --silent -A test-agent http://localhost:9000/headers

-- Try changing configuration

UPDATE omni_httpd.listeners SET port = 9001;

\! curl --retry-connrefused --retry 10  --retry-max-time 10 --silent -w '\n%{response_code}\nContent-Type: %header{content-type}\n\n' http://localhost:9001/test?q=1

\! curl --silent -w '\n%{exitcode}' http://localhost:9000/test?q=1