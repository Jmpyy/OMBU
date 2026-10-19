#!/bin/sh
# Crea un proyecto de C listo para estudiar: CMake con avisos estrictos, Makefile con atajos
# (run, leaks con valgrind, asan, debug con gdb) y compile_commands.json para clangd.
# Uso: cproj.sh nombre [carpeta]   (por defecto en ~/universidad)
set -eu

name=${1:?uso: cproj.sh nombre [carpeta]}
base=${2:-$HOME/universidad}
dir=$base/$name

case $name in
*[!A-Za-z0-9_-]* | "")
    echo "el nombre solo puede tener letras, números, - y _" >&2
    exit 1
    ;;
esac
if [ -e "$dir" ]; then
    echo "ya existe $dir" >&2
    exit 1
fi

mkdir -p "$dir"
cd "$dir"

cat > main.c <<'C'
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    int *numeros = malloc(5 * sizeof *numeros);
    if (numeros == NULL)
        return EXIT_FAILURE;

    for (int i = 0; i < 5; i++)
        numeros[i] = i * i;

    for (int i = 0; i < 5; i++)
        printf("%d\n", numeros[i]);

    free(numeros);
    return EXIT_SUCCESS;
}
C

cat > CMakeLists.txt <<CMAKE
cmake_minimum_required(VERSION 3.20)
project($name C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif()

option(SANITIZE "Compilar con AddressSanitizer y UBSan" OFF)

add_executable(app main.c)
target_compile_options(app PRIVATE -Wall -Wextra -Wpedantic -Wshadow -Wconversion)
if(SANITIZE)
  target_compile_options(app PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer)
  target_link_options(app PRIVATE -fsanitize=address,undefined)
endif()
CMAKE

cat > Makefile <<'MAKE'
.PHONY: all run leaks asan debug clean

all:
	cmake -S . -B build
	cmake --build build
	ln -sf build/compile_commands.json compile_commands.json

run: all
	./build/app

# Fugas y accesos inválidos a la memoria (valgrind)
leaks: all
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./build/app

# Lo mismo con los sanitizers de gcc: más rápido que valgrind
asan:
	cmake -S . -B build-asan -DSANITIZE=ON
	cmake --build build-asan
	./build-asan/app

debug: all
	gdb --quiet ./build/app

clean:
	rm -rf build build-asan compile_commands.json
MAKE

printf 'build/\nbuild-asan/\ncompile_commands.json\n' > .gitignore
echo "Proyecto creado en $dir"
echo "  make run     compila y ejecuta"
echo "  make leaks   valgrind"
echo "  make asan    sanitizers"
echo "  make debug   gdb"
