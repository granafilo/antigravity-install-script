#!/usr/bin/env bash
# ==============================================================================
# Script di Installazione e Aggiornamento per Antigravity IDE & Antigravity 2.0
# ==============================================================================
# Uso:
#   ./install-antigravity.sh [OPZIONI] [PERCORSO_ARCHIVIO.tar.gz]
#
# Esempi:
#   ./install-antigravity.sh "Antigravity IDE.tar.gz"
#   ./install-antigravity.sh -u "Antigravity IDE.tar.gz"
#   ./install-antigravity.sh -u                # Cerca automaticamente in ~/Scaricati o cartella corrente
#   ./install-antigravity.sh --chat "antigravity.tar.gz"
# ==============================================================================

set -euo pipefail

# Colori per l'output nel terminale
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Percorsi base
APPS_DIR="${HOME}/Applications"
LOCAL_BIN="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICONS_BASE_DIR="${HOME}/.local/share/icons/hicolor"

# Variabili di stato
ARCHIVE_PATH=""
FORCE_TYPE=""     # "ide" oppure "chat"
IS_UPDATE=false
TEMP_EXTRACT=""

cleanup() {
    if [[ -n "${TEMP_EXTRACT:-}" && -d "${TEMP_EXTRACT:-}" ]]; then
        rm -rf "${TEMP_EXTRACT}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Stampa banner e guida
# ------------------------------------------------------------------------------
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       🚀 Antigravity Installer & Updater (Linux)           "
    echo "============================================================"
    echo -e "${NC}"
}

print_help() {
    print_banner
    cat << EOF
Utilizzo:
  $0 [OPZIONI] [ARCHIVIO.tar.gz]

Opzioni:
  -u, --update        Esegue l'aggiornamento dell'applicazione esistente
                      (sostituisce i binari preservando configurazioni e impostazioni)
  -i, --install       Forza la modalità installazione (comportamento predefinito)
      --ide           Forza l'installazione/aggiornamento come Antigravity IDE
      --chat, --2.0   Forza l'installazione/aggiornamento come Antigravity 2.0 (Chat)
  -a, --archive FILE  Specifica esplicitamente il file archivio tar/tar.gz
  -h, --help          Mostra questo messaggio di aiuto

Esempi:
  # Installazione standard con auto-rilevamento dell'archivio:
  $0 ~/Scaricati/Antigravity\ IDE.tar.gz

  # Aggiornamento dell'IDE o di Antigravity 2.0:
  $0 -u ~/Scaricati/Antigravity\ IDE.tar.gz

  # Aggiornamento automatico (cerca l'ultimo archivio scaricato):
  $0 -u

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${BOLD}[✓]${NC} ${GREEN}$1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}${BOLD}[ERRORE]${NC} $1" >&2
}

