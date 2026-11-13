"use server";

import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { Especialidad, Resultado } from "./tipos";
import { fallo, limpiar, mensajeError, ok } from "./utilidades";

export async function listarEspecialidades(
  incluirInactivas = false,
): Promise<Resultado<Especialidad[]>> {
  const supabase = await crearClienteServidor();
  let consulta = supabase
    .from("especialidades")
    .select("id, nombre, descripcion, esta_activa")
    .order("nombre");
  if (!incluirInactivas) consulta = consulta.eq("esta_activa", true);

  const { data, error } = await consulta;
  return error ? fallo(mensajeError(error)) : ok(data);
}

/** Sólo administrador (lo garantiza RLS). */
export async function crearEspecialidad(datos: {
  nombre: string;
  descripcion?: string;
}): Promise<Resultado<Especialidad>> {
  if (!datos.nombre?.trim()) return fallo("El nombre es obligatorio.");

  const supabase = await crearClienteServidor();
  const { data, error } = await supabase
    .from("especialidades")
    .insert(limpiar({ ...datos, nombre: datos.nombre.trim() }))
    .select("id, nombre, descripcion, esta_activa")
    .single();
  return error ? fallo(mensajeError(error)) : ok(data);
}

/** Sólo administrador. Para "eliminar" una especialidad usar esta_activa: false. */
export async function actualizarEspecialidad(
  id: string,
  datos: { nombre?: string; descripcion?: string; esta_activa?: boolean },
): Promise<Resultado> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase
    .from("especialidades")
    .update(limpiar(datos))
    .eq("id", id)
    .select("id");
  if (error) return fallo(mensajeError(error));
  return data.length ? ok(null) : fallo("No tenés permisos o la especialidad no existe.");
}
