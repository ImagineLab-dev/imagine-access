# Guía de Permisos para Windows (Flutter)

Windows bloquea la creación de "enlaces simbólicos" (atajos de archivos) por seguridad, a menos que actives el "Modo Desarrollador" o seas Administrador.

Aquí tienes dos formas de solucionar el error `exit code 1` al compilar:

## Opción 1: Habilitar Modo Desarrollador (Recomendado)

Esta opción soluciona el problema permanentemente para este equipo.

1.  Abre el menú **Inicio** y escribe **"Configuración para desarrolladores"**.
2.  Entra en la opción que aparece.
3.  Busca el interruptor **"Modo de desarrollador"** y actívalo.
4.  Confirma en la ventana emergente.
5.  Vuelve a la terminal del proyecto y ejecuta: `flutter pub get`.

## Opción 2: Ejecutar Terminal como Administrador

Esta opción es solo para esta vez.

1.  Cierra tu terminal actual (VS Code, CMD, etc.).
2.  Haz clic derecho en el icono de tu terminal o **VS Code** y selecciona **"Ejecutar como administrador"**.
3.  Navega a la carpeta del proyecto:
    `cd C:\Users\Hp\Desktop\SONICO\imagine_access`
4.  Ejecuta el comando:
    `flutter pub get`
5.  Si funciona, puedes volver a usar tu terminal normal.

## Opción 3: Ejecutar desde PowerShell (Admin)

Si usas VS Code, puedes abrir una terminal de administrador dentro de él:

1.  Presiona `Ctrl + Shift + P`.
2.  Escribe `Terminal: Create New Integrated Terminal (Administrator)`.
3.  Ejecuta `flutter pub get`.
