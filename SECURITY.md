# Security policy

## Experimental status

PhoneView is a local development prototype. It has not received a professional security audit and should not be treated as production software.

## Network exposure

Some components listen on all local interfaces and do not authenticate clients:

- `8765`: PhoneView H.264 ingest.
- `8999`: PhoneView viewer and control relay.
- `12004`: PhoneView/iPhone Direct DeviceKit service.
- `12005`: iPhone Mac DeviceKit service.

Run the projects only on networks you trust. Do not create router port-forwarding rules, public tunnels, or internet-facing deployments for these ports. A production redesign should add mutual authentication, encryption, session authorization, and explicit peer approval.

## Sensitive data

ReplayKit can capture notifications and other personal screen content. Stop the broadcast before entering or displaying sensitive information. Do not attach logs or recordings to public issues without reviewing and redacting them.

## Signing

Use your own development team, certificates, provisioning profiles, App Groups, and unique bundle identifiers. Never commit provisioning profiles, `.p12` files, private keys, Apple account credentials, device UDIDs, or personal IP addresses.

## Reporting a vulnerability

Please open a GitHub issue only for non-sensitive security hardening discussions. For a vulnerability that could expose private data or enable remote control, contact the repository owner privately through their GitHub profile rather than publishing exploit details.

