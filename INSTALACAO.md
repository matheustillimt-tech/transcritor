# Instalação do Transcritor (passo a passo manual)

O Transcritor roda **só no seu Mac**, sem internet e sem custo: a fala vira texto com o Whisper
(large-v3-turbo) rodando no próprio computador. Nada é enviado pra fora.

## Do que você precisa

- Um Mac com macOS 13 ou mais novo. Funciona melhor em Apple Silicon (M1, M2, M3...).
- Uns 2 GB livres (o modelo do Whisper tem cerca de 1,6 GB).
- A senha do Mac (o Homebrew pede na primeira vez).

## Instalar

1. Abra o **Terminal**.
2. Baixe o código e entre na pasta:
   ```bash
   git clone https://github.com/matheustillimt-tech/transcritor.git
   cd transcritor
   ```
3. Rode o instalador. Ele instala o que faltar (Command Line Tools da Apple, Homebrew, `whisper-cpp`), baixa o
   modelo, compila e abre o app em `/Applications/Transcritor.app`:
   ```bash
   ./install.sh
   ```
4. Libere as 2 permissões quando o macOS pedir:
   - **Microfone:** Permitir.
   - **Acessibilidade:** Ajustes do Sistema › Privacidade e Segurança › Acessibilidade › ative o **Transcritor**.
     É o que deixa o atalho funcionar e colar o texto sozinho.
5. Se for usar a tecla **🌐 (fn)**: Ajustes do Sistema › Teclado › "Pressionar a tecla 🌐" › **Não fazer nada**.

## Testar

Clique num campo de texto qualquer (Notas, WhatsApp Web, e-mail), **segure o fn**, fale uma frase e solte.
Em 1 ou 2 segundos o texto aparece onde está o cursor.

## Problemas comuns

| O que acontece | O que fazer |
|---|---|
| O texto não cola sozinho | Falta a permissão de Acessibilidade. Se já estava ativa e você recompilou, remova o Transcritor da lista e adicione de novo |
| Apertar fn abre os emojis | Ajustes do Sistema › Teclado › "Pressionar a tecla 🌐" › Não fazer nada |
| Não transcreve nada | Veja o log em `~/Library/Logs/Transcritor/whisper-server.log` e confira se o modelo está em `~/.cache/whisper-models/` |
| Erra nome próprio | Botão direito no widget › Vocabulário: cadastre nomes, marcas e termos seus |

## Atualizar

Dentro da pasta `transcritor`: `git pull` e depois `./build.sh`.
