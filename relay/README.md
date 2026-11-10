# Still screen connection service

A small, self-hosted, in-memory signaling service for the WebRTC screen-sharing mode. It does **not** host the local YouTube/link receiver and does not turn the app into Google Cast. It adds no analytics, database or access-log feature. Hosting, proxies, STUN and TURN providers may keep independent operational records.

## Development

Node 22+:

```sh
npm ci
npm test
npm audit --omit=dev
```

`server.mjs` requires `PUBLIC_ORIGIN` to be an exact HTTPS origin without a path/trailing slash. HTTP loopback is accepted only for local testing. The service listens on loopback:8080 by default; run behind a TLS reverse proxy. `BIND_ADDRESS=0.0.0.0` is appropriate inside the included container, which is exposed only to its reverse proxy.

For a local protocol-only test:

```sh
PUBLIC_ORIGIN=http://127.0.0.1:8080 node server.mjs
```

A local loopback URL is not a usable cross-device iOS deployment. iOS requires a trusted HTTPS endpoint, and desktop screen capture requires a secure browser context. Do not disable TLS verification or globally weaken ATS.

## Deployment template

1. Point a real domain at your server. Configure its firewall for HTTPS and for the independently deployed TURN service.
2. Copy `config.example.env` to `config.local.env`. Use your exact public HTTPS origin, your STUN/TURN URLs and a cryptographically random TURN shared secret (at least 32 bytes). Generate the secret using your platform’s secure secret manager or a local cryptographic tool. Do not commit it.
3. Deploy coturn or another compatible TURN REST-credential provider separately. `turnserver.example.conf` is an illustrative template, not a deployed service. Its shared secret must match the connection service. Set real certificates, realm, external/private addresses where needed, quotas and firewall rules; deny relay access to private and loopback destinations to avoid creating a network pivot. Assess and configure TURN logs/retention independently.
4. Set `SHARING_DOMAIN` in your shell and launch the optional Caddy/relay compose configuration. Caddy obtains TLS for that domain. The compose file does **not** deploy TURN.
5. Verify HTTPS/WSS, and test over two genuinely different networks with a forced relay path before distribution. Check NAT, UDP and TCP/TLS TURN paths. The templates have not been deployed or verified against a real domain in this workspace.
6. Enter the origin in Still’s Screen sharing settings. Publish the operator identity, privacy practices and costs for users. No default free server is included.

Review hosting limits before public exposure. Rooms are capped, messages and concurrent sockets are bounded, and create attempts are rate-limited, but the supplied service is not a managed anti-abuse platform. Add appropriate infrastructure controls and operator authentication/provisioning if running a public multi-tenant service. A denial-of-service attack can still affect availability.

## Protocol

Connect `wss://<origin>/signal`. Native clients can omit Origin; browser Origin must equal `PUBLIC_ORIGIN`. Tokens are lowercase 32-digit hexadecimal random values. Credentials are sent over the protected WebSocket, not URL query parameters. Invitations use `https://<origin>/#room=...&invite=...`; the page removes the fragment immediately and retains it only in memory.

Receiver creates a room:

```json
{"type":"create","room":"32 random hex digits","owner":"private receiver secret","invite":"separate invitation secret"}
```

Server replies `ready` with ICE servers. Sender joins with `join`, room, invite and `allowRecording` boolean; it receives `joined` and the receiver receives `peer-joined`. Only one sender is allowed. The private owner secret is never included in the sender invitation.

Sender sends `offer` with SDP, receiver sends `answer`. Both exchange `candidate`, `sdpMid` and integer `sdpMLineIndex`. The server validates roles, shapes and size before forwarding. The receiver sends `recording` with `active` only after sender opt-in; the service enforces that notification policy. It cannot prevent an unrelated recording tool.

`end` from the receiver revokes the room. Receiver disconnection leaves a 90-second reconnection grace. A matching private owner credential can resume and trigger sender renegotiation. Sessions expire after two hours. Memory state is lost on service restart; clients must create a new invitation. Rooms and capture are not silently re-created after explicit user stop.

TURN credentials expire after three hours so they cover the two-hour room lifetime. They use the TURN REST HMAC-SHA1 convention with a server-only shared secret. The shared secret is never returned to a client. This is credential authentication, not a choice of media cipher; WebRTC negotiates its own DTLS-SRTP transport encryption.
