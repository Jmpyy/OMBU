# Para tu ~/.config/fish/config.fish: prompt starship, búsqueda difusa con fzf, atuin, zoxide y los colores de ombu.
# Los programas se activan solo si están instalados.

# Prompt de ombu (starship): solo si está instalado
type -q starship; and starship init fish | source

# Búsqueda difusa (fzf) con los colores de ombu: Ctrl+R historial, Ctrl+T archivos, Alt+C carpetas
if type -q fzf
    set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --border=rounded --color=bg:#161011,bg+:#211819,fg:#efe8dc,fg+:#fff4e8,hl:#e23b32,hl+:#ff7a8a,info:#a89c90,prompt:#e23b32,pointer:#5fb0ae,marker:#86efac,spinner:#e23b32,header:#a89c90,border:#35282a"
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

# Colores de ombu para fish (Spider-Man cómic: rojo #e23b32, crema #efe8dc, teal #5fb0ae)
set -g fish_color_normal efe8dc
set -g fish_color_command e23b32 --bold
set -g fish_color_keyword 5fb0ae --bold
set -g fish_color_param efe8dc
set -g fish_color_option 5fb0ae
set -g fish_color_quote 86efac
set -g fish_color_redirection f2b84b
set -g fish_color_end f2b84b
set -g fish_color_operator 5fb0ae
set -g fish_color_escape 5fb0ae
set -g fish_color_error ff7a8a
set -g fish_color_comment a89c90
set -g fish_color_autosuggestion 5e5251
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=35282a
set -g fish_color_search_match --background=35282a
set -g fish_pager_color_prefix e23b32 --bold
set -g fish_pager_color_completion efe8dc
set -g fish_pager_color_description a89c90
set -g fish_pager_color_progress a89c90 --background=211819
set -g fish_pager_color_selected_background --background=35282a

# Aliases modernos (eza, bat)
if type -q eza
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -la --icons --octal-permissions --group-directories-first --git"
    alias tree="eza --tree --icons --level=3"
end

if type -q bat
    alias cat="bat --paging=never"
end

# Desarrollo en C / C++ y Bajo Nivel (UPE / Ciberseguridad)
alias cflags="echo '-Wall -Wextra -Werror -pedantic -std=c11 -g'"
alias cxxflags="echo '-Wall -Wextra -Werror -pedantic -std=c++20 -g'"
alias valgrind-check="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes"
alias memcheck="valgrind --tool=memcheck --leak-check=full"
alias disasm="objdump -d -M intel"
alias ports="ss -tulnp"
alias myip="curl -s ifconfig.me"

# Git rápido
alias gst="git status -sb"
alias glog="git log --oneline --graph --decorate"
alias gd="git diff"
