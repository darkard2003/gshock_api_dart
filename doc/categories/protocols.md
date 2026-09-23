# Protocols & Constants

Encapsulates Casio BLE characteristic codes, handles, and watch communication strategies.

## Protocol Strategies
Different Casio G-Shock generations require distinct communication flows:
- `StandardProtocol`: Used by standard digital watches (GW-B5600, GMW-B5000, GA-B2100).
- `MipProtocol`: Used by Memory-in-Pixel display watches (GW-BX5600, GMW-BZ5000, DW-H5600) overriding time synchronization with a 4-step SP handshake.
- `AnalogueProtocol`: Used by analogue dial watches (MTG-B1000, MTG-B3000, GST-B100) managing motor alignment and second-dial sequences.
- `CasioConstants`: Complete reference of BLE UUIDs, static handles, and characteristic codes.
