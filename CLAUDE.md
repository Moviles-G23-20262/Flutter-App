# CampusSwap – Directrices de trabajo

## 1. Framework
- Flutter con Dart y null-safety estricto (evitar `!` y `dynamic` salvo justificación).

## 2. Arquitectura
Separación por capas:
- `domain`: entidades, contratos de repositorios y casos de uso (sin dependencias de Flutter).
- `data`: implementaciones de repositorios, fuentes de datos y modelos/DTOs.
- `presentation`: pantallas, widgets y gestión de estado.

Las dependencias apuntan hacia `domain`; `presentation` no accede directamente a `data`.

## 3. Paleta de diseño oficial
| Nombre         | Hex       |
|----------------|-----------|
| Deep Navy      | `#0E122F` |
| Primary Blue   | `#202A6A` |
| Accent Blue    | `#3B4DC4` |
| Secondary Blue | `#8B94D0` |
| Light Blue     | `#C6C9E2` |

## 4. Tipografías
- Display / títulos: **Fraunces**
- Cuerpo: **Outfit**
- Identificadores técnicos y precios: **JetBrains Mono**

## 5. Commits
Seguir Conventional Commits en formato verbose, por ejemplo:
`feat(search): implement strategy pattern for sorting`
