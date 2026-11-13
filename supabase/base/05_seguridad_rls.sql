-- 05. Seguridad y políticas RLS
-- Depende de: todos los archivos anteriores.
--
-- Nota: las historias clínicas no permiten UPDATE ni DELETE desde el cliente.
-- Para correcciones clínicas conviene implementar un mecanismo de rectificación
-- con trazabilidad, en lugar de editar o borrar el registro original.

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.especialidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horarios_medicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turnos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historias_clinicas ENABLE ROW LEVEL SECURITY;

-- PERFILES
DROP POLICY IF EXISTS perfiles_consultar ON public.perfiles;
CREATE POLICY perfiles_consultar
ON public.perfiles FOR SELECT
TO authenticated
USING (id = auth.uid() OR public.es_administrador());

DROP POLICY IF EXISTS perfiles_actualizar ON public.perfiles;
CREATE POLICY perfiles_actualizar
ON public.perfiles FOR UPDATE
TO authenticated
USING (id = auth.uid() OR public.es_administrador())
WITH CHECK (id = auth.uid() OR public.es_administrador());

DROP POLICY IF EXISTS perfiles_administrador_insertar ON public.perfiles;
CREATE POLICY perfiles_administrador_insertar
ON public.perfiles FOR INSERT
TO authenticated
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS perfiles_administrador_eliminar ON public.perfiles;
CREATE POLICY perfiles_administrador_eliminar
ON public.perfiles FOR DELETE
TO authenticated
USING (public.es_administrador());

-- ESPECIALIDADES
DROP POLICY IF EXISTS especialidades_consultar ON public.especialidades;
CREATE POLICY especialidades_consultar
ON public.especialidades FOR SELECT
TO authenticated
USING (TRUE);

DROP POLICY IF EXISTS especialidades_administrador_insertar ON public.especialidades;
CREATE POLICY especialidades_administrador_insertar
ON public.especialidades FOR INSERT
TO authenticated
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS especialidades_administrador_actualizar ON public.especialidades;
CREATE POLICY especialidades_administrador_actualizar
ON public.especialidades FOR UPDATE
TO authenticated
USING (public.es_administrador())
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS especialidades_administrador_eliminar ON public.especialidades;
CREATE POLICY especialidades_administrador_eliminar
ON public.especialidades FOR DELETE
TO authenticated
USING (public.es_administrador());

-- MEDICOS
DROP POLICY IF EXISTS medicos_consultar ON public.medicos;
CREATE POLICY medicos_consultar
ON public.medicos FOR SELECT
TO authenticated
USING (TRUE);

DROP POLICY IF EXISTS medicos_administrador_insertar ON public.medicos;
CREATE POLICY medicos_administrador_insertar
ON public.medicos FOR INSERT
TO authenticated
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS medicos_administrador_actualizar ON public.medicos;
CREATE POLICY medicos_administrador_actualizar
ON public.medicos FOR UPDATE
TO authenticated
USING (public.es_administrador())
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS medicos_administrador_eliminar ON public.medicos;
CREATE POLICY medicos_administrador_eliminar
ON public.medicos FOR DELETE
TO authenticated
USING (public.es_administrador());

-- PACIENTES
DROP POLICY IF EXISTS pacientes_consultar ON public.pacientes;
CREATE POLICY pacientes_consultar
ON public.pacientes FOR SELECT
TO authenticated
USING (
    public.es_administrador()
    OR perfil_id = auth.uid()
    OR public.medico_tiene_paciente(id)
);

DROP POLICY IF EXISTS pacientes_administrador_insertar ON public.pacientes;
CREATE POLICY pacientes_administrador_insertar
ON public.pacientes FOR INSERT
TO authenticated
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS pacientes_administrador_actualizar ON public.pacientes;
CREATE POLICY pacientes_administrador_actualizar
ON public.pacientes FOR UPDATE
TO authenticated
USING (public.es_administrador())
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS pacientes_administrador_eliminar ON public.pacientes;
CREATE POLICY pacientes_administrador_eliminar
ON public.pacientes FOR DELETE
TO authenticated
USING (public.es_administrador());

-- HORARIOS MEDICOS
DROP POLICY IF EXISTS horarios_consultar ON public.horarios_medicos;
CREATE POLICY horarios_consultar
ON public.horarios_medicos FOR SELECT
TO authenticated
USING (TRUE);

DROP POLICY IF EXISTS horarios_administrador_insertar ON public.horarios_medicos;
CREATE POLICY horarios_administrador_insertar
ON public.horarios_medicos FOR INSERT
TO authenticated
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS horarios_administrador_actualizar ON public.horarios_medicos;
CREATE POLICY horarios_administrador_actualizar
ON public.horarios_medicos FOR UPDATE
TO authenticated
USING (public.es_administrador())
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS horarios_administrador_eliminar ON public.horarios_medicos;
CREATE POLICY horarios_administrador_eliminar
ON public.horarios_medicos FOR DELETE
TO authenticated
USING (public.es_administrador());

-- TURNOS
DROP POLICY IF EXISTS turnos_consultar ON public.turnos;
CREATE POLICY turnos_consultar
ON public.turnos FOR SELECT
TO authenticated
USING (
    public.es_administrador()
    OR EXISTS (
        SELECT 1
        FROM public.pacientes p
        WHERE p.id = turnos.paciente_id
          AND p.perfil_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1
        FROM public.medicos m
        WHERE m.id = turnos.medico_id
          AND m.perfil_id = auth.uid()
    )
);

DROP POLICY IF EXISTS turnos_insertar ON public.turnos;
CREATE POLICY turnos_insertar
ON public.turnos FOR INSERT
TO authenticated
WITH CHECK (
    public.es_administrador()
    OR (
        estado = 'PENDIENTE'
        AND EXISTS (
            SELECT 1
            FROM public.pacientes p
            WHERE p.id = turnos.paciente_id
              AND p.perfil_id = auth.uid()
        )
    )
);

DROP POLICY IF EXISTS turnos_administrador_actualizar ON public.turnos;
CREATE POLICY turnos_administrador_actualizar
ON public.turnos FOR UPDATE
TO authenticated
USING (public.es_administrador())
WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS turnos_administrador_eliminar ON public.turnos;
CREATE POLICY turnos_administrador_eliminar
ON public.turnos FOR DELETE
TO authenticated
USING (public.es_administrador());

-- HISTORIAS CLINICAS
DROP POLICY IF EXISTS historias_consultar ON public.historias_clinicas;
CREATE POLICY historias_consultar
ON public.historias_clinicas FOR SELECT
TO authenticated
USING (
    public.es_administrador()
    OR EXISTS (
        SELECT 1
        FROM public.pacientes p
        WHERE p.id = historias_clinicas.paciente_id
          AND p.perfil_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1
        FROM public.medicos m
        WHERE m.id = historias_clinicas.medico_id
          AND m.perfil_id = auth.uid()
    )
);

DROP POLICY IF EXISTS historias_insertar ON public.historias_clinicas;
CREATE POLICY historias_insertar
ON public.historias_clinicas FOR INSERT
TO authenticated
WITH CHECK (
    public.es_administrador()
    OR EXISTS (
        SELECT 1
        FROM public.medicos m
        WHERE m.id = historias_clinicas.medico_id
          AND m.perfil_id = auth.uid()
    )
);

-- No se crean políticas de UPDATE o DELETE para historias_clinicas:
-- por defecto quedan bloqueadas para los usuarios autenticados.
