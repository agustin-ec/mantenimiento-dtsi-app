# AGENTS.md — reglas del proyecto Mantenimiento DTSI (app Flutter)

## Qué es
App Flutter (Android) para técnicos de mantenimiento. GetX para el estado, dio contra un backend FastAPI con JWT (el contrato está en docs/api/openapi-backend.json), Hive para caché y preferencias, flutter_secure_storage para el token y notificaciones locales.

## Dónde está cada cosa
- lib/screens/ y lib/widgets/: interfaz.
- lib/controllers/: estado compartido (GetX).
- lib/services/ y lib/repositories/: red, token seguro y caché.
- lib/models/, lib/theme/ y lib/utils/: modelos, tema y utilidades.
- test/: pruebas.

## Cómo verificar (siempre, antes de dar un cambio por terminado)
Ejecutar `flutter analyze` y `flutter test`. Los dos deben terminar sin errores. Si fallan, corrige el código; no desactives el análisis ni borres pruebas para que pasen.

## Convenciones
- El estado compartido vive en controladores GetX; las pantallas no llaman directamente a la red ni a Hive.
- Todo texto visible va en español neutro.
- Cada pantalla con datos cubre los tres estados: cargando, vacío y error.
- Colores y estilos salen del tema claro u oscuro; no usar colores fijos en las pantallas.
- La dirección del backend se lee con String.fromEnvironment('API_BASE_URL'); no se escribe fija en otros lugares.
- Cambios pequeños y enfocados: una funcionalidad a la vez, con una prueba por cada comportamiento nuevo.

## Prohibido
- Escribir claves, tokens o contraseñas en el código, en los registros o en este archivo. No leer ni modificar .env. El token JWT solo vive en el almacenamiento seguro: nunca en Hive, print ni registros.
- Agregar dependencias nuevas sin avisar y explicar por qué hacen falta.
- Ejecutar git push o crear etiquetas: eso lo hace la persona después de revisar el cambio.

## Reglas del estudiante
- Los nombres de clases, funciones y variables van en español, igual que en el resto del código.
- Antes de crear un widget nuevo, revisa si ya existe uno parecido en lib/widgets/.
