"use server";

import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { DatosNuevoPaciente, Resultado, UsuarioActual } from "./tipos";
import { fallo, limpiar, mensajeError, ok } from "./utilidades";

/** Usuario logueado con su perfil, o null si no hay sesión o está inactivo. */
export async function obtenerUsuarioActual(): Promise<UsuarioActual | null> {
  const supabase = await crearClienteServidor();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: perfil } = await supabase
    .from("perfiles")
    .select("id, nombre_completo, correo_electronico, telefono, rol, esta_activo")
    .eq("id", user.id)
    .maybeSingle();
  if (!perfil || !perfil.esta_activo) return null;

  let medico_id: string | null = null;
  let paciente_id: string | null = null;

  if (perfil.rol === "MEDICO") {
    const { data } = await supabase.from("medicos").select("id").eq("perfil_id", user.id).maybeSingle();
    medico_id = data?.id ?? null;
  } else if (perfil.rol === "PACIENTE") {
    const { data } = await supabase.from("pacientes").select("id").eq("perfil_id", user.id).maybeSingle();
    paciente_id = data?.id ?? null;
  }

  return {
    id: perfil.id,
    nombre_completo: perfil.nombre_completo,
    correo_electronico: perfil.correo_electronico,
    telefono: perfil.telefono,
    rol: perfil.rol,
    medico_id,
    paciente_id,
  };
}

export async function iniciarSesion(
  correo: string,
  contrasena: string,
): Promise<Resultado<UsuarioActual>> {
  const supabase = await crearClienteServidor();
  const { error } = await supabase.auth.signInWithPassword({
    email: correo.trim(),
    password: contrasena,
  });
  if (error) return fallo("Correo o contraseña incorrectos.");

  const usuario = await obtenerUsuarioActual();
  if (!usuario) {
    await supabase.auth.signOut();
    return fallo("Tu usuario está inactivo. Comunicate con la clínica.");
  }
  return ok(usuario);
}

/** Auto-registro de pacientes. El trigger de la base crea el perfil y la ficha. */
export async function registrarPaciente(
  datos: DatosNuevoPaciente,
): Promise<Resultado<{ requiere_confirmacion: boolean }>> {
  const { correo_electronico, contrasena, ...personales } = datos;
  if (!personales.nombre_completo?.trim()) return fallo("El nombre es obligatorio.");
  if (contrasena.length < 6) return fallo("La contraseña debe tener al menos 6 caracteres.");

  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.auth.signUp({
    email: correo_electronico.trim(),
    password: contrasena,
    options: { data: limpiar(personales) },
  });
  if (error) {
    return fallo(
      error.message.includes("Database error")
        ? "No se pudo registrar: verificá que el DNI no esté ya registrado."
        : error.message,
    );
  }
  return ok({ requiere_confirmacion: !data.session });
}

export async function cerrarSesion(): Promise<void> {
  const supabase = await crearClienteServidor();
  await supabase.auth.signOut();
}

/** El usuario edita sus propios datos de contacto (no puede cambiar su rol). */
export async function actualizarMiPerfil(datos: {
  nombre_completo?: string;
  telefono?: string;
}): Promise<Resultado> {
  const usuario = await obtenerUsuarioActual();
  if (!usuario) return fallo("Sesión no válida.");

  const supabase = await crearClienteServidor();
  const { error } = await supabase.from("perfiles").update(limpiar(datos)).eq("id", usuario.id);
  return error ? fallo(mensajeError(error)) : ok(null);
}
