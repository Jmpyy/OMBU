# Para tu ~/.config/fish/config.fish: prompt starship, búsqueda difusa con fzf y zoxide.
# Cada bloque solo se activa si el programa está instalado.

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

# zoxide: "z carpeta" te lleva a la que más usás (solo si está instalado)
type -q zoxide; and zoxide init fish | source
