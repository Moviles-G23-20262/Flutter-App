# CampusSwap – Work Guidelines

## 1. Framework

* Flutter with Dart and strict null-safety (avoid `!` and `dynamic` unless justified).

## 2. Architecture

Layered separation:

* `domain`: entities, repository contracts, and use cases (without Flutter dependencies).

* `data`: repository implementations, data sources, and models/DTOs.

* `presentation`: screens, widgets, and state management.

Dependencies point toward `domain`; `presentation` does not directly access `data`.

## 3. Official Design Palette

| Name           | Hex       |
| -------------- | --------- |
| Deep Navy      | `#0E122F` |
| Primary Blue   | `#202A6A` |
| Accent Blue    | `#3B4DC4` |
| Secondary Blue | `#8B94D0` |
| Light Blue     | `#C6C9E2` |

## 4. Typography

* Display / titles: **Fraunces**

* Body: **Outfit**

* Technical identifiers and prices: **JetBrains Mono**