# ------------------------------------------------------------------------------
# Parsing argomenti
# ------------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--update)
                IS_UPDATE=true
                shift
                ;;
            -i|--install)
                IS_UPDATE=false
                shift
                ;;
            --ide)
                FORCE_TYPE="ide"
                shift
                ;;
            --chat|--2.0|--agent)
                FORCE_TYPE="chat"
                shift
                ;;
            -a|--archive)
                ARCHIVE_PATH="$2"
                shift 2
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            -*)
                log_error "Opzione non riconosciuta: $1"
                echo "Usa '$0 --help' per la guida."
                exit 1
                ;;
            *)
                if [[ -z "$ARCHIVE_PATH" ]]; then
                    ARCHIVE_PATH="$1"
                else
                    log_warn "Argomento aggiuntivo ignorato: $1"
                fi
                shift
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Ricerca automatica archivio se non fornito
# ------------------------------------------------------------------------------
find_archive() {
    if [[ -n "$ARCHIVE_PATH" ]]; then
        if [[ ! -f "$ARCHIVE_PATH" ]]; then
            log_error "Il file specificato non esiste: $ARCHIVE_PATH"
            exit 1
        fi
        return 0
    fi

    log_info "Nessun percorso archivio specificato. Ricerca automatica in corso..."
    
    # Cerca archivi compatibili in cartella corrente, ~/Scaricati e ~/Downloads
    local search_dirs=(".")
    [[ -d "${HOME}/Scaricati" ]] && search_dirs+=("${HOME}/Scaricati")
    [[ -d "${HOME}/Downloads" ]] && search_dirs+=("${HOME}/Downloads")

    local found_files=()
    for dir in "${search_dirs[@]}"; do
        while IFS= read -r -d '' file; do
            found_files+=("$file")
        done < <(find "$dir" -maxdepth 1 -type f \( -iname "*antigravity*.tar*" -o -iname "*antigravity*.tgz" \) -print0 2>/dev/null)
    done

    if [[ ${#found_files[@]} -eq 0 ]]; then
        log_error "Nessun archivio Antigravity (*.tar.gz, *.tgz, *.tar) trovato automaticamente."
        echo -e "Specificare il percorso dell'archivio. Esempio:\n  $0 \"/percorso/archivio.tar.gz\""
        exit 1
    elif [[ ${#found_files[@]} -eq 1 ]]; then
        ARCHIVE_PATH="${found_files[0]}"
        log_info "Trovato archivio: ${ARCHIVE_PATH}"
    else
        echo -e "${YELLOW}Sono stati trovati molteplici archivi:${NC}"
        local idx=1
        for f in "${found_files[@]}"; do
            echo "  [$idx] $f"
            ((idx++))
        done
        printf "Seleziona il numero dell'archivio da usare [1-%d]: " "${#found_files[@]}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#found_files[@]} )); then
            ARCHIVE_PATH="${found_files[$((choice-1))]}"
        else
            log_error "Selezione non valida."
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Rilevamento tipo applicazione (IDE vs Chat/2.0)
# ------------------------------------------------------------------------------
detect_app_type() {
    if [[ -n "$FORCE_TYPE" ]]; then
        APP_TYPE="$FORCE_TYPE"
        return 0
    fi

    log_info "Analisi del contenuto dell'archivio: $(basename "$ARCHIVE_PATH")..."
    
    # Ispezione del sommario tar
    local tar_listing
    tar_listing=$(tar -tf "$ARCHIVE_PATH" 2>/dev/null | head -n 100 || true)

    if echo "$tar_listing" | grep -qiE "antigravity-ide|Antigravity IDE|resources/app/out/cli.js|bin/antigravity-ide"; then
        APP_TYPE="ide"
    elif echo "$tar_listing" | grep -qiE "antigravity-chat|antigravity"; then
        APP_TYPE="chat"
    else
        # Fallback basato sul nome file
        local base_lower
        base_lower=$(basename "$ARCHIVE_PATH" | tr '[:upper:]' '[:lower:]')
        if [[ "$base_lower" =~ "ide" ]]; then
            APP_TYPE="ide"
        else
            APP_TYPE="chat"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Setup percorsi in base al tipo
# ------------------------------------------------------------------------------
setup_app_metadata() {
    if [[ "$APP_TYPE" == "ide" ]]; then
        APP_NAME="Antigravity IDE"
        APP_ID="antigravity-ide"
        TARGET_DIR="${APPS_DIR}/antigravity-ide"
        DESKTOP_FILE="${DESKTOP_DIR}/antigravity-ide.desktop"
        BIN_NAME="antigravity-ide"
    else
        APP_NAME="Antigravity 2.0"
        APP_ID="antigravity"
        TARGET_DIR="${APPS_DIR}/antigravity-chat"
        DESKTOP_FILE="${DESKTOP_DIR}/antigravity.desktop"
        BIN_NAME="antigravity"
    fi
}

# ------------------------------------------------------------------------------
# Installazione / Aggiornamento File Binari
# ------------------------------------------------------------------------------
install_files() {
    local mode_str="Installazione"
    if [[ "$IS_UPDATE" == true ]] || [[ -d "$TARGET_DIR" ]]; then
        mode_str="Aggiornamento"
        IS_UPDATE=true
    fi

    log_info "Avvio ${mode_str} per ${BOLD}${APP_NAME}${NC}..."

    # Creazione cartelle base se non esistono
    mkdir -p "${APPS_DIR}" "${LOCAL_BIN}" "${DESKTOP_DIR}" "${ICONS_BASE_DIR}"

    # Directory temporanea per estrazione sicura
    TEMP_EXTRACT=$(mktemp -d "/tmp/antigravity_install_XXXXXX")

    log_info "Estrazione archivio in corso..."
    tar -xf "$ARCHIVE_PATH" -C "$TEMP_EXTRACT"

    # Controllo struttura estratta (singola cartella interna o contenuto diretto)
    local items=("$TEMP_EXTRACT"/*)
    local source_dir="$TEMP_EXTRACT"

    if [[ ${#items[@]} -eq 1 ]] && [[ -d "${items[0]}" ]]; then
        source_dir="${items[0]}"
    fi

    # Se è un aggiornamento e la cartella di destinazione esiste già, esegui backup temporaneo
    local backup_dir=""
    if [[ -d "$TARGET_DIR" ]]; then
        backup_dir="${TARGET_DIR}_backup_$(date +%s)"
        log_info "Salvataggio backup versione precedente in: $(basename "$backup_dir")..."
        mv "$TARGET_DIR" "$backup_dir"
    fi

    # Spostamento nuovi file
    log_info "Posizionamento nuovi file in: ${TARGET_DIR}..."
    mkdir -p "$TARGET_DIR"
    cp -a "$source_dir"/. "$TARGET_DIR"/

    # Rimuovi backup temporaneo se tutto ok
    if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
        rm -rf "$backup_dir"
    fi

    # Impostazione permessi eseguibili
    log_info "Configurazione permessi eseguibili..."
    if [[ "$APP_TYPE" == "ide" ]]; then
        chmod +x "${TARGET_DIR}/antigravity-ide" 2>/dev/null || true
        chmod +x "${TARGET_DIR}/bin/antigravity-ide" 2>/dev/null || true
        chmod +x "${TARGET_DIR}/chrome-sandbox" 2>/dev/null || true
        chmod +x "${TARGET_DIR}/chrome_crashpad_handler" 2>/dev/null || true
    else
        chmod +x "${TARGET_DIR}/antigravity" 2>/dev/null || true
        chmod +x "${TARGET_DIR}/chrome-sandbox" 2>/dev/null || true
        chmod +x "${TARGET_DIR}/chrome_crashpad_handler" 2>/dev/null || true
    fi

    log_success "File dell'applicazione posizionati correttamente."
}

# ------------------------------------------------------------------------------
# Installazione Icone di Sistema
# ------------------------------------------------------------------------------
install_icons() {
    log_info "Configurazione icone di sistema..."
    local src_icon=""

    if [[ "$APP_TYPE" == "ide" ]]; then
        # Cerca icone valide nell'IDE
        for candidate in \
            "${TARGET_DIR}/antigravity-ide.png" \
            "${TARGET_DIR}/icon.png" \
            "${TARGET_DIR}/resources/app/resources/linux/code.png" \
            "${TARGET_DIR}/resources/app/out/media/code-icon.png"; do
            if [[ -f "$candidate" ]]; then
                src_icon="$candidate"
                break
            fi
        done

        # Salva copia icona principale nella cartella applicazione
        if [[ -n "$src_icon" ]]; then
            cp -f "$src_icon" "${TARGET_DIR}/antigravity-ide.png"
            cp -f "$src_icon" "${TARGET_DIR}/icon.png"
        fi

        # Installa nei percorsi standard hicolor
        local icon_names=("antigravity-ide")
    else
        # Cerca icone valide nella Chat / 2.0
        for candidate in \
            "${TARGET_DIR}/antigravity.png" \
            "${TARGET_DIR}/antigravity-chat.png" \
            "${TARGET_DIR}/icon.png"; do
            if [[ -f "$candidate" ]]; then
                src_icon="$candidate"
                break
            fi
        done

        if [[ -n "$src_icon" ]]; then
            cp -f "$src_icon" "${TARGET_DIR}/antigravity.png"
            cp -f "$src_icon" "${TARGET_DIR}/antigravity-chat.png"
            cp -f "$src_icon" "${TARGET_DIR}/icon.png"
        fi

        local icon_names=("antigravity" "antigravity-chat")
    fi

    if [[ -n "$src_icon" && -f "$src_icon" ]]; then
        local sizes=(16 24 32 48 64 128 256 512 1024)
        local has_convert=false
        command -v convert >/dev/null 2>&1 && has_convert=true

        for sz in "${sizes[@]}"; do
            local dest_icon_dir="${ICONS_BASE_DIR}/${sz}x${sz}/apps"
            mkdir -p "$dest_icon_dir"

            for iname in "${icon_names[@]}"; do
                local target_icon_file="${dest_icon_dir}/${iname}.png"
                if [[ "$has_convert" == true ]]; then
                    convert "$src_icon" -resize "${sz}x${sz}" "$target_icon_file" 2>/dev/null || cp -f "$src_icon" "$target_icon_file"
                else
                    cp -f "$src_icon" "$target_icon_file"
                fi
            done
        done
        log_success "Icone installate in ~/.local/share/icons/hicolor/"
    else
        log_warn "Nessuna icona PNG trovata nell'archivio. Verranno usate le icone di fallback del tema."
    fi
}

# ------------------------------------------------------------------------------
# Creazione File Desktop (.desktop)
# ------------------------------------------------------------------------------
install_desktop_entry() {
    log_info "Creazione scorciatoia desktop: $(basename "$DESKTOP_FILE")..."

    if [[ "$APP_TYPE" == "ide" ]]; then
        cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Antigravity IDE
Comment=AI-Powered Integrated Development Environment
GenericName=Integrated Development Environment
Exec=${TARGET_DIR}/antigravity-ide --no-sandbox %F
Icon=antigravity-ide
Type=Application
StartupNotify=true
StartupWMClass=antigravity-ide
Categories=Development;IDE;Utility;TextEditor;
MimeType=text/plain;inode/directory;x-scheme-handler/antigravity-ide;
Keywords=vscode;code;development;ide;antigravity;ai;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Name[it]=Nuova finestra vuota
Exec=${TARGET_DIR}/antigravity-ide --no-sandbox --new-window %F
Icon=antigravity-ide
EOF
    else
        cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Antigravity 2.0
Comment=Antigravity AI Assistant & Agent Workspace
GenericName=AI Assistant
Exec=${TARGET_DIR}/antigravity --no-sandbox %U
Icon=antigravity
Type=Application
StartupNotify=true
StartupWMClass=antigravity
Categories=Utility;Development;
Keywords=antigravity;chat;ai;assistant;agent;gemini;
Actions=new-window;

[Desktop Action new-window]
Name=New Window
Name[it]=Nuova finestra
Exec=${TARGET_DIR}/antigravity --no-sandbox
Icon=antigravity
MimeType=x-scheme-handler/antigravity;text/html;
EOF
    fi

    chmod 644 "$DESKTOP_FILE"
    log_success "Launcher desktop aggiornato."
}

# ------------------------------------------------------------------------------
# Creazione Comandi CLI / Symlink in ~/.local/bin
# ------------------------------------------------------------------------------
install_cli_commands() {
    log_info "Configurazione comandi CLI in ~/.local/bin/..."

    if [[ "$APP_TYPE" == "ide" ]]; then
        # Se esiste bin/antigravity-ide, collega ad esso
        if [[ -f "${TARGET_DIR}/bin/antigravity-ide" ]]; then
            ln -sf "${TARGET_DIR}/bin/antigravity-ide" "${LOCAL_BIN}/antigravity-ide"
        else
            ln -sf "${TARGET_DIR}/antigravity-ide" "${LOCAL_BIN}/antigravity-ide"
        fi
        log_success "Comando da terminale disponibile: 'antigravity-ide'"
    else
        # Script wrapper per la Chat / Antigravity 2.0
        local wrapper_script="${LOCAL_BIN}/antigravity"
        cat > "$wrapper_script" << EOF
#!/usr/bin/env bash
exec "${TARGET_DIR}/antigravity" --no-sandbox "\$@"
EOF
        chmod +x "$wrapper_script"

        # Symlink per retrocompatibilità antigravity-chat
        ln -sf "${LOCAL_BIN}/antigravity" "${LOCAL_BIN}/antigravity-chat"
        log_success "Comandi da terminale disponibili: 'antigravity' e 'antigravity-chat'"
    fi
}

# ------------------------------------------------------------------------------
# Aggiornamento cache di sistema
# ------------------------------------------------------------------------------
update_system_caches() {
    log_info "Aggiornamento database desktop e cache icone..."
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "${ICONS_BASE_DIR}" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# Controllo PATH
# ------------------------------------------------------------------------------
check_path() {
    if [[ ":$PATH:" != *":${LOCAL_BIN}:"* ]]; then
        log_warn "~/.local/bin non sembra essere presente nel tuo \$PATH."
        echo -e "Per eseguire il comando direttamente da qualsiasi terminale, puoi aggiungere:"
        echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC} nel tuo ~/.bashrc"
    fi
}

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
main() {
    parse_args "$@"
    print_banner
    find_archive
    detect_app_type
    setup_app_metadata

    echo -e "${BOLD}Dettagli operazione:${NC}"
    echo -e "  • Applicazione:  ${CYAN}${APP_NAME}${NC}"
    echo -e "  • Modalità:      ${CYAN}$([ "$IS_UPDATE" = true ] && echo "Aggiornamento (-u)" || echo "Installazione")${NC}"
    echo -e "  • Archivio sorg: ${ARCHIVE_PATH}"
    echo -e "  • Destinazione:  ${TARGET_DIR}"
    echo ""

    install_files
    install_icons
    install_desktop_entry
    install_cli_commands
    update_system_caches
    check_path

    echo ""
    echo -e "${GREEN}============================================================${NC}"
    if [[ "$IS_UPDATE" == true ]]; then
        echo -e "${GREEN}${BOLD}  ✨ Aggiornamento di ${APP_NAME} completato con successo! ✨${NC}"
    else
        echo -e "${GREEN}${BOLD}  ✨ Installazione di ${APP_NAME} completata con successo! ✨${NC}"
    fi
    echo -e "${GREEN}============================================================${NC}"
    echo -e "Puoi avviare l'applicazione dal menu del tuo ambiente desktop oppure da terminale:"
    if [[ "$APP_TYPE" == "ide" ]]; then
        echo -e "  ${BOLD}antigravity-ide [cartella_progetto]${NC}"
    else
        echo -e "  ${BOLD}antigravity${NC}"
    fi
    echo ""
}

main "$@"
