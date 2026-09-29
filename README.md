# Contador

Uma gota de vidro líquido presa na borda da tela do seu Mac, contando o tempo até a sua meta.
Passe o mouse e ela se estica mostrando dias, horas, progresso e semanas. Tire o mouse e ela volta pra borda.

*A liquid glass drop stuck to the edge of your Mac screen, counting down to your goal. Hover to expand.*

## Instalar

Cole no Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/AdrianoBinhara/contador/main/install.sh | sh
```

Pronto. A gota nasce no centro da tela e escorre até a borda.

Prefere baixar? Pegue o `Contador.zip` em [Releases](https://github.com/AdrianoBinhara/contador/releases/latest), descompacte e arraste pra Aplicativos. Se o macOS bloquear na primeira vez: Ajustes do Sistema, Privacidade e Segurança, "Abrir Mesmo Assim".

**Requisitos:** macOS 14 ou mais novo, Apple Silicon ou Intel. O efeito de vidro líquido aparece no macOS 26; nas versões anteriores a gota usa vidro fosco.

## Usar

- **Ajustes:** clique no card aberto, no ícone de gota na barra de menus ou abra o app de novo pelo Spotlight.
- **Contagem:** nome, início e fim. Reinicie quando quiser ou trave pra evitar clique acidental.
- **Aparência:** 5 cores, lado da tela (direita ou esquerda) e altura na borda.
- **Abrir ao iniciar o Mac:** um botão nos ajustes.
- **Sair:** ícone de gota na barra de menus, "Sair do Contador".

## Compilar

Um único arquivo Swift, sem dependências.

```sh
swift icon.swift   # gera Icon.icns (já incluso)
./build.sh         # compila universal e assina
```

O `build.sh` assina com o Developer ID do autor. Pra compilar na sua máquina, troque a identidade no `codesign` por `-` (assinatura local).

## Licença

MIT
