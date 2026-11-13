-- 03. Tablas operativas
-- Depende de: 02_tablas_base.sql

CREATE TABLE IF NOT EXISTS public.medicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID NOT NULL UNIQUE REFERENCES public.perfiles(id) ON DELETE RESTRICT,
    especialidad_id UUID REFERENCES public.especialidades(id) ON DELETE RESTRICT,
    dni TEXT UNIQUE,
    numero_matricula TEXT UNIQUE,
    esta_activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pacientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID NOT NULL UNIQUE REFERENCES public.perfiles(id) ON DELETE RESTRICT,
    dni TEXT UNIQUE,
    fecha_nacimiento DATE,
    genero TEXT CHECK (genero IN ('FEMENINO', 'MASCULINO', 'OTRO', 'NO_ESPECIFICADO')),
    direccion TEXT,
    nombre_obra_social TEXT,
    numero_afiliado TEXT,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.horarios_medicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medico_id UUID NOT NULL REFERENCES public.medicos(id) ON DELETE CASCADE,
    dia_semana INTEGER NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    duracion_turno INTEGER NOT NULL DEFAULT 30 CHECK (duracion_turno > 0),
    esta_activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT horario_valido CHECK (hora_fin > hora_inicio)
);

CREATE TABLE IF NOT EXISTS public.turnos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paciente_id UUID NOT NULL REFERENCES public.pacientes(id) ON DELETE RESTRICT,
    medico_id UUID NOT NULL REFERENCES public.medicos(id) ON DELETE RESTRICT,
    fecha_inicio TIMESTAMPTZ NOT NULL,
    fecha_fin TIMESTAMPTZ NOT NULL,
    motivo TEXT,
    estado TEXT NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ATENDIDO', 'CANCELADO', 'AUSENTE')),
    creado_por UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT turno_rango_valido CHECK (fecha_fin > fecha_inicio)
);

-- Impide que un médico tenga dos turnos activos superpuestos.
ALTER TABLE public.turnos
    ADD CONSTRAINT turnos_sin_superposicion
    EXCLUDE USING gist (
        medico_id WITH =,
        tstzrange(fecha_inicio, fecha_fin, '[)') WITH &&
    )
    WHERE (estado IN ('PENDIENTE', 'CONFIRMADO'));

CREATE TABLE IF NOT EXISTS public.historias_clinicas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paciente_id UUID NOT NULL REFERENCES public.pacientes(id) ON DELETE RESTRICT,
    medico_id UUID NOT NULL REFERENCES public.medicos(id) ON DELETE RESTRICT,
    turno_id UUID UNIQUE REFERENCES public.turnos(id) ON DELETE RESTRICT,
    fecha_consulta TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    motivo TEXT,
    diagnostico TEXT,
    tratamiento TEXT,
    medicacion TEXT,
    observaciones TEXT,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
