-- 04. Funciones, índices y triggers
-- Depende de: 02_tablas_base.sql y 03_tablas_operativas.sql

CREATE OR REPLACE FUNCTION public.actualizar_fecha_modificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.fecha_actualizacion = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.obtener_rol_usuario()
RETURNS TEXT
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT rol
    FROM public.perfiles
    WHERE id = auth.uid()
      AND esta_activo = TRUE
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.es_administrador()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(public.obtener_rol_usuario() = 'ADMINISTRADOR', FALSE);
$$;

-- Comprueba si el médico autenticado tiene relación asistencial con el paciente.
-- SECURITY DEFINER evita depender de las políticas RLS de las tablas consultadas.
CREATE OR REPLACE FUNCTION public.medico_tiene_paciente(p_paciente_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.medicos m
        JOIN public.turnos t ON t.medico_id = m.id
        WHERE m.perfil_id = auth.uid()
          AND t.paciente_id = p_paciente_id
    )
    OR EXISTS (
        SELECT 1
        FROM public.medicos m
        JOIN public.historias_clinicas h ON h.medico_id = m.id
        WHERE m.perfil_id = auth.uid()
          AND h.paciente_id = p_paciente_id
    );
$$;

-- Evita que un usuario cambie su propio rol desde la tabla perfiles.
CREATE OR REPLACE FUNCTION public.proteger_rol_perfil()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() = OLD.id
       AND NOT public.es_administrador()
       AND NEW.rol IS DISTINCT FROM OLD.rol THEN
        RAISE EXCEPTION 'No tenés permisos para modificar tu rol';
    END IF;

    RETURN NEW;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_medicos_especialidad
    ON public.medicos(especialidad_id);

CREATE INDEX IF NOT EXISTS idx_pacientes_perfil
    ON public.pacientes(perfil_id);

CREATE INDEX IF NOT EXISTS idx_horarios_medico_dia
    ON public.horarios_medicos(medico_id, dia_semana);

CREATE INDEX IF NOT EXISTS idx_turnos_paciente_fecha
    ON public.turnos(paciente_id, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_turnos_medico_fecha
    ON public.turnos(medico_id, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_turnos_estado
    ON public.turnos(estado);

CREATE INDEX IF NOT EXISTS idx_historias_paciente_fecha
    ON public.historias_clinicas(paciente_id, fecha_consulta DESC);

CREATE INDEX IF NOT EXISTS idx_historias_medico
    ON public.historias_clinicas(medico_id);

DROP TRIGGER IF EXISTS trg_perfiles_actualizar_fecha ON public.perfiles;
CREATE TRIGGER trg_perfiles_actualizar_fecha
BEFORE UPDATE ON public.perfiles
FOR EACH ROW EXECUTE FUNCTION public.actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS trg_perfiles_proteger_rol ON public.perfiles;
CREATE TRIGGER trg_perfiles_proteger_rol
BEFORE UPDATE ON public.perfiles
FOR EACH ROW EXECUTE FUNCTION public.proteger_rol_perfil();

DROP TRIGGER IF EXISTS trg_medicos_actualizar_fecha ON public.medicos;
CREATE TRIGGER trg_medicos_actualizar_fecha
BEFORE UPDATE ON public.medicos
FOR EACH ROW EXECUTE FUNCTION public.actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS trg_pacientes_actualizar_fecha ON public.pacientes;
CREATE TRIGGER trg_pacientes_actualizar_fecha
BEFORE UPDATE ON public.pacientes
FOR EACH ROW EXECUTE FUNCTION public.actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS trg_turnos_actualizar_fecha ON public.turnos;
CREATE TRIGGER trg_turnos_actualizar_fecha
BEFORE UPDATE ON public.turnos
FOR EACH ROW EXECUTE FUNCTION public.actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS trg_historias_actualizar_fecha ON public.historias_clinicas;
CREATE TRIGGER trg_historias_actualizar_fecha
BEFORE UPDATE ON public.historias_clinicas
FOR EACH ROW EXECUTE FUNCTION public.actualizar_fecha_modificacion();
