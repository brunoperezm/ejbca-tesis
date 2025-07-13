workspace "PKI con Uso de Certificados x509 para autenticar usuarios en servidores" {
    model {
        user = person "Usuario final"
        oficial_registro = person "Oficial de registro"
        userHost = softwareSystem "Host de usuario" {
            ssh_client = container "SSH Client" "Herramienta ssh/ssh-add" "OpenSSH"
            ssh_agent = container "ssh-agent" "Mantiene claves y firma peticiones" "OpenSSH ssh-agent"
            pkcs11_module = container "PKCS#11 Module" "libsofthsm2.so: expone SoftHSM a OpenSSH" "Biblioteca C PKCS#11"
            soft_hsm_store = container "SoftHSM2 Token Store" "Archivos de token cifrados" "SoftHSM2"
            ssh_client -> ssh_agent "Solicita firmas"
            ssh_agent -> pkcs11_module "Carga módulo"
            pkcs11_module -> soft_hsm_store "Accede al token"
        }
        bastion = softwareSystem "Bastion" "Proxy de autenticacion a la red interna." {
            bastion_container = container "Servidor Bastion" "Servidor que recibe conexiones SSH y redirige conecciones SSH" "Linux Server" {
                ssh_server_bastion = component "SSH Daemon" "Servicio SSH que recibe conexiones entrantes." "sshd"
                pam_bastion = component "PAM" "Linux" "Subsistema de autenticación modular."
                pam_python_bastion = component "PAM Python" "Python" "Módulo PAM que incorpora un intérprete Python."

                ssh_server_bastion -> pam_bastion "Autentica usuario" "PAM authenticate call"
                pam_bastion -> pam_python_bastion "Utiliza módulo Python para lógica personalizada" "Python Interpreter"
            }
        }
        ejbca = softwareSystem "EJBCA" "Autoridad de certificacion, registro y validacion." {
            ejbca_rest_api = container "EJBCA REST API" "EJBCA REST API" "EJBCA REST API"
            ejbca_va = container "EJBCA VA" "EJBCA Validation Authority" "EJBCA Validation Authority"
            ejbca_ca = container "EJBCA CA" "EJBCA Certification Authority" "EJBCA Certification Authority"
            ejbca_ra = container "EJBCA RA" "EJBCA Registration Authority" "EJBCA Registration Authority"
            ejbca_rest_api -> ejbca_va "Valida certificados" "REST HTTPS"
            ejbca_ra -> ejbca_ca "Registra certificados" "Web Ui"
        }
        auth_server = softwareSystem "Servicio de autenticacion" "Servidor de autenticacion de usuarios." {
            nginx = container "SSL Proxy Server" "Nginx"
            auth_service = container "Auth Service" "Servicio de autenticacion" "Python FastAPI" {
                group "Capa de Presentación" {
                    api_rest = component "Certificate Controller" "Expone endpoints para la validación de certificados" "FastAPI"
                }
    
                group "Capa de Aplicación" {
                    orquestador_autenticacion = component "Orquestador de Autenticación" "Coordina el flujo completo de autenticación" "Python"
                }
    
                group "Capa de Dominio" {
                    dominio_certificados = component "Dominio de Certificados" "Lógica de negocio para certificados y validaciones" "Python"
                    gestion_claves = component "Gestión de Claves" "Manejo y conversión de claves criptográficas" "Python/OpenSSL"
                    repositorio_certificados = component "Repositorio de Certificados" "Interfaz de acceso a datos de certificados y validación de estado" "Python Abstract Class"
                }
    
                group "Capa de Infraestructura" {
                    repositorio_certificados_impl = component "Implementacion Repositorio de Certificados" "Implementa el repositorio en sí" "Python + EJBCA REST API"
                    parseador_certificados = component "Parser de Certificados" "Procesamiento de certificados X.509" "pyOpenSSL library"
                    configuracion = component "Configuración" "Manejo de configuración del sistema" "Python / YAML"
                }
                 
                # Relaciones principales del flujo de autenticación
                api_rest -> orquestador_autenticacion "delega solicitud autenticación"
                orquestador_autenticacion -> dominio_certificados "valida certificados"
                orquestador_autenticacion -> gestion_claves "solicita conversión de certificado en una entrada válida de authorized_keys file"
                # Relaciones del dominio con infraestructura
                orquestador_autenticacion -> repositorio_certificados "consulta estado de certificados"
                orquestador_autenticacion -> repositorio_certificados "obtiene certificado X.509 completo"
                repositorio_certificados -> repositorio_certificados_impl "Delega implementación"
                repositorio_certificados_impl -> parseador_certificados "solicita decodificación de certificados"
    
                
    
                # Configuración
                api_rest -> configuracion "obtiene configuración"
                repositorio_certificados_impl -> configuracion "obtiene llaves y acceso necesarios para comunicarse EJBCA REST API"
            }
            nginx -> api_rest "Redirije solicitud" "HTTP request"
        }
        destino1 = softwareSystem "Servidor destino 1" "Servidor interno que maneja conexiones SSH autenticadas mediante PAM y pam_python." {
            destino_container = container "Servidor Destino 1" "Servidor que recibe conexiones SSH y gestiona autenticación PAM mediante pam_python." "Linux Server" {
                ssh_server = component "SSH Daemon" "Servicio SSH que recibe conexiones entrantes." "sshd"
                pam = component "PAM" "Linux" "Subsistema de autenticación modular."
                pam_python = component "PAM Python" "Python" "Módulo PAM que incorpora un intérprete Python."

                ssh_server -> pam "Autentica usuario" "PAM authenticate call"
                pam -> pam_python "Utiliza módulo Python para lógica personalizada" "Python Interpreter"
            }
        }
        // Registro de certificados
        oficial_registro -> ejbca_ra "Registra CSR provisto por usuario" "Web Ui"
        user -> oficial_registro "Solicita un certificado para acceder a destino1" "CSR"
        // Autenticacion de usuarios
        user -> ssh_client "Solicitud de acceso a destino 1 vía bastion" "SSH Command"
        ssh_client -> ssh_server_bastion "Solicitud de conexión" "SSH tunnel"
        pam_python_bastion -> nginx "Valida que certificado no este expirado ni revocado" "REST HTTPS"
        auth_service -> ejbca_rest_api "Pregunta estado de revocacion de un certificado" "REST HTTPS"
        auth_service -> ejbca_rest_api "Busca el certificado completo" "REST HTTPS"
        ssh_server_bastion -> destino_container "Redirije solicitud de conexion" "SSH"
        destino_container -> nginx "Valida que certificado no este expirado ni revocado" "HTTPS with MTLS"
        destino_container -> userHost "Acceso a servidor destino" "SSH"
        // Interacion externa auth-service
        repositorio_certificados_impl -> ejbca_rest_api "Consulta estado de revocacion" "HTTPs Request"
        repositorio_certificados_impl -> ejbca "Obtiene certificado" "HTTPs Request"
    }

    views {
        
        systemLandscape SystemView {
            include *
            // autoLayout lr
        }
        container auth_server {
            include bastion_container nginx auth_service destino_container ejbca
            autoLayout lr
        }
        
        component bastion_container {
            include *
            // autoLayout lr
        }
        component auth_service {
            include *
            autoLayout lr
        }
        component destino_container {
            include *
            autoLayout tb
        }
    
        container ejbca {
            include *
            autoLayout tb
        }
        container userHost {
            include *
        }
        
        dynamic auth_service "AuthenticationFlow" "Flujo de autenticación de certificados X.509" {
            title "Flujo de validación de certificado en el servicio de autenticación"
            // autoLayout lr
    
            # 1. Llegada de la solicitud desde PAM
            nginx -> api_rest "Redirije solicitud de validación de certificado"
    
            # 2. Controller procesa solicitud
            api_rest -> orquestador_autenticacion "Delega validación del certificado"
    
            # 3. Verificar si certificado está revocado
            orquestador_autenticacion -> repositorio_certificados "Verificar estado de revocación"
            repositorio_certificados -> repositorio_certificados_impl "Obtención del certificado completo"
            repositorio_certificados_impl -> ejbca_rest_api "Consultar estado de revocacion"
    
            # 4. Obtener certificado completo
            orquestador_autenticacion -> repositorio_certificados "Obtener datos del certificado"
            repositorio_certificados -> repositorio_certificados_impl "Obtener datos del certificado"
            repositorio_certificados_impl -> ejbca_rest_api "Buscar certificado"
            repositorio_certificados_impl -> parseador_certificados "Decodificar certificado X.509"
    
            # 5. Validar certificado en dominio
            orquestador_autenticacion -> dominio_certificados "Verificar vigencia"
    
            # 6. Verificar roles/permisos
            dominio_certificados -> orquestador_autenticacion "Usuario autenticado"
    
            # 7. Generar authorized_keys entry
            orquestador_autenticacion -> gestion_claves "Generar entrada para authorized_keys"
    
            # 8. Respuesta exitosa
            orquestador_autenticacion -> api_rest "Autenticación exitosa con clave SSH"
            api_rest -> nginx "Respuesta HTTP con json apropiado"
        }
        theme default
    }
}