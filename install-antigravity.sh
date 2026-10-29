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
PIXMAPS_DIR="${HOME}/.local/share/pixmaps"

# Variabili di stato
ARCHIVE_PATH=""
FORCE_TYPE=""     # "ide" oppure "chat"
IS_UPDATE=false
TEMP_EXTRACT=""
TEMP_ASAR_EXTRACT=""
DESKTOP_ICON=""

cleanup() {
    if [[ -n "${TEMP_EXTRACT:-}" && -d "${TEMP_EXTRACT:-}" ]]; then
        rm -rf "${TEMP_EXTRACT}" 2>/dev/null || true
    fi
    if [[ -n "${TEMP_ASAR_EXTRACT:-}" && -d "${TEMP_ASAR_EXTRACT:-}" ]]; then
        rm -rf "${TEMP_ASAR_EXTRACT}" 2>/dev/null || true
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
        DESKTOP_ICON="antigravity-ide"
    else
        APP_NAME="Antigravity 2.0"
        APP_ID="antigravity"
        TARGET_DIR="${APPS_DIR}/antigravity-chat"
        DESKTOP_FILE="${DESKTOP_DIR}/antigravity.desktop"
        BIN_NAME="antigravity"
        DESKTOP_ICON="antigravity"
    fi
}

# ------------------------------------------------------------------------------
# Controllo Processi in Esecuzione
# ------------------------------------------------------------------------------
check_running_instances() {
    local running_pids=()
    if [[ "$APP_TYPE" == "ide" ]]; then
        running_pids=($(pgrep -f "antigravity-ide" 2>/dev/null || true))
    else
        running_pids=($(pgrep -f "antigravity" 2>/dev/null || true))
    fi

    local filtered_pids=()
    for pid in "${running_pids[@]}"; do
        if [[ "$pid" != "$$" ]]; then
            filtered_pids+=("$pid")
        fi
    done

    if [[ ${#filtered_pids[@]} -gt 0 ]]; then
        log_warn "Rilevate ${#filtered_pids[@]} istanze/processi di ${APP_NAME} attivi."
        log_warn "L'aggiornamento avverrà in modalità in-place sicura per preservare i processi attivi."
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

    # Se è un aggiornamento e la cartella di destinazione esiste già, esegui copia di sicurezza
    local backup_dir=""
    if [[ -d "$TARGET_DIR" ]]; then
        backup_dir="${TARGET_DIR}_backup_$(date +%s)"
        log_info "Salvataggio copia di sicurezza versione precedente in: $(basename "$backup_dir")..."
        cp -a "$TARGET_DIR" "$backup_dir" 2>/dev/null || true
    fi

    # Spostamento nuovi file in-place (senza distruggere la cartella genitore)
    log_info "Posizionamento nuovi file in: ${TARGET_DIR}..."
    mkdir -p "$TARGET_DIR"
    cp -a --remove-destination "$source_dir"/. "$TARGET_DIR"/

    # Rimuovi copia di sicurezza temporanea
    if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
        rm -rf "$backup_dir" 2>/dev/null || true
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
# Estrazione archivio Electron .asar
# ------------------------------------------------------------------------------
extract_asar_archive() {
    local asar_file="$1"
    local dest_dir="$2"
    mkdir -p "$dest_dir"

    # 1. Prova binary 'asar' globale se disponibile
    if command -v asar >/dev/null 2>&1; then
        if asar extract "$asar_file" "$dest_dir" >/dev/null 2>&1; then
            return 0
        fi
    fi

    # 2. Fallback con script Python 3 integrato (zero dipendenze, 100% offline e istantaneo)
    if command -v python3 >/dev/null 2>&1; then
        if python3 - "$asar_file" "$dest_dir" << 'PYEOF' >/dev/null 2>&1
import sys, os, struct, json

asar_path = sys.argv[1]
dest = sys.argv[2]

try:
    with open(asar_path, 'rb') as f:
        header_raw = f.read(16)
        if len(header_raw) < 16:
            sys.exit(1)
        magic, total_len, json_wrapper, json_len = struct.unpack('<IIII', header_raw)
        if magic != 4:
            sys.exit(1)
        header_json = f.read(json_len).decode('utf-8', errors='ignore')
        header = json.loads(header_json)
        data_base = 8 + total_len

        def dump_node(node, cur_path):
            if 'files' in node:
                for name, child in node['files'].items():
                    dump_node(child, os.path.join(cur_path, name))
            elif 'offset' in node:
                lower = cur_path.lower()
                # Estrai solo file immagine per minimizzare tempo e risorse
                if lower.endswith(('.png', '.svg', '.ico')):
                    offset = int(node['offset'])
                    size = int(node['size'])
                    os.makedirs(os.path.dirname(cur_path), exist_ok=True)
                    f.seek(data_base + offset)
                    content = f.read(size)
                    with open(cur_path, 'wb') as out_f:
                        out_f.write(content)

        dump_node(header, dest)
        sys.exit(0)
except Exception:
    sys.exit(1)
PYEOF
        then
            return 0
        fi
    fi

    # 3. Fallback con Node.js puro integrato (senza librerie esterne, 100% offline)
    if command -v node >/dev/null 2>&1; then
        if node - "$asar_file" "$dest_dir" << 'NODEOF' >/dev/null 2>&1
const fs = require('fs');
const path = require('path');

const asarPath = process.argv[2];
const dest = process.argv[3];

try {
    const fd = fs.openSync(asarPath, 'r');
    const headerBuf = Buffer.alloc(16);
    fs.readSync(fd, headerBuf, 0, 16, 0);

    const magic = headerBuf.readUInt32LE(0);
    const totalLen = headerBuf.readUInt32LE(4);
    const jsonLen = headerBuf.readUInt32LE(12);

    if (magic !== 4) process.exit(1);

    const jsonBuf = Buffer.alloc(jsonLen);
    fs.readSync(fd, jsonBuf, 0, jsonLen, 16);
    const header = JSON.parse(jsonBuf.toString('utf8'));
    const dataBase = 8 + totalLen;

    function dumpNode(node, curPath) {
        if (node.files) {
            for (const [name, child] of Object.entries(node.files)) {
                dumpNode(child, path.join(curPath, name));
            }
        } else if (node.offset !== undefined) {
            const lower = curPath.toLowerCase();
            if (lower.endsWith('.png') || lower.endsWith('.svg') || lower.endsWith('.ico')) {
                const offset = parseInt(node.offset, 10);
                const size = parseInt(node.size, 10);
                fs.mkdirSync(path.dirname(curPath), { recursive: true });
                const buf = Buffer.alloc(size);
                fs.readSync(fd, buf, 0, size, dataBase + offset);
                fs.writeFileSync(curPath, buf);
            }
        }
    }

    dumpNode(header, dest);
    fs.closeSync(fd);
    process.exit(0);
} catch (e) {
    process.exit(1);
}
NODEOF
        then
            return 0
        fi
    fi

    return 1
}

# ------------------------------------------------------------------------------
# Ricerca dell'icona migliore all'interno di una cartella
# ------------------------------------------------------------------------------
find_icon_in_directory() {
    local search_dir="$1"

    if [[ "$APP_TYPE" == "ide" ]]; then
        for candidate in \
            "${search_dir}/resources/linux/code.png" \
            "${search_dir}/resources/app/resources/linux/code.png" \
            "${search_dir}/resources/linux/antigravity.png" \
            "${search_dir}/resources/linux/antigravity-ide.png" \
            "${search_dir}/out/media/code-icon.png" \
            "${search_dir}/assets/icon.png" \
            "${search_dir}/media/icon.png" \
            "${search_dir}/resources/icon.png" \
            "${search_dir}/antigravity-ide.png" \
            "${search_dir}/icon.png"; do
            if [[ -f "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi
        done
    else
        for candidate in \
            "${search_dir}/resources/icon.png" \
            "${search_dir}/assets/icon.png" \
            "${search_dir}/assets/icons/icon.png" \
            "${search_dir}/assets/icons/512x512.png" \
            "${search_dir}/static/icon.png" \
            "${search_dir}/antigravity.png" \
            "${search_dir}/antigravity-chat.png" \
            "${search_dir}/media/icon.png" \
            "${search_dir}/icon.png"; do
            if [[ -f "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi
        done
    fi

    # Ricerca con pattern mirati
    local candidates=()
    while IFS= read -r -d '' file; do
        candidates+=("$file")
    done < <(find "$search_dir" -type f \( -iname "*antigravity*.png" -o -iname "*icon*.png" -o -iname "*logo*.png" -o -iname "*code*.png" \) -print0 2>/dev/null)

    # Se ancora non trovata, cerca tutti i file PNG
    if [[ ${#candidates[@]} -eq 0 ]]; then
        while IFS= read -r -d '' file; do
            candidates+=("$file")
        done < <(find "$search_dir" -type f -iname "*.png" -print0 2>/dev/null)
    fi

    # Se trovati candidati, scegli il file con dimensione maggiore (qualità / risoluzione maggiore)
    if [[ ${#candidates[@]} -gt 0 ]]; then
        local best_file=""
        local max_size=0
        for f in "${candidates[@]}"; do
            local f_size
            f_size=$(wc -c < "$f" 2>/dev/null || echo 0)
            if (( f_size > max_size )); then
                max_size=$f_size
                best_file="$f"
            fi
        done
        if [[ -n "$best_file" && -f "$best_file" ]]; then
            echo "$best_file"
            return 0
        fi
    fi

    return 1
}

# ------------------------------------------------------------------------------
# Ricerca ed estrazione dell'icona dal pacchetto .asar
# ------------------------------------------------------------------------------
EXTRACTED_ASAR_ICON=""

extract_icon_from_asar() {
    EXTRACTED_ASAR_ICON=""
    log_info "Controllo ed estrazione del file .asar per ricavare l'icona..."
    local asar_files=()

    # Cerca file .asar noti con priorità
    if [[ -f "${TARGET_DIR}/resources/app.asar" ]]; then
        asar_files+=("${TARGET_DIR}/resources/app.asar")
    fi
    if [[ -f "${TARGET_DIR}/app.asar" ]]; then
        asar_files+=("${TARGET_DIR}/app.asar")
    fi
    if [[ -f "${TARGET_DIR}/resources/default_app.asar" ]]; then
        asar_files+=("${TARGET_DIR}/resources/default_app.asar")
    fi

    # Cerca altri .asar se non trovati quelli standard
    while IFS= read -r -d '' f; do
        local already=false
        for existing in "${asar_files[@]}"; do
            if [[ "$existing" == "$f" ]]; then
                already=true
                break
            fi
        done
        if [[ "$already" == false ]]; then
            asar_files+=("$f")
        fi
    done < <(find "$TARGET_DIR" -maxdepth 3 -type f -name "*.asar" -print0 2>/dev/null)

    if [[ ${#asar_files[@]} -eq 0 ]]; then
        log_info "Nessun file .asar rilevato in ${TARGET_DIR}."
        return 1
    fi

    for asar_file in "${asar_files[@]}"; do
        log_info "Estrazione archivio ASAR: $(basename "$asar_file")..."
        TEMP_ASAR_EXTRACT=$(mktemp -d "/tmp/antigravity_asar_XXXXXX")

        if extract_asar_archive "$asar_file" "$TEMP_ASAR_EXTRACT"; then
            local extracted_icon
            extracted_icon=$(find_icon_in_directory "$TEMP_ASAR_EXTRACT" || true)
            if [[ -n "$extracted_icon" && -f "$extracted_icon" ]]; then
                log_success "Icona individuata con successo nel file .asar: $(basename "$extracted_icon")"
                local saved_icon="/tmp/antigravity_extracted_icon_${APP_ID}_$$.png"
                cp -f "$extracted_icon" "$saved_icon"
                rm -rf "$TEMP_ASAR_EXTRACT" 2>/dev/null || true
                TEMP_ASAR_EXTRACT=""
                EXTRACTED_ASAR_ICON="$saved_icon"
                return 0
            fi
        fi

        rm -rf "$TEMP_ASAR_EXTRACT" 2>/dev/null || true
        TEMP_ASAR_EXTRACT=""
    done

    log_warn "Nessuna icona valida reperita all'interno dei file .asar analizzati."
    return 1
}

# ------------------------------------------------------------------------------
# Installazione Icone di Sistema
# ------------------------------------------------------------------------------
install_icons() {
    log_info "Configurazione icone di sistema..."
    local src_icon=""

    # 1. Prova prima a estrarre e ricavare l'icona dal file .asar
    if extract_icon_from_asar && [[ -n "$EXTRACTED_ASAR_ICON" && -f "$EXTRACTED_ASAR_ICON" ]]; then
        src_icon="$EXTRACTED_ASAR_ICON"
        log_success "Icona ricavata dal file .asar impostata come sorgente principale."
    fi

    # 2. Se non trovata nell'asar, cerca nei file dell'applicazione
    if [[ -z "$src_icon" ]]; then
        src_icon=$(find_icon_in_directory "$TARGET_DIR" || true)
    fi

    # Setup nomi icone per tema
    if [[ "$APP_TYPE" == "ide" ]]; then
        local icon_names=("antigravity-ide")
    else
        local icon_names=("antigravity" "antigravity-chat")
    fi

    if [[ -n "$src_icon" && -f "$src_icon" ]]; then
        # Salva copia icona principale nella cartella applicazione
        cp -f "$src_icon" "${TARGET_DIR}/${APP_ID}.png"
        cp -f "$src_icon" "${TARGET_DIR}/icon.png"
        if [[ "$APP_TYPE" == "chat" ]]; then
            cp -f "$src_icon" "${TARGET_DIR}/antigravity-chat.png"
        fi

        # Definisce l'icona da usare nella entry .desktop (percorso assoluto garantito)
        DESKTOP_ICON="${TARGET_DIR}/${APP_ID}.png"

        # Installa in ~/.local/share/pixmaps per supporto desktop universale
        mkdir -p "${PIXMAPS_DIR}"
        for iname in "${icon_names[@]}"; do
            cp -f "$src_icon" "${PIXMAPS_DIR}/${iname}.png"
        done

        # Installa nei percorsi standard hicolor
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

        # Pulizia eventuale icona temporanea
        if [[ "$src_icon" == /tmp/* ]]; then
            rm -f "$src_icon" 2>/dev/null || true
        fi

        log_success "Icone installate in ~/.local/share/icons/hicolor/ e ~/.local/share/pixmaps/"
    else
        DESKTOP_ICON="${APP_ID}"
        log_warn "Nessuna icona PNG trovata nell'archivio o nel file .asar. Verranno usate le icone di fallback del tema."
    fi
}

# ------------------------------------------------------------------------------
# Creazione File Desktop (.desktop)
# ------------------------------------------------------------------------------
install_desktop_entry() {
    log_info "Creazione scorciatoia desktop: $(basename "$DESKTOP_FILE")..."

    local icon_entry="${DESKTOP_ICON:-$APP_ID}"
    local tmp_desktop="${DESKTOP_FILE}.tmp.$$"

    if [[ "$APP_TYPE" == "ide" ]]; then
        cat > "$tmp_desktop" << EOF
[Desktop Entry]
Name=Antigravity IDE
Comment=AI-Powered Integrated Development Environment
GenericName=Integrated Development Environment
Exec=${TARGET_DIR}/antigravity-ide --no-sandbox %F
Icon=${icon_entry}
Type=Application
StartupNotify=true
StartupWMClass=antigravity-ide
Categories=Development;IDE;
MimeType=text/plain;inode/directory;x-scheme-handler/antigravity-ide;
Keywords=vscode;code;development;ide;antigravity;ai;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Name[it]=Nuova finestra vuota
Exec=${TARGET_DIR}/antigravity-ide --no-sandbox --new-window %F
Icon=${icon_entry}
EOF
    else
        cat > "$tmp_desktop" << EOF
[Desktop Entry]
Name=Antigravity 2.0
Comment=Antigravity AI Assistant & Agent Workspace
GenericName=AI Assistant
Exec=${TARGET_DIR}/antigravity --no-sandbox %U
Icon=${icon_entry}
Type=Application
StartupNotify=true
StartupWMClass=antigravity
Categories=Utility;Development;
MimeType=x-scheme-handler/antigravity;text/html;
Keywords=antigravity;chat;ai;assistant;agent;gemini;
Actions=new-window;

[Desktop Action new-window]
Name=New Window
Name[it]=Nuova finestra
Exec=${TARGET_DIR}/antigravity --no-sandbox
Icon=${icon_entry}
EOF
    fi

    chmod 644 "$tmp_desktop"

    # Validazione prima dell'attivazione per evitare crash nei compositori desktop
    if command -v desktop-file-validate >/dev/null 2>&1; then
        if ! desktop-file-validate "$tmp_desktop" >/dev/null 2>&1; then
            log_warn "Rilevati warning nella validazione della scorciatoia desktop."
        fi
    fi

    # Spostamento atomico (rename syscall) per evitare race condition con inotify di GNOME/KDE
    mv -f "$tmp_desktop" "$DESKTOP_FILE"
    log_success "Launcher desktop aggiornato con icona: ${icon_entry}"
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
        local tmp_wrapper="${wrapper_script}.tmp.$$"
        cat > "$tmp_wrapper" << EOF
#!/usr/bin/env bash
exec "${TARGET_DIR}/antigravity" --no-sandbox "\$@"
EOF
        chmod +x "$tmp_wrapper"
        mv -f "$tmp_wrapper" "$wrapper_script"

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
        update-desktop-database -q "${DESKTOP_DIR}" 2>/dev/null || true
    fi
    # Esegui gtk-update-icon-cache in modo sicuro solo se la directory del tema è integra
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        if [[ -f "${ICONS_BASE_DIR}/index.theme" ]]; then
            gtk-update-icon-cache -q "${ICONS_BASE_DIR}" 2>/dev/null || true
        fi
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

    check_running_instances
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
