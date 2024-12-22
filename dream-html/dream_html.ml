(* Copyright 2023 Yawar Amin

   This file is part of dream-html.

   dream-html is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the Free
   Software Foundation, either version 3 of the License, or (at your option) any
   later version.

   dream-html is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
   details.

   You should have received a copy of the GNU General Public License along with
   dream-html. If not, see <https://www.gnu.org/licenses/>. *)

include Pure_html
module Form = Form

let form f ?csrf req =
  req
  |> Dream.form ?csrf
  |> Lwt.map @@ function
     | `Ok values -> (
       match Form.validate f values with
       | Ok a -> `Ok a
       | Error list -> `Invalid list)
     | `Expired (values, float) -> (
       match Form.validate f values with
       | Ok a -> `Expired (a, float)
       | Error list -> `Invalid list)
     | `Wrong_session values -> (
       match Form.validate f values with
       | Ok a -> `Wrong_session a
       | Error list -> `Invalid list)
     | `Invalid_token values -> (
       match Form.validate f values with
       | Ok a -> `Invalid_token a
       | Error list -> `Invalid list)
     | `Missing_token values -> (
       match Form.validate f values with
       | Ok a -> `Missing_token a
       | Error list -> `Invalid list)
     | `Many_tokens values -> (
       match Form.validate f values with
       | Ok a -> `Many_tokens a
       | Error list -> `Invalid list)
     | `Wrong_content_type -> `Wrong_content_type

let query f req =
  match Form.validate f (Dream.all_queries req) with
  | Ok a -> `Ok a
  | Error list -> `Invalid list

let respond ?status ?code ?headers node =
  Dream.html ?status ?code ?headers (to_string node)

let send ?text_or_binary ?end_of_message websocket node =
  Dream.send ?text_or_binary ?end_of_message websocket (to_string node)

let set_body resp node =
  Dream.set_body resp (to_string node);
  Dream.set_header resp "Content-Type" "text/html"

let write stream node = Dream.write stream (to_string node)

let csrf_tag req =
  let open HTML in
  input [name "dream.csrf"; type_ "hidden"; value "%s" (Dream.csrf_token req)]

module Path = Path

type ('r, 'p) route = ('r, 'p) Path.t -> (Dream.request -> 'r) -> Dream.route

let get path func =
  Dream.get (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let post path func =
  Dream.post (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let put path func =
  Dream.put (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let delete path func =
  Dream.delete (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let head path func =
  Dream.head (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let connect path func =
  Dream.connect (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let options path func =
  Dream.options (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let trace path func =
  Dream.trace (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let patch path func =
  Dream.patch (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let any path func =
  Dream.any (Path.to_dream path.Path.rfmt) (Path.handler path.rfmt func)

let use = Dream.scope "/**"

module Livereload = struct
  let enabled =
    match Sys.getenv "LIVERELOAD" with
    | "1" -> true
    | _ | (exception _) -> false

  let endpoint = "/_livereload"

  let script =
    if enabled then
      HTML.script []
        {|
(() => {
  const retryIntervalMs = 500;
  const socketUrl = `ws://${location.host}%s`;
  const s = new WebSocket(socketUrl);

  s.onopen = _evt => {
    console.debug("Live reload: WebSocket connection open");
  };

  s.onclose = _evt => {
    console.debug("Live reload: WebSocket connection closed");

    function reload() {
      const s2 = new WebSocket(socketUrl);

      s2.onerror = _evt => {
        setTimeout(reload, retryIntervalMs);
      };

      s2.onopen = _evt => {
        location.reload();
      };
    };

    reload();
  };

  s.onerror = evt => {
    console.debug("Live reload: WebSocket error:", evt);
  };
})()
  |}
        endpoint
    else
      HTML.null []

  let route =
    if enabled then
      Dream.get endpoint (fun _ ->
          Dream.websocket (fun sock ->
              Lwt.bind (Dream.receive sock) (fun _ ->
                  Dream.close_websocket sock)))
    else
      Dream.no_route
end
