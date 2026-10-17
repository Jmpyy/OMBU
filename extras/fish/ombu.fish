# Para tu ~/.config/fish/config.fish: prompt starship, búsqueda difusa con fzf, atuin, zoxide y los colores de ombu.
# Los programas se activan solo si están instalados.

# Prompt de ombu (starship): solo si está instalado
type -q starship; and starship init fish | source

# Búsqueda difusa (fzf) con los colores de ombu: Ctrl+R historial, Ctrl+T archivos, Alt+C carpetas
if type -q fzf
    set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --border=rounded --color=bg:#14131a,bg+:#1d1c26,fg:#e8e8f0,fg+:#e8e8f0,hl:#a78bfa,hl+:#c4b5fd,info:#8a8a9c,prompt:#a78bfa,pointer:#a78bfa,marker:#86efac,spinner:#a78bfa,header:#8a8a9c,border:#2b2a38"
    if type -q fd
        set -gx FZF_CTRL_T_COMMAND "fd --type f --hidden --exclude .git"
        set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --exclude .git"
    end
    fzf --fish | source
end

# atuin: Ctrl+R abre el historial con contexto (carpeta, si salió bien, cuándo); la flecha arriba queda
# como en fish. Va después de fzf para que Ctrl+R sea de atuin (fzf conserva Ctrl+T y Alt+C).
type -q atuin; and atuin init fish --disable-up-arrow | source

# zoxide: "z carpeta" te lleva a la que más usás (solo si está instalado)
type -q zoxide; and zoxide init fish | source

# Colores de ombu para fish: resaltado mientras escribís, la sugerencia en gris y la lista de Tab
set -g fish_color_normal e8e8f0
set -g fish_color_command c4b5fd --bold
set -g fish_color_keyword 60a5fa
set -g fish_color_param e8e8f0
set -g fish_color_option 5eead4
set -g fish_color_quote 86efac
set -g fish_color_redirection fbbf24
set -g fish_color_end fbbf24
set -g fish_color_operator 5eead4
set -g fish_color_escape 5eead4
set -g fish_color_error f87171
set -g fish_color_comment 8a8a9c
set -g fish_color_autosuggestion 5a5970
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=3a3950
set -g fish_color_search_match --background=3a3950
set -g fish_pager_color_prefix a78bfa --bold
set -g fish_pager_color_completion e8e8f0
set -g fish_pager_color_description 8a8a9c
set -g fish_pager_color_progress 8a8a9c --background=1d1c26
set -g fish_pager_color_selected_background --background=3a3950
