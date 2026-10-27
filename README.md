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

## Instalar com o Claude Code

Abra o Claude (aba Code) numa pasta qualquer do seu Mac e cole:

```
Quero instalar o Transcritor, o ditado por voz 100% local do Grupo Vórtex, no meu Mac.

1. Confira se este Mac tem chip Apple Silicon (M1, M2, M3...). Se não tiver, me avise que vai funcionar mais devagar e pergunte se eu quero seguir.
2. Confira se eu tenho o Git. Se não tiver, instale comigo.
3. Baixe o código: git clone https://github.com/matheustillimt-tech/transcritor.git e entre na pasta transcritor.
4. Leia o README.md e o INSTALACAO.md.
5. Rode o ./install.sh no meu terminal. Ele instala as ferramentas da Apple, o Homebrew, o whisper-cpp e baixa o modelo (cerca de 1,6 GB). Me avise antes do download grande e do que pedir a senha do Mac (a senha eu digito no terminal, nunca aqui no chat).
6. Quando o app abrir, me guie pra liberar as 2 permissões: Microfone e Acessibilidade (Ajustes do Sistema › Privacidade e Segurança › Acessibilidade › Transcritor).
7. Me ajude a deixar a tecla 🌐 (fn) como "Não fazer nada" em Ajustes do Sistema › Teclado.
8. Faça um teste comigo: eu seguro o fn, falo uma frase e confiro se o texto apareceu onde está o cursor.

Regras: fale comigo em português simples (sou dono de negócio, não programador), um passo de cada vez, esperando eu terminar antes de seguir.
```

O passo a passo manual está no [INSTALACAO.md](INSTALACAO.md).

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

## Licença

MIT. Feito pelo Grupo Vórtex · entregue na Plataforma Vórtex IA.
