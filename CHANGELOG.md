# Changelog

## [1.0.0] - 2026-09-10

First build.

### Added

- Depot terminal with a cab roster, shift stats, personal record and a company board
- Rented cabs against a deposit, with damage taken off the refund on return
- Live meter: flagfall, distance, waiting time, night rates and a cross-town bonus
- NPC fares pulled from a config point list, grouped by area and gated by tier
- Player fares — `/taxi` calls every signed-on driver in range, first to accept takes it
- Open-ended hailed rides that the driver ends with `/endride` wherever the passenger asked for
- Ride ratings that fall for collisions, speeding, flipping the cab and hurting the passenger
- Tips and reputation both scale off the rating, so driving well is the progression
- Five reputation tiers unlocking cabs and raising the fare multiplier
- Bridges for framework, target, vehicle keys and XS-Phone, all auto-detected and all optional
- Server-side fare validation: the client's meter is a ceiling, never the source of truth
