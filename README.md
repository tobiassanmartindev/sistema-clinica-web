# Sistema de Clínicas

Sistema web de gestión para clínicas médicas: médicos, pacientes, especialidades, agendas, turnos e historias clínicas.

Construido con **Next.js 16** (App Router, Server Actions), **React 19**, **Tailwind CSS 4** y **Supabase** (Postgres, Auth y Row Level Security).

> Estado: la capa de datos (base, seguridad y funciones del servidor) está implementada. La interfaz todavía no.

## Roles

| Rol | Puede |
| --- | --- |
| **ADMINISTRADOR** | Gestionar especialidades, médicos, pacientes y horarios. Ver y modificar todos los turnos. |
| **MEDICO** | Ver su agenda, confirmar, cancelar o cerrar sus turnos, registrar consultas y ver la historia de sus pacientes. |
| **PACIENTE** | Registrarse solo, pedir y cancelar sus turnos y ver su historia clínica. |

Los permisos se aplican en la base con RLS y funciones `SECURITY DEFINER` que validan quién las llama, no solo en el frontend.

## Estructura

```
src/
├── app/                  # Rutas de Next.js (App Router)
├── funciones/            # Server Actions agrupadas por dominio
│   ├── auth.ts           # iniciarSesion, registrarPaciente, cerrarSesion, obtenerUsuarioActual, actualizarMiPerfil
│   ├── especialidades.ts # listar, crear, actualizar
│   ├── medicos.ts        # listar, crear (con usuario de acceso), actualizar
│   ├── pacientes.ts      # listar, obtener, crear, actualizar
│   ├── horarios.ts       # agenda semanal de cada médico
│   ├── turnos.ts         # listar, horarios disponibles, solicitar, cambiar estado
│   ├── historias.ts      # historia clínica y registro de consultas
│   ├── tipos.ts          # tipos compartidos (Rol, EstadoTurno, Resultado, ...)
│   └── utilidades.ts
├── lib/supabase/
│   ├── navegador.ts      # cliente para componentes de cliente
│   ├── servidor.ts       # cliente con la sesión del usuario (cookies)
│   └── admin.ts          # cliente service_role, solo en el servidor
└── proxy.ts              # refresca la sesión de Supabase en cada request

supabase/
├── base/                 # 01–05: extensiones, tablas, triggers, índices y RLS
└── funciones/            # 06: funciones RPC del sistema
```

Todas las funciones de `src/funciones` devuelven un `Resultado<T>` (`{ ok: true, datos }` o `{ ok: false, error }`) y no lanzan excepciones por errores esperables.

## Puesta en marcha

### 1. Requisitos

- Node.js 20 o superior
- Un proyecto en [Supabase](https://supabase.com)

### 2. Base de datos

En el **SQL Editor** de Supabase, ejecutá los scripts en este orden:

1. `supabase/base/01_extensiones.sql`
2. `supabase/base/02_tablas_base.sql`
3. `supabase/base/03_tablas_operativas.sql`
4. `supabase/base/04_funciones_indices_triggers.sql`
5. `supabase/base/05_seguridad_rls.sql`
6. `supabase/funciones/06_funciones_sistema.sql`

La zona horaria de la clínica está definida en `zona_horaria_clinica()` (por defecto `America/Argentina/Buenos_Aires`).

### 3. Variables de entorno

```bash
cp .env.example .env
```

| Variable | Dónde se obtiene |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase → Project Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API. **Es secreta: no la expongas al cliente ni la subas al repo.** |

### 4. Instalar y ejecutar

```bash
npm install
npm run dev
```

La app queda en [http://localhost:3000](http://localhost:3000).

### 5. Crear el primer administrador

Al crear un usuario, el rol se lee de `app_metadata.rol`. Si no viene, el usuario queda como `PACIENTE`. Ese campo solo se puede definir con la clave `service_role`, así que el primer administrador se crea desde el panel de Supabase (**Authentication → Users → Add user**). Después, en el SQL Editor:

```sql
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"rol": "ADMINISTRADOR"}'
WHERE email = 'admin@tu-clinica.com';

UPDATE public.perfiles
SET rol = 'ADMINISTRADOR'
WHERE correo_electronico = 'admin@tu-clinica.com';

-- El usuario nació como PACIENTE: se borra la ficha de paciente que se creó automáticamente.
DELETE FROM public.pacientes
WHERE perfil_id = (SELECT id FROM public.perfiles WHERE correo_electronico = 'admin@tu-clinica.com');
```

A partir de ahí, el administrador da de alta a los médicos desde la aplicación.

## Scripts

| Comando | Descripción |
| --- | --- |
| `npm run dev` | Servidor de desarrollo |
| `npm run build` | Build de producción |
| `npm run start` | Sirve el build de producción |
| `npm run lint` | ESLint |
