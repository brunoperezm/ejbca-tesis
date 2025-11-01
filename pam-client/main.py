#!/usr/bin/env python2
# -*- coding: utf-8 -*-
import json
import urllib2
import ssl

# Función para llamar al endpoint del servidor de autenticación usando un certificado cliente.
def authenticate(serial_id, username):
    base_url = "https://localhost:8888"  # cambiado a HTTPS
    url = base_url + "/api/v1/certificate/" + serial_id + "/validate?username=" + username
    
    try:
        # Configurar el contexto SSL con los certificados
        ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        
        # Cargar certificado y llave del cliente
        ctx.load_cert_chain(
            certfile='client.crt',  # Ruta al certificado del cliente
            keyfile='client.key'    # Ruta a la llave privada del cliente
        )
        
        # Verificación del certificado del servidor 
        ctx.load_verify_locations('/etc/pam_python/ca.crt')  # Ruta al certificado CA
        
        # Crear solicitud HTTPS
        request = urllib2.Request(url)
        
        # Abrir la conexión con el contexto SSL
        response = urllib2.urlopen(request, context=ctx)
        code = response.getcode()
        content = response.read()
        
    except urllib2.URLError as e:
        print("Error llamando al endpoint para serial: %s" % serial_id)
        print(str(e))
        return {"allowed": False, "authorized_keys_entry": None}

    if code == 200:
        return json.loads(content)
    elif code in (400, 403):
        try:
            return json.loads(content)
        except Exception:
            return {"allowed": False, "authorized_keys_entry": None}
    elif code == 500:
        print("Error interno en el servidor de autenticación para el certificado %s" % serial_id)
        return {"allowed": False, "authorized_keys_entry": None}
    else:
        print("Código de respuesta inesperado %s para el certificado %s" % (code, serial_id))
        return {"allowed": False, "authorized_keys_entry": None}


# Funciones relacionadas con PAM

def pam_sm_authenticate(pamh, flags, argv):
    try:
        user = pamh.get_user(None)
        if user is None:
            print("Usuario es None")
            return pamh.PAM_USER_UNKNOWN

        # Abrir el archivo authorized_keys
        f = open("/home/" + user + "/.ssh/authorized_keys", "w+")
        if f is None:
            print("No se pudo abrir el archivo authorized_keys")
            return pamh.PAM_USER_UNKNOWN

        msg = pamh.Message(
            pamh.PAM_PROMPT_ECHO_ON, "Ingrese el serial_id de su certificado: "
        )
        resp = pamh.conversation(msg)
        serial_id = resp.resp
        if serial_id is None:
            return pamh.PAM_USER_UNKNOWN

        pamh.conversation(
            pamh.Message(
                pamh.PAM_TEXT_INFO, "Buscando certificado con serial_id: " + serial_id
            )
        )

        # Llamar al servidor de autenticación
        auth_response = authenticate(serial_id, user)
        if not auth_response.get("allowed"):
            print("El certificado %s no está autorizado." % serial_id)
            return pamh.PAM_AUTH_ERR

        # Obtener el campo autorizado_keys_entry (nota: en la respuesta es "authorized_keys_entry")
        authorized_keys_entry = auth_response.get("authorized_keys_entry")
        if not authorized_keys_entry:
            print("Error en la respuesta del servicio para serial_id %s." % serial_id)
            return pamh.PAM_AUTH_ERR


        pamh.conversation(
            pamh.Message(
                pamh.PAM_TEXT_INFO,
                "¡Certificado encontrado! Clave autorizada añadida a authorized_keys.",
            )
        )

        f.write(authorized_keys_entry + "\n")
        f.close()

        # Para testeo se escribe información en /tmp/enviroment_test
        f2 = open("/tmp/enviroment_test", "w")
        f2.write("\nuser:" + user)
        f2.close()
    except Exception as e:
        f3 = open("/tmp/error", "w")
        f3.write(str(e))
        f3.close()
        return pamh.PAM_USER_UNKNOWN

    return pamh.PAM_SUCCESS


def pam_sm_setcred(pamh, flags, argv):
    return pamh.PAM_SUCCESS


def pam_sm_acct_mgmt(pamh, flags, argv):
    return pamh.PAM_SUCCESS


def pam_sm_open_session(pamh, flags, argv):
    return pamh.PAM_SUCCESS


def pam_sm_close_session(pamh, flags, argv):
    user = pamh.get_user(None)
    if user is None:
        print("Usuario es None")
        return pamh.PAM_USER_UNKNOWN

    # Abrir el archivo authorized_keys
    f = open("/home/" + user + "/.ssh/authorized_keys", "w+")
    f.write("")
    f.close()
    if f is None:
        print("No se pudo abrir el archivo authorized_keys")

    return pamh.PAM_SUCCESS


def pam_sm_chauthtok(pamh, flags, argv):
    return pamh.PAM_SUCCESS

