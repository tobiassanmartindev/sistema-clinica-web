-- 06. Funciones del sistema (RPC)
-- Depende de: todos los archivos de supabase/base (01 a 05).
--
-- Por qué existen estas funciones:
-- * La política de `perfiles` sólo deja ver el propio perfil (o todo si sos
--   administrador). Sin estas funciones un paciente no podría ver el nombre de
--   los médicos y un médico no podría ver el nombre de sus pacientes.
-- * Los turnos sólo los puede modificar el administrador. Estas funciones
--   permiten, de forma controlada, que el paciente cancele los suyos y que el
--   médico confirme, cancele o cierre los de su agenda.
-- * Calcular horarios libres requiere ver turnos de otros pacientes.
--
-- Todas son SECURITY DEFINER y validan explícitamente quién las llama.

-- ---------------------------------------------------------------------------
-- Configuración
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.zona_horaria_clinica()
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT 'America/Argentina/Buenos_Aires'::TEXT;
$$;

-- ---------------------------------------------------------------------------
-- Alta automática de perfil al crear un usuario en auth.users
-- ---------------------------------------------------------------------------
-- El rol se toma de raw_app_meta_data (sólo lo puede definir el service role,
-- es decir, el administrador desde el servidor). Si no viene, es PACIENTE, lo
-- que habilita el auto-registro de pacientes sin riesgo de escalar privilegios.
-- Los datos personales se toman de raw_user_meta_data.

CREATE OR REPLACE FUNCTION public.crear_perfil_nuevo_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rol TEXT := COALESCE(NEW.raw_app_meta_data->>'rol', 'PACIENTE');
    v_datos JSONB := COALESCE(NEW.raw_user_meta_data, '{}'::JSONB);
    v_genero TEXT := NULLIF(v_datos->>'genero', '');
