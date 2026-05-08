import Foundation

struct Cleaner {
    static var totalGeral: Int64 = 0
    static var contadorItens = 0
    static var itensParaLimpar: [String] = []

    // Pastas de usuário
    static var pastasUsuario: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/CoreSimulator/Caches",
            "\(home)/Library/Caches/com.apple.dt.Xcode",
            "\(home)/Library/Caches/org.swift.swiftpm",
            "\(home)/Library/Caches/com.google.Chrome",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Caches/com.spotify.client",
            "\(home)/Library/Caches",
            "\(home)/Library/Logs",
            "\(home)/.Trash"
        ]
    }

    static let pastasProtegidas = [
        "/Library/Caches",
        "/private/var/log",
        "/private/var/folders",
        "/private/tmp"
    ]

    // Validação de privilégios logo no início
    static func validarSudo() {
        print("🔐 Este script precisa de acesso de administrador.")

        let path = "/usr/bin/sudo"
        let args = ["sudo", "-v"]

        // Converte os argumentos para o formato que o C entende
        let cArgs = args.map { strdup($0) } + [nil]
        let env = Array(ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" })
        let cEnv = env.map { strdup($0) } + [nil]

        var pid: pid_t = 0

        // posix_spawn executa o processo herdando o terminal (TTY) atual
        let status = posix_spawn(&pid, path, nil, nil, cArgs, cEnv)

        if status == 0 {
            var exitStatus: Int32 = 0
            waitpid(pid, &exitStatus, 0)

            if exitStatus != 0 {
                print("\n❌ Erro: Permissão negada ou cancelada.")
                exit(1)
            }
        } else {
            print("❌ Erro ao spawnar o processo sudo.")
            exit(1)
        }

        // Limpeza de memória dos ponteiros C
        cArgs.compactMap { $0 }.forEach { free($0) }
        cEnv.compactMap { $0 }.forEach { free($0) }

        print("✅ Autenticado.\n")
    }


    static func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func mapearTudo() {
        let fm = FileManager.default
        totalGeral = 0
        contadorItens = 0
        itensParaLimpar = []

        for raiz in pastasUsuario {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: raiz, isDirectory: &isDir), isDir.boolValue else { continue }

            print("🔍 Analisando: \(raiz)")

            let enumerator = fm.enumerator(atPath: raiz)
            while let itemRelativo = enumerator?.nextObject() as? String {
                let caminhoCompleto = (raiz as NSString).appendingPathComponent(itemRelativo)

                do {
                    let attrs = try fm.attributesOfItem(atPath: caminhoCompleto)
                    if let tamanho = attrs[.size] as? Int64 {
                        totalGeral += tamanho
                        contadorItens += 1
                        itensParaLimpar.append(caminhoCompleto)
                    }
                } catch { continue }
            }
        }

        print("\n📂 Calculando pastas de sistema...")
        for caminho in pastasProtegidas {
            // Usa sudo internamente para calcular o tamanho
            let output = shell("sudo du -sk \"\(caminho)\" 2>/dev/null | awk '{print $1}'").trimmingCharacters(in: .whitespacesAndNewlines)
            if let kb = Int64(output) {
                totalGeral += (kb * 1024)
                print("> \(caminho) [SISTEMA] -> \(String(format: "%.2f", Double(kb)/1024.0)) MB")
            }
        }

        let totalMB = Double(totalGeral) / (1024.0 * 1024.0)
        print(String(format: "\n📦 TOTAL GERAL MAPEADO: %.2f MB", totalMB))
        print(String(repeating: "-", count: 50))
    }

    static func executarLimpeza() {
        guard totalGeral > 0 else { return print("Nada para limpar.") }

        print("\n⚠️ Deseja apagar os \(contadorItens) itens mapeados? (s/n)")
        print("> ", terminator: "") // Mantém o cursor na mesma linha

        if let input = readLine()?.lowercased(), input == "s" {
            print("🚀 Iniciando faxina...")

            for item in itensParaLimpar.reversed() {
                _ = shell("rm -rf '\(item)'")
            }

            print("⚙️ Limpando caches globais e logs...")
            _ = shell("sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder")
            _ = shell("sudo periodic daily weekly monthly")

            for p in pastasProtegidas {
                _ = shell("sudo rm -rf \(p)/* 2>/dev/null")
            }

            let som = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif"
            _ = shell("afplay -v 2 -t 2 '\(som)'")

            print("🔄 Reiniciando o Finder...")
            _ = shell("killall Finder")
            print("✅ Seu Mac está limpo!")
        } else {
            print("❌ Operação cancelada.")
        }
    }
}

// Fluxo de Execução
Cleaner.validarSudo()
Cleaner.mapearTudo()
Cleaner.executarLimpeza()
