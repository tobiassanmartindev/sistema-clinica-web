"use server";

import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { Consulta, DatosConsulta, Resultado } from "./tipos";
import { fallo, mensajeError, ok } from "./utilidades";

/**
 * Consultas de un paciente, de la más reciente a la más antigua.
 * Administrador: todas. Paciente: las suyas. Médico: las que él registró.
 */
export async function obtenerHistoriaClinica(pacienteId: string): Promise<Resultado<Consulta[]>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("obtener_historia_clinica", {
    p_paciente_id: pacienteId,
  });
  return error ? fallo(mensajeError(error)) : ok(data as Consulta[]);
}

/**
 * Sólo el médico del turno. Registra la consulta y marca el turno como ATENDIDO.
 * Las consultas no se pueden editar ni borrar una vez guardadas.
 */
export async function registrarConsulta(
  turnoId: string,
  datos: DatosConsulta,
): Promise<Resultado<{ consulta_id: string }>> {
  if (!datos.diagnostico?.trim()) return fallo("El diagnóstico es obligatorio.");

  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("registrar_consulta", {
    p_turno_id: turnoId,
    p_diagnostico: datos.diagnostico,
    p_tratamiento: datos.tratamiento ?? null,
    p_medicacion: datos.medicacion ?? null,
    p_observaciones: datos.observaciones ?? null,
    p_motivo: datos.motivo ?? null,
  });
  return error ? fallo(mensajeError(error)) : ok({ consulta_id: data as string });
}
