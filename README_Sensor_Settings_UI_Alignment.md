# Sensor settings UI alignment

Date: 2026-06-18

This package aligns the expert-only Sensor-Einstellungen page with the existing Einstellungen Software page.

## UI behavior

- The page starts with the same Expertenmodus switch style used by the software settings page.
- Sensor metadata groups use the same ExpansionTile/card styling, group header color, spacing and group action pattern.
- Each sensor is displayed as a two-column settings card on wide screens and as a stacked card on mobile layouts.
- The left side shows label, key, JSON metadata summary, description, live value, visibility, expert and readonly badges.
- The right side uses settings-style editors for JSON metadata fields.
- Group actions follow the software settings wording: Entwurf zurücksetzen, Jetzt anwenden and Dauerhaft speichern. The session action is disabled because sensor values are readonly.
- The JSON view mirrors the software settings JSON section and supports copy/download of sensors/settings/json.

## MQTT topics

The page uses the sensors settings namespace:

- sensors/settings/json
- sensors/settings/bson
- sensors/settings/set/renew/json
- sensors/settings/set/persistent/json
- sensors/settings/validation/json

Live sensor values remain on:

- sensors/<sensor_id>/data

## Editable metadata

The app sends only changed metadata fields on persistent save:

- label
- description
- group
- order
- visible
- expert

Live sensor values are not edited on this page.
