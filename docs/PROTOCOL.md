# Local receiver protocol · v1

Still listens on TCP port **8942**, on Wi-Fi, and advertises `_stillcast._tcp`. Bonjour is available to custom clients; the supplied browser remote pairs through a QR URL rather than automatic browser mDNS discovery. Browsers generally cannot enumerate Bonjour directly.

The app currently displays its `en0` IPv4 address. Open `http://<ip>:8942/#<token>`. The token is a fresh UUID without hyphens (122 bits of randomness) created at service start, and is immediately removed from the browser address after the page loads. It lives in page memory only, so refreshing requires reopening the original pairing link. It is not placed in API paths, query strings, local storage or logs.

All API requests require `Authorization: Bearer <token>`. The `Host` must match the displayed IPv4 address and port. Requests with an Origin header must originate from that same address. There is no CORS grant. Stopping the service discards the token, listener and all open connections. Starting never resumes old sessions.

`GET /` serves the remote page without credentials. `GET /api/state` returns name, title, source, playing, buffering, position, duration, volume, queue titles and playback error. `POST /api/command` accepts `application/json`:

```json
{"action":"load","url":"https://youtu.be/dQw4w9WgXcQ","title":"Optional title"}
```

| Action | Fields |
| --- | --- |
| `load` | `url`, optional `title`; replace current media |
| `enqueue` | `url`, optional `title`; queue, or play when idle |
| `play`, `pause`, `stop`, `next` | No additional fields |
| `seek` | `value`: finite nonnegative seconds, clamped to available duration |
| `volume` | `value`: finite number in 0…1 |

The queue holds 20 entries. Success is `{"ok":true}`; errors use `{"error":"…"}` and HTTP 400, 401, 403, 404, 422 or 500. A 200 means the command was accepted, not that the media provider has successfully started playback. Read `error`, `playing` and `buffering` from state for playback results.

HTTP/1.1 only, one request per connection, 16 KiB total request limit, eight simultaneous connections, eight-second connection deadline. Duplicate headers, chunked transfer, ambiguous lengths and pipelined extra data are rejected. Responses have `no-store`, a restrictive CSP, frame restrictions and no-referrer headers. Media URLs are passed to on-device players; the HTTP server does not fetch arbitrary URL contents.

This is a trusted-LAN protocol. HTTP provides no transport confidentiality or protection against an attacker already intercepting the Wi-Fi network. Do not expose the port to the public internet. There is no per-client identity, approval screen, persistent pairing or per-client revocation; stop/restart revokes every paired remote together. The session token grants all playback controls.

## v1.1 session controls

`GET /api/state` additionally includes `queueOnly` (boolean) and `theme` (`Graphite`, `Moss`, `Ocean`, `Clay`, `Plum`). The browser adapts its primary action to enqueue and hides transport controls in queue-only mode; the server independently rejects all actions except `enqueue` with HTTP 422. In this mode enqueue never starts playback on an idle screen. The receiver’s user chooses when to play, and native auto-next remains under that user’s settings. Queue-only remotes can still read titles and playback state.

Disconnect all remotes stops and restarts the listener with a new token, without replacing the current video. Sleep expiry pauses the player and stops receiving. Local wipe stops both receiving and playback before asynchronous cleanup. There is no remotely accessible wipe command.