BEGIN
    IF v_rol NOT IN ('ADMINISTRADOR', 'MEDICO', 'PACIENTE') THEN
        v_rol := 'PACIENTE';
    END IF;

    INSERT INTO public.perfiles (id, nombre_completo, correo_electronico, telefono, rol)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(TRIM(v_datos->>'nombre_completo'), ''), NEW.email),
        NEW.email,
        NULLIF(v_datos->>'telefono', ''),
        v_rol
    );

    IF v_rol = 'PACIENTE' THEN
        IF v_genero NOT IN ('FEMENINO', 'MASCULINO', 'OTRO', 'NO_ESPECIFICADO') THEN
            v_genero := NULL;
        END IF;

        INSERT INTO public.pacientes (
            perfil_id, dni, fecha_nacimiento, genero, direccion,
            nombre_obra_social, numero_afiliado
        )
        VALUES (
            NEW.id,
            NULLIF(v_datos->>'dni', ''),
            NULLIF(v_datos->>'fecha_nacimiento', '')::DATE,
            v_genero,
            NULLIF(v_datos->>'direccion', ''),
            NULLIF(v_datos->>'nombre_obra_social', ''),
            NULLIF(v_datos->>'numero_afiliado', '')
        );
    ELSIF v_rol = 'MEDICO' THEN
        INSERT INTO public.medicos (perfil_id, especialidad_id, dni, numero_matricula)
        VALUES (
            NEW.id,
            NULLIF(v_datos->>'especialidad_id', '')::UUID,
            NULLIF(v_datos->>'dni', ''),
            NULLIF(v_datos->>'numero_matricula', '')
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auth_usuario_creado ON auth.users;
CREATE TRIGGER trg_auth_usuario_creado
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.crear_perfil_nuevo_usuario();

-- ---------------------------------------------------------------------------
-- Médicos (listado con nombre, visible para cualquier usuario autenticado)
-- ---------------------------------------------------------------------------
-- Los datos de contacto y el DNI sólo se devuelven al administrador.

CREATE OR REPLACE FUNCTION public.listar_medicos(
    p_especialidad_id UUID DEFAULT NULL,
    p_incluir_inactivos BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    id UUID,
    perfil_id UUID,
    nombre_completo TEXT,
    especialidad_id UUID,
    especialidad TEXT,
    numero_matricula TEXT,
    dni TEXT,
    correo_electronico TEXT,
    telefono TEXT,
    esta_activo BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin BOOLEAN := public.es_administrador();
BEGIN
    IF public.obtener_rol_usuario() IS NULL THEN
        RAISE EXCEPTION 'Sesión no válida';
    END IF;

    RETURN QUERY
    SELECT
        m.id,
        m.perfil_id,
        p.nombre_completo,
        m.especialidad_id,
        e.nombre,
        m.numero_matricula,
        CASE WHEN v_admin THEN m.dni END,
        CASE WHEN v_admin THEN p.correo_electronico END,
        CASE WHEN v_admin THEN p.telefono END,
        (m.esta_activo AND p.esta_activo)
    FROM public.medicos m
    JOIN public.perfiles p ON p.id = m.perfil_id
    LEFT JOIN public.especialidades e ON e.id = m.especialidad_id
    WHERE (p_especialidad_id IS NULL OR m.especialidad_id = p_especialidad_id)
      AND ((m.esta_activo AND p.esta_activo) OR (p_incluir_inactivos AND v_admin))
    ORDER BY p.nombre_completo;
END;
$$;

-- ---------------------------------------------------------------------------
-- Pacientes (administrador: todos; médico: los suyos; paciente: él mismo)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.listar_pacientes(
    p_busqueda TEXT DEFAULT NULL,
    p_paciente_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    perfil_id UUID,
    nombre_completo TEXT,
    correo_electronico TEXT,
    telefono TEXT,
    dni TEXT,
    fecha_nacimiento DATE,
    genero TEXT,
    direccion TEXT,
    nombre_obra_social TEXT,
    numero_afiliado TEXT,
    esta_activo BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_busqueda TEXT := NULLIF(TRIM(p_busqueda), '');
BEGIN
    IF public.obtener_rol_usuario() IS NULL THEN
        RAISE EXCEPTION 'Sesión no válida';
    END IF;

    RETURN QUERY
    SELECT
        pa.id,
        pa.perfil_id,
        p.nombre_completo,
        p.correo_electronico,
        p.telefono,
        pa.dni,
        pa.fecha_nacimiento,
        pa.genero,
        pa.direccion,
        pa.nombre_obra_social,
        pa.numero_afiliado,
        p.esta_activo
    FROM public.pacientes pa
    JOIN public.perfiles p ON p.id = pa.perfil_id
    WHERE (
            public.es_administrador()
            OR pa.perfil_id = auth.uid()
            OR public.medico_tiene_paciente(pa.id)
          )
      AND (p_paciente_id IS NULL OR pa.id = p_paciente_id)
      AND (
            v_busqueda IS NULL
            OR p.nombre_completo ILIKE '%' || v_busqueda || '%'
            OR pa.dni ILIKE '%' || v_busqueda || '%'
          )
    ORDER BY p.nombre_completo;
END;
$$;

-- ---------------------------------------------------------------------------
-- Horarios libres de un médico en una fecha
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.obtener_horarios_disponibles(
    p_medico_id UUID,
    p_fecha DATE
)
RETURNS TABLE (fecha_inicio TIMESTAMPTZ, fecha_fin TIMESTAMPTZ)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tz TEXT := public.zona_horaria_clinica();
BEGIN
    IF public.obtener_rol_usuario() IS NULL THEN
        RAISE EXCEPTION 'Sesión no válida';
    END IF;

    RETURN QUERY
    SELECT s.inicio, s.inicio + make_interval(mins => h.duracion_turno)
    FROM public.horarios_medicos h
    JOIN public.medicos m ON m.id = h.medico_id AND m.esta_activo
    JOIN public.perfiles p ON p.id = m.perfil_id AND p.esta_activo
    CROSS JOIN LATERAL generate_series(
        (p_fecha + h.hora_inicio) AT TIME ZONE v_tz,
        (p_fecha + h.hora_fin) AT TIME ZONE v_tz - make_interval(mins => h.duracion_turno),
        make_interval(mins => h.duracion_turno)
    ) AS s(inicio)
    WHERE h.medico_id = p_medico_id
      AND h.esta_activo
      AND h.dia_semana = EXTRACT(DOW FROM p_fecha)
      AND s.inicio > NOW()
      AND NOT EXISTS (
          SELECT 1
          FROM public.turnos t
          WHERE t.medico_id = h.medico_id
            AND t.estado IN ('PENDIENTE', 'CONFIRMADO')
            AND tstzrange(t.fecha_inicio, t.fecha_fin, '[)')
                && tstzrange(s.inicio, s.inicio + make_interval(mins => h.duracion_turno), '[)')
      )
    ORDER BY s.inicio;
END;
$$;

-- ---------------------------------------------------------------------------
-- Turnos: listado con nombres (cada rol ve lo mismo que permite RLS)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.listar_turnos(
    p_desde TIMESTAMPTZ DEFAULT NULL,
    p_hasta TIMESTAMPTZ DEFAULT NULL,
    p_estado TEXT DEFAULT NULL,
    p_medico_id UUID DEFAULT NULL,
    p_paciente_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    fecha_inicio TIMESTAMPTZ,
    fecha_fin TIMESTAMPTZ,
    estado TEXT,
    motivo TEXT,
    paciente_id UUID,
    paciente_nombre TEXT,
    paciente_dni TEXT,
    medico_id UUID,
    medico_nombre TEXT,
    especialidad TEXT,
    tiene_consulta BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.obtener_rol_usuario() IS NULL THEN
        RAISE EXCEPTION 'Sesión no válida';
    END IF;

    RETURN QUERY
    SELECT
        t.id,
        t.fecha_inicio,
        t.fecha_fin,
        t.estado,
        t.motivo,
        t.paciente_id,
        pp.nombre_completo,
        pa.dni,
        t.medico_id,
        pm.nombre_completo,
        e.nombre,
        EXISTS (SELECT 1 FROM public.historias_clinicas h WHERE h.turno_id = t.id)
    FROM public.turnos t
    JOIN public.pacientes pa ON pa.id = t.paciente_id
    JOIN public.perfiles pp ON pp.id = pa.perfil_id
    JOIN public.medicos m ON m.id = t.medico_id
    JOIN public.perfiles pm ON pm.id = m.perfil_id
    LEFT JOIN public.especialidades e ON e.id = m.especialidad_id
    WHERE (
            public.es_administrador()
            OR pa.perfil_id = auth.uid()
            OR m.perfil_id = auth.uid()
          )
      AND (p_desde IS NULL OR t.fecha_inicio >= p_desde)
      AND (p_hasta IS NULL OR t.fecha_inicio < p_hasta)
      AND (p_estado IS NULL OR t.estado = p_estado)
      AND (p_medico_id IS NULL OR t.medico_id = p_medico_id)
      AND (p_paciente_id IS NULL OR t.paciente_id = p_paciente_id)
    ORDER BY t.fecha_inicio;
END;
$$;

-- ---------------------------------------------------------------------------
-- Turnos: solicitar
-- ---------------------------------------------------------------------------
-- Paciente: siempre para sí mismo (se ignora p_paciente_id), queda PENDIENTE.
-- Administrador: para cualquier paciente, queda CONFIRMADO.
-- Valida que el horario coincida con la agenda del médico.

CREATE OR REPLACE FUNCTION public.solicitar_turno(
    p_medico_id UUID,
    p_fecha_inicio TIMESTAMPTZ,
    p_motivo TEXT DEFAULT NULL,
    p_paciente_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rol TEXT := public.obtener_rol_usuario();
    v_tz TEXT := public.zona_horaria_clinica();
    v_local TIMESTAMP := p_fecha_inicio AT TIME ZONE v_tz;
    v_paciente_id UUID;
    v_duracion INTEGER;
    v_turno_id UUID;
BEGIN
    IF v_rol = 'PACIENTE' THEN
        SELECT id INTO v_paciente_id FROM public.pacientes WHERE perfil_id = auth.uid();
    ELSIF v_rol = 'ADMINISTRADOR' THEN
        v_paciente_id := p_paciente_id;
    ELSE
        RAISE EXCEPTION 'No tenés permisos para solicitar turnos';
    END IF;

    IF v_paciente_id IS NULL THEN
        RAISE EXCEPTION 'Paciente no encontrado';
    END IF;

    IF p_fecha_inicio <= NOW() THEN
        RAISE EXCEPTION 'El turno debe ser en una fecha futura';
    END IF;

    SELECT h.duracion_turno INTO v_duracion
    FROM public.horarios_medicos h
    JOIN public.medicos m ON m.id = h.medico_id AND m.esta_activo
    JOIN public.perfiles p ON p.id = m.perfil_id AND p.esta_activo
    WHERE h.medico_id = p_medico_id
      AND h.esta_activo
      AND h.dia_semana = EXTRACT(DOW FROM v_local)
      AND v_local::TIME >= h.hora_inicio
      AND v_local::TIME + make_interval(mins => h.duracion_turno) <= h.hora_fin
      AND MOD(EXTRACT(EPOCH FROM v_local::TIME - h.hora_inicio)::INTEGER, h.duracion_turno * 60) = 0
    LIMIT 1;

    IF v_duracion IS NULL THEN
        RAISE EXCEPTION 'El horario elegido no está en la agenda del médico';
    END IF;

    INSERT INTO public.turnos (paciente_id, medico_id, fecha_inicio, fecha_fin, motivo, estado, creado_por)
    VALUES (
        v_paciente_id,
        p_medico_id,
        p_fecha_inicio,
        p_fecha_inicio + make_interval(mins => v_duracion),
        NULLIF(TRIM(p_motivo), ''),
        CASE WHEN v_rol = 'ADMINISTRADOR' THEN 'CONFIRMADO' ELSE 'PENDIENTE' END,
        auth.uid()
    )
    RETURNING id INTO v_turno_id;

    RETURN v_turno_id;
EXCEPTION
    WHEN exclusion_violation THEN
        RAISE EXCEPTION 'El horario elegido ya está ocupado';
END;
$$;

-- ---------------------------------------------------------------------------
-- Turnos: cambiar estado
-- ---------------------------------------------------------------------------
-- Administrador: cualquier estado.
-- Médico (sus turnos abiertos): CONFIRMADO, CANCELADO, AUSENTE, ATENDIDO.
-- Paciente (sus turnos abiertos y futuros): sólo CANCELADO.

CREATE OR REPLACE FUNCTION public.cambiar_estado_turno(
    p_turno_id UUID,
    p_estado TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rol TEXT := public.obtener_rol_usuario();
    v_turno RECORD;
BEGIN
    IF p_estado NOT IN ('PENDIENTE', 'CONFIRMADO', 'ATENDIDO', 'CANCELADO', 'AUSENTE') THEN
        RAISE EXCEPTION 'Estado de turno inválido';
    END IF;

    SELECT t.estado, t.fecha_inicio, pa.perfil_id AS perfil_paciente, m.perfil_id AS perfil_medico
    INTO v_turno
    FROM public.turnos t
    JOIN public.pacientes pa ON pa.id = t.paciente_id
    JOIN public.medicos m ON m.id = t.medico_id
    WHERE t.id = p_turno_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno no encontrado';
    END IF;

    IF v_rol IS DISTINCT FROM 'ADMINISTRADOR' THEN
        IF v_turno.estado NOT IN ('PENDIENTE', 'CONFIRMADO') THEN
            RAISE EXCEPTION 'El turno ya está cerrado';
        END IF;

        IF v_rol = 'MEDICO' AND v_turno.perfil_medico = auth.uid() THEN
            IF p_estado NOT IN ('CONFIRMADO', 'CANCELADO', 'AUSENTE', 'ATENDIDO') THEN
                RAISE EXCEPTION 'Estado no permitido';
            END IF;
        ELSIF v_rol = 'PACIENTE' AND v_turno.perfil_paciente = auth.uid() THEN
            IF p_estado <> 'CANCELADO' THEN
                RAISE EXCEPTION 'Sólo podés cancelar tus turnos';
            END IF;
            IF v_turno.fecha_inicio <= NOW() THEN
                RAISE EXCEPTION 'No se puede cancelar un turno pasado';
            END IF;
        ELSE
            RAISE EXCEPTION 'No tenés permisos sobre este turno';
        END IF;
    END IF;

    UPDATE public.turnos SET estado = p_estado WHERE id = p_turno_id;
EXCEPTION
    WHEN exclusion_violation THEN
        RAISE EXCEPTION 'El horario del turno ya está ocupado por otro turno';
END;
$$;

-- ---------------------------------------------------------------------------
-- Historia clínica: registrar consulta de un turno (y marcarlo ATENDIDO)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.registrar_consulta(
    p_turno_id UUID,
    p_diagnostico TEXT,
    p_tratamiento TEXT DEFAULT NULL,
    p_medicacion TEXT DEFAULT NULL,
    p_observaciones TEXT DEFAULT NULL,
    p_motivo TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_turno RECORD;
    v_historia_id UUID;
BEGIN
    SELECT t.id, t.paciente_id, t.medico_id, t.estado, t.motivo
    INTO v_turno
    FROM public.turnos t
    JOIN public.medicos m ON m.id = t.medico_id
    WHERE t.id = p_turno_id
      AND m.perfil_id = auth.uid()
      AND public.obtener_rol_usuario() = 'MEDICO';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno no encontrado o no pertenece a tu agenda';
    END IF;

    IF v_turno.estado IN ('CANCELADO', 'AUSENTE') THEN
        RAISE EXCEPTION 'No se puede registrar una consulta de un turno cancelado o ausente';
    END IF;

    IF EXISTS (SELECT 1 FROM public.historias_clinicas WHERE turno_id = p_turno_id) THEN
        RAISE EXCEPTION 'El turno ya tiene una consulta registrada';
    END IF;

    INSERT INTO public.historias_clinicas (
        paciente_id, medico_id, turno_id, motivo, diagnostico,
        tratamiento, medicacion, observaciones
    )
    VALUES (
        v_turno.paciente_id,
        v_turno.medico_id,
        v_turno.id,
        COALESCE(NULLIF(TRIM(p_motivo), ''), v_turno.motivo),
        NULLIF(TRIM(p_diagnostico), ''),
        NULLIF(TRIM(p_tratamiento), ''),
        NULLIF(TRIM(p_medicacion), ''),
        NULLIF(TRIM(p_observaciones), '')
    )
    RETURNING id INTO v_historia_id;

    UPDATE public.turnos SET estado = 'ATENDIDO' WHERE id = v_turno.id;

    RETURN v_historia_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Historia clínica: consultar (mismas reglas que la política RLS)
-- ---------------------------------------------------------------------------
-- Administrador: todo. Paciente: la suya. Médico: las consultas que él registró.

CREATE OR REPLACE FUNCTION public.obtener_historia_clinica(p_paciente_id UUID)
RETURNS TABLE (
    id UUID,
    fecha_consulta TIMESTAMPTZ,
    motivo TEXT,
    diagnostico TEXT,
    tratamiento TEXT,
    medicacion TEXT,
    observaciones TEXT,
    turno_id UUID,
    medico_id UUID,
    medico_nombre TEXT,
    especialidad TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.obtener_rol_usuario() IS NULL THEN
        RAISE EXCEPTION 'Sesión no válida';
    END IF;

    RETURN QUERY
    SELECT
        h.id,
        h.fecha_consulta,
        h.motivo,
        h.diagnostico,
        h.tratamiento,
        h.medicacion,
        h.observaciones,
        h.turno_id,
        h.medico_id,
        pm.nombre_completo,
        e.nombre
    FROM public.historias_clinicas h
    JOIN public.pacientes pa ON pa.id = h.paciente_id
    JOIN public.medicos m ON m.id = h.medico_id
    JOIN public.perfiles pm ON pm.id = m.perfil_id
    LEFT JOIN public.especialidades e ON e.id = m.especialidad_id
    WHERE h.paciente_id = p_paciente_id
      AND (
            public.es_administrador()
            OR pa.perfil_id = auth.uid()
            OR m.perfil_id = auth.uid()
          )
    ORDER BY h.fecha_consulta DESC;
END;
$$;

-- ---------------------------------------------------------------------------
-- Permisos de ejecución
-- ---------------------------------------------------------------------------
-- Supabase otorga EXECUTE a anon por defecto: se restringe a usuarios logueados.

REVOKE ALL ON FUNCTION public.crear_perfil_nuevo_usuario() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.listar_medicos(UUID, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.listar_pacientes(TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.obtener_horarios_disponibles(UUID, DATE) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.listar_turnos(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.solicitar_turno(UUID, TIMESTAMPTZ, TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cambiar_estado_turno(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_consulta(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.obtener_historia_clinica(UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.listar_medicos(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_pacientes(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_horarios_disponibles(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_turnos(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.solicitar_turno(UUID, TIMESTAMPTZ, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cambiar_estado_turno(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_consulta(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_historia_clinica(UUID) TO authenticated;
