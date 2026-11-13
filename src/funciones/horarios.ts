"use server";

import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { HorarioMedico, Resultado } from "./tipos";
import { esAdministrador, fallo, mensajeError, ok } from "./utilidades";

const COLUMNAS = "id, medico_id, dia_semana, hora_inicio, hora_fin, duracion_turno, esta_activo";

/** Agenda semanal de un médico. Cualquier usuario logueado. */
export async function listarHorarios(medicoId: string): Promise<Resultado<HorarioMedico[]>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase
    .from("horarios_medicos")
    .select(COLUMNAS)
    .eq("medico_id", medicoId)
    .order("dia_semana")
    .order("hora_inicio");
  return error ? fallo(mensajeError(error)) : ok(data);
}

/** Sólo administrador. Crea el bloque horario si no tiene id; si lo tiene, lo actualiza. */
export async function guardarHorario(
  horario: Omit<HorarioMedico, "id" | "esta_activo"> & { id?: string; esta_activo?: boolean },
): Promise<Resultado<HorarioMedico>> {
  if (!(await esAdministrador())) return fallo("No tenés permisos para realizar esta acción.");
  if (horario.hora_fin <= horario.hora_inicio) {
    return fallo("La hora de fin debe ser posterior a la de inicio.");
  }

  const supabase = await crearClienteServidor();
  const { id, ...datos } = horario;
  const consulta = id
    ? supabase.from("horarios_medicos").update(datos).eq("id", id)
    : supabase.from("horarios_medicos").insert(datos);

  const { data, error } = await consulta.select(COLUMNAS).single();
  return error ? fallo(mensajeError(error)) : ok(data);
}

/** Sólo administrador. */
export async function eliminarHorario(id: string): Promise<Resultado> {
  if (!(await esAdministrador())) return fallo("No tenés permisos para realizar esta acción.");

  const supabase = await crearClienteServidor();
  const { error } = await supabase.from("horarios_medicos").delete().eq("id", id);
  return error ? fallo(mensajeError(error)) : ok(null);
}
