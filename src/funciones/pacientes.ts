"use server";

import { crearClienteAdmin } from "@/lib/supabase/admin";
import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { DatosNuevoPaciente, DatosPaciente, Paciente, Resultado } from "./tipos";
import { esAdministrador, fallo, limpiar, mensajeError, ok } from "./utilidades";

/** Administrador: todos. Médico: sus pacientes. Paciente: sólo él mismo. Busca por nombre o DNI. */
export async function listarPacientes(busqueda?: string): Promise<Resultado<Paciente[]>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("listar_pacientes", {
    p_busqueda: busqueda ?? null,
    p_paciente_id: null,
  });
  return error ? fallo(mensajeError(error)) : ok(data as Paciente[]);
}

export async function obtenerPaciente(pacienteId: string): Promise<Resultado<Paciente>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("listar_pacientes", {
    p_busqueda: null,
    p_paciente_id: pacienteId,
  });
  if (error) return fallo(mensajeError(error));
  const paciente = (data as Paciente[])[0];
  return paciente ? ok(paciente) : fallo("Paciente no encontrado.");
}

/** Sólo administrador (alta desde recepción). Los pacientes también pueden auto-registrarse. */
export async function crearPaciente(datos: DatosNuevoPaciente): Promise<Resultado<{ perfil_id: string }>> {
  if (!(await esAdministrador())) return fallo("No tenés permisos para realizar esta acción.");

  const { correo_electronico, contrasena, ...personales } = datos;
  if (!personales.nombre_completo?.trim()) return fallo("El nombre es obligatorio.");
  if (contrasena.length < 6) return fallo("La contraseña debe tener al menos 6 caracteres.");

  const { data, error } = await crearClienteAdmin().auth.admin.createUser({
    email: correo_electronico.trim(),
    password: contrasena,
    email_confirm: true,
    app_metadata: { rol: "PACIENTE" },
    user_metadata: limpiar(personales),
  });
  if (error) {
    return fallo(
      error.message.includes("Database error")
        ? "No se pudo crear el paciente: verificá que el DNI no esté registrado."
        : error.message,
    );
  }
  return ok({ perfil_id: data.user.id });
}

/** Sólo administrador. esta_activo: false bloquea el acceso del paciente. */
export async function actualizarPaciente(
  pacienteId: string,
  datos: Partial<DatosPaciente> & { esta_activo?: boolean },
): Promise<Resultado> {
  if (!(await esAdministrador())) return fallo("No tenés permisos para realizar esta acción.");

  const supabase = await crearClienteServidor();
  const { data: paciente } = await supabase
    .from("pacientes")
    .select("perfil_id")
    .eq("id", pacienteId)
    .maybeSingle();
  if (!paciente) return fallo("Paciente no encontrado.");

  const { nombre_completo, telefono, esta_activo, ...ficha } = datos;

  const cambiosPerfil = limpiar({ nombre_completo, telefono, esta_activo });
  if (Object.keys(cambiosPerfil).length) {
    const { error } = await supabase.from("perfiles").update(cambiosPerfil).eq("id", paciente.perfil_id);
    if (error) return fallo(mensajeError(error));
  }

  const cambiosPaciente = limpiar(ficha);
  if (Object.keys(cambiosPaciente).length) {
    const { error } = await supabase.from("pacientes").update(cambiosPaciente).eq("id", pacienteId);
    if (error) return fallo(mensajeError(error));
  }

  return ok(null);
}
