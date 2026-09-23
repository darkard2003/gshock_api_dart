# Timezone

Casio watch timezone conversion, geographic coordinates, and IANA database mapping.

## Overview
Casio watches represent time offsets in units of 15 minutes (`offset ~/ 900`). The timezone module bridges standard IANA timezone identifiers with Casio's internal world-city index and coordinates.

## Components
- `CasioTimeZoneHelper`: Main utility for timezone resolution and world-city lookup.
- `CasioTimeZone`: Timezone entry holding standard and DST offsets.
- `LatLon` & `WorldCityCoordinates`: Geographic coordinates for world city positioning.
