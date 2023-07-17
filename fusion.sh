#!/bin/bash

# Verificar si se está ejecutando como administrador
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ser ejecutado como administrador."
    exit 1
fi

# Función para ejecutar el script Repositorios-sources_list.sh
function ejecutar_menu() {
    echo "Ejecutando el script Repositorios-sources_list.sh..."
    bash Proxmox-local/Scripts/Repositorios-sources_list.sh
}

# Función para ejecutar el script Generico.sh
function ejecutar_generico() {
    echo "Ejecutando el script Generico.sh..."
    bash Proxmox-local/Scripts/GPU-Passthrough/Generico.sh
}

# Asignar permisos de ejecución a los scripts necesarios
function asignar_permisos() {
    echo "Asignando permisos de ejecución a los scripts..."
    chmod +x Proxmox-local/Scripts/Repositorios-sources_list.sh
    chmod +x Proxmox-local/Scripts/GPU-Passthrough/Generico.sh
}

# Mostrar el menú de selección
function mostrar_menu() {
    clear
    echo "Menú de selección:"
    echo "1. Instalar repositorios Proxmox"
    echo "2. Instalar y configurar GPU-Passthrough"
    echo "3. Configuración de IOMMU y GPU-Passthrough"
    echo "0. Salir"
    echo ""
}

# Bucle principal
while true; do
    mostrar_menu

    # Leer la opción seleccionada
    read -p "Ingrese el número de opción: " opcion
    echo ""

    # Evaluar la opción seleccionada
    case $opcion in
        1)
            asignar_permisos
            ejecutar_menu
            ;;
        2)
            asignar_permisos
            ejecutar_generico
            ;;
        3)
            echo "Configuración de IOMMU y GPU-Passthrough..."
            # Script para configuración de IOMMU y GPU-Passthrough
            # Colores
            RED='\e[0;31m'
            GREEN='\e[0;32m'
            BLUE='\e[0;34m'
            NC='\e[0m' # No Color

            # Comprobar si el usuario es root
            if [[ $EUID -ne 0 ]]; then
                echo -e "${RED}Este script debe ser ejecutado como root.${NC}"
                exit 1
            fi

            # Comprobar si sudo está instalado, si no, instalarlo.
            if ! command -v sudo &> /dev/null; then
                echo -e "${BLUE}sudo no está instalado. Instalando...${NC}"
                apt-get update
                apt-get install sudo -y
            fi

            # Función para preguntar si se desea continuar
            ask_continue() {
                echo -e "${BLUE}=================================================${NC}"
                echo -e "${BLUE}| El siguiente paso consistirá en:             |${NC}"
                echo -e "${BLUE}=================================================${NC}"
                echo -e "${GREEN}$1${NC}"
                echo -e "${BLUE}-------------------------------------------------${NC}"
                read -p "$(echo -e ${BLUE}¿Deseas continuar?${NC} (y/n) )" answer
                case $answer in
                    [yY])
                        echo -e "${BLUE}Continuando...${NC}"
                        ;;
                    *)
                        echo -e "${RED}Saltando al siguiente paso.${NC}"
                        return 1
                        ;;
                esac
            }

            # Función para crear una copia de seguridad del archivo
            backup_file() {
                echo -e "${BLUE}=================================================${NC}"
                echo -e "${BLUE}| Creando una copia de seguridad de sources.list |${NC}"
                echo -e "${BLUE}=================================================${NC}"
                backup_filename="/etc/apt/sources.list.bak_$(date +%Y%m%d_%H%M%S)"
                sudo cp "/etc/apt/sources.list" "$backup_filename"
                echo -e "${GREEN}Copia de seguridad creada en $backup_filename.${NC}"
            }

            # Función para modificar el archivo sources.list
            modify_sources_list() {
                echo -e "${BLUE}===============================================${NC}"
                echo -e "${BLUE}| Modificando el archivo sources.list          |${NC}"
                echo -e "${BLUE}===============================================${NC}"

                # Agregar repositorios de Debian
                echo "deb http://ftp.debian.org/debian bullseye main contrib" | sudo tee -a "/etc/apt/sources.list"
                echo "deb http://ftp.debian.org/debian bullseye-updates main contrib" | sudo tee -a "/etc/apt/sources.list"
                echo "deb http://security.debian.org/debian-security bullseye-security main contrib" | sudo tee -a "/etc/apt/sources.list"

                # Agregar repositorio de Proxmox VE
                echo "# PVE pve-no-subscription repository provided by proxmox.com, NOT recommended for production use" | sudo tee -a "/etc/apt/sources.list"
                echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" | sudo tee -a "/etc/apt/sources.list"

                echo -e "${GREEN}Archivo sources.list modificado.${NC}"
            }

            # Ejecutar las funciones
            ask_continue "Hacer una copia de seguridad de tu archivo sources.list." && backup_file
            ask_continue "Modificar el archivo sources.list." && modify_sources_list

            # Continuar con la instalación de dependencias
            echo -e "${BLUE}===============================================${NC}"
            echo -e "${BLUE}|       Instalación de dependencias           |${NC}"
            echo -e "${BLUE}===============================================${NC}"
            ask_continue "Actualizar el sistema." || exit

            # Actualizar el sistema
            echo -e "${GREEN}Actualizando el sistema...${NC}"
            sudo apt update && sudo apt -y upgrade
            ask_continue "Instalar herramientas necesarias." || exit

            # Instalar herramientas necesarias
            echo -e "${GREEN}Instalando herramientas necesarias...${NC}"
            sudo apt -y install build-essential dkms
            ask_continue "Clonar repositorios necesarios." || exit

            # Clonar repositorios necesarios
            echo -e "${GREEN}Clonando repositorios necesarios...${NC}"
            git clone https://github.com/DualCoder/vgpu_unlock
            git clone https://github.com/mbilker/vgpu_unlock-rs
            ask_continue "Instalar Rust." || exit

            # Instalar Rust
            echo -e "${GREEN}Instalando Rust...${NC}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
            ask_continue "Descargar e instalar los encabezados de Proxmox VE." || exit

            # Descargar e instalar los encabezados de Proxmox VE
            echo -e "${GREEN}Descargando e instalar los encabezados de Proxmox VE...${NC}"
            wget http://download.proxmox.com/debian/dists/bullseye/pve-no-subscription/binary-amd64/pve-headers-5.15.30-2-pve_5.15.30-3_amd64.deb
            sudo dpkg -i pve-headers-5.15.30-2-pve_5.15.30-3_amd64.deb

            # Informar al usuario sobre la necesidad de descargar manualmente el controlador de nVidia vGPU
            echo -e "${BLUE}=================================================${NC}"
            echo -e "${BLUE}| Siguiente paso:                             |${NC}"
            echo -e "${BLUE}=================================================${NC}"
            echo -e "${GREEN}Descargue el controlador v14.0 nVidia vGPU para Linux KVM desde https://nvid.nvidia.com${NC}"
            echo -e "${GREEN}Necesitará solicitar acceso y registrarse para descargar.${NC}"
            echo -e "${GREEN}Después de descargar el controlador, desempaquete e instálelo manualmente.${NC}"
            echo -e "${GREEN}Por favor, reinicie su sistema después de la instalación.${NC}"
            ;;
        0)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción inválida. Por favor, ingrese un número de opción válido."
            ;;
    esac

    # Pausa antes de volver a mostrar el menú
    read -p "Presione Enter para continuar..."
done
