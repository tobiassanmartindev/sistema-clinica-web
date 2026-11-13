import { createClient } from "@supabase/supabase-js";

/**
 * Cliente con la clave service_role: ignora RLS.
 * Usar SOLO en el servidor y SOLO después de verificar que quien llama es administrador.
 */
export function crearClienteAdmin() {
  const clave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!clave) {
    throw new Error("Falta configurar SUPABASE_SERVICE_ROLE_KEY en el archivo .env");
  }

  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, clave, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
