// Helpers internos de las funciones (no son Server Actions).
import type { PostgrestError } from "@supabase/supabase-js";
import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { Resultado } from "./tipos";

export function ok<T>(datos: T): Resultado<T> {
  return { ok: true, datos };
}

export function fallo<T = never>(error: string): Resultado<T> {
  return { ok: false, error };
}

/** Convierte un error de Supabase/Postgres en un mensaje para mostrar al usuario. */
export function mensajeError(error: Pick<PostgrestError, "message"> & { code?: string }): string {
  switch (error.code) {
    case "P0001": // RAISE EXCEPTION de nuestras funciones: el mensaje ya es legible.
      return error.message;
    case "23505":
      return "Ya existe un registro con esos datos (DNI, matrícula, correo o nombre duplicado).";
    case "23503":
      return "El registro está relacionado con otros datos y no se puede modificar o eliminar.";
    case "23P01":
      return "El horario elegido ya está ocupado.";
    case "23502":
      return "Falta completar un dato obligatorio.";
    case "23514":
      return "Algún dato no tiene un valor válido.";
    case "42501":
      return "No tenés permisos para realizar esta acción.";
    default:
      return error.message || "Ocurrió un error inesperado.";
  }
}

/** Valida que el usuario logueado sea administrador activo. */
export async function esAdministrador(): Promise<boolean> {
  const supabase = await crearClienteServidor();
  const { data } = await supabase.rpc("es_administrador");
  return data === true;
}

/** Quita claves con undefined o string vacío y convierte "" en null para la base. */
export function limpiar<T extends object>(datos: T): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(datos)
      .filter(([, valor]) => valor !== undefined)
      .map(([clave, valor]) => [clave, typeof valor === "string" && valor.trim() === "" ? null : valor]),
  );
}
