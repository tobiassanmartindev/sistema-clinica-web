"use server";

import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { EstadoTurno, FiltrosTurnos, HorarioDisponible, Resultado, Turno } from "./tipos";
import { fallo, mensajeError, ok } from "./utilidades";

/** Cada rol ve sus turnos: administrador todos, médico su agenda, paciente los propios. */
export async function listarTurnos(filtros: FiltrosTurnos = {}): Promise<Resultado<Turno[]>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("listar_turnos", {
    p_desde: filtros.desde ?? null,
    p_hasta: filtros.hasta ?? null,
    p_estado: filtros.estado ?? null,
    p_medico_id: filtros.medico_id ?? null,
    p_paciente_id: filtros.paciente_id ?? null,
  });
  return error ? fallo(mensajeError(error)) : ok(data as Turno[]);
}

/** Horarios libres de un médico en un día. fecha: "YYYY-MM-DD" (hora de la clínica). */
export async function obtenerHorariosDisponibles(
  medicoId: string,
  fecha: string,
): Promise<Resultado<HorarioDisponible[]>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("obtener_horarios_disponibles", {
    p_medico_id: medicoId,
    p_fecha: fecha,
  });
  return error ? fallo(mensajeError(error)) : ok(data as HorarioDisponible[]);
}

/**
 * Paciente: pide un turno para sí mismo (queda PENDIENTE).
 * Administrador: debe indicar paciente_id (queda CONFIRMADO).
 * fecha_inicio debe ser uno de los valores devueltos por obtenerHorariosDisponibles.
 */
export async function solicitarTurno(datos: {
  medico_id: string;
  fecha_inicio: string;
  motivo?: string;
  paciente_id?: string;
}): Promise<Resultado<{ turno_id: string }>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("solicitar_turno", {
    p_medico_id: datos.medico_id,
    p_fecha_inicio: datos.fecha_inicio,
    p_motivo: datos.motivo ?? null,
    p_paciente_id: datos.paciente_id ?? null,
  });
  return error ? fallo(mensajeError(error)) : ok({ turno_id: data as string });
}

/**
 * Administrador: cualquier estado.
 * Médico: confirmar, cancelar, marcar ausente o atendido en su agenda.
 * Paciente: sólo cancelar sus turnos futuros.
 */
export async function cambiarEstadoTurno(turnoId: string, estado: EstadoTurno): Promise<Resultado> {
  const supabase = await crearClienteServidor();
  const { error } = await supabase.rpc("cambiar_estado_turno", {
    p_turno_id: turnoId,
    p_estado: estado,
  });
  return error ? fallo(mensajeError(error)) : ok(null);
}
