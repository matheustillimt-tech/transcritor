# Transcritor 🎙️

Widget flutuante para macOS que transforma sua fala em texto e cola onde estiver o cursor, em qualquer app.
Roda 100% local (Whisper large-v3-turbo via `whisper-cpp`), sem internet e sem custo.

## Como usar

### Pelo teclado (o jeito mais rápido)

| Ação | O que faz |
|---|---|
| **Segurar fn (🌐)** e falar | Grava enquanto você segura. Soltou, transcreve e cola onde está o cursor |
| **Dois toques rápidos no fn** | Modo mãos livres: grava sem segurar. Toque no fn de novo para terminar |
| **Esc** | Cancela a gravação |

A tecla pode ser trocada no menu (botão direito no widget) para **Option direita** ou **Command direita**.
Se usar o fn, vá em Ajustes do Sistema › Teclado e deixe **“Pressionar a tecla 🌐”** como **“Não fazer nada”**, senão ele abre os emojis.

### Pelo widget

| Ação | O que faz |
|---|---|
| **Clique** no botão | Começa a gravar (fica vermelho e pulsa com sua voz) |
| **Clique de novo** | Para, transcreve (fica azul) e cola o texto onde está o cursor |
| **Arrastar** | Move o widget para qualquer lugar ou monitor (a posição fica salva) |
| **Botão direito** | Menu: cancelar, copiar última transcrição, vocabulário, sair |

Clicar no widget **não tira o foco** do app onde você está digitando.

## Instalar / compilar

Num Mac novo, um comando instala tudo (Command Line Tools, Homebrew, `whisper-cpp` e o modelo de ~1,6 GB em `~/.cache/whisper-models/`), compila e abre o app:

```bash
./install.sh
```

Se as dependências já estiverem instaladas, `./build.sh` só recompila. O script compila, instala em `/Applications/Transcritor.app` e abre o app. Ele já fica configurado para abrir junto com o Mac (dá pra desligar no menu).

Na primeira vez, o macOS vai pedir:
1. **Microfone**: permitir.
2. **Acessibilidade** (Ajustes do Sistema › Privacidade e Segurança › Acessibilidade): ative o *Transcritor*. É o que permite usar a tecla de atalho e colar o texto automaticamente. Sem isso, o texto fica só copiado (cole com ⌘V).

> Toda vez que você recompilar, o macOS pode pedir a permissão de Acessibilidade de novo (o app é assinado localmente). Se não colar, remova o Transcritor da lista e adicione de novo.

## Dicas de precisão

- **Vocabulário** (botão direito): cadastre nomes próprios, marcas e termos seus (ex.: `uai, trem, Uberlândia, pão de queijo, Kubernetes`). Isso ajuda muito o Whisper.
- Fale a uns 15–30 cm do microfone. Fala rápida e "palavras comidas" funcionam bem, porque o modelo usa beam search.
- Log do motor: `~/Library/Logs/Transcritor/whisper-server.log`.
