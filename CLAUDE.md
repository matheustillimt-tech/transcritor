# CLAUDE.md · Transcritor

App de Mac (Swift, sem Xcode: compila com `swiftc` via `build.sh`) que grava a fala, transcreve 100% local com o
`whisper-server` do `whisper-cpp` (modelo large-v3-turbo em `~/.cache/whisper-models/`) e cola o texto onde está o
cursor.

| Arquivo | O que é |
|---|---|
| `Sources/Transcritor/main.swift` | Início do app |
| `AppController.swift` | Liga tudo: atalho, gravação, transcrição, colagem e menu |
| `HotkeyMonitor.swift` | Tecla de atalho (fn, Option direita ou Command direita), segurar e toque duplo |
| `AudioRecorder.swift` | Grava o microfone e mede o volume (o widget pulsa com a voz) |
| `WhisperEngine.swift` | Sobe e conversa com o `whisper-server` local |
| `TextInserter.swift` | Cola o texto no app em foco (precisa de Acessibilidade) |
| `WidgetPanel.swift` / `ToastPanel.swift` | O botão flutuante e os avisos |

- Instalar do zero: `./install.sh`. Só recompilar: `./build.sh`.
- Toda recompilação pode exigir liberar de novo a Acessibilidade (o app é assinado localmente).
- Nada sai do computador: não acrescente envio de áudio ou texto pra serviço externo sem deixar isso explícito pro usuário.
