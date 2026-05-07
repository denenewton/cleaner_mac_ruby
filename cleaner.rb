require 'find'
require 'fileutils'

module Cleaner
  @total_geral = 0
  @contador_itens = 0
  @itens_para_limpar = []

  # Pastas de usuário que podem ser limpas com segurança (Arquivos temporários e Caches)
  def self.pastas_usuario
    [
      # --- DESENVOLVIMENTO (Xcode, Swift, Simuladores) ---
      File.expand_path("~/Library/Developer/Xcode/DerivedData"),
      File.expand_path("~/Library/Developer/Xcode/iOS DeviceSupport"),
      File.expand_path("~/Library/Developer/Xcode/Archives"),
      File.expand_path("~/Library/Developer/CoreSimulator/Caches"),
      File.expand_path("~/Library/Caches/com.apple.dt.Xcode"),
      File.expand_path("~/Library/Caches/org.swift.swiftpm"),

      # --- NAVEGADORES E APPS COMUNS ---
      File.expand_path("~/Library/Caches/com.google.Chrome"),
      File.expand_path("~/Library/Caches/Firefox"),
      File.expand_path("~/Library/Caches/com.spotify.client"),

      # --- SISTEMA DO USUÁRIO ---
      File.expand_path("~/Library/Caches"),
      File.expand_path("~/Library/Logs"),
      File.expand_path("~/.Trash")
    ]
  end

  # Pastas globais que exigem permissão de administrador (Sudo)
  def self.pastas_protegidas
    [
      "/Library/Caches",
      "/private/var/log",
      "/private/var/folders", # Arquivos temporários de processos do sistema
      "/private/tmp"          # Arquivos temporários gerais
    ]
  end

  def self.mapear_tudo
    @total_geral = 0
    @contador_itens = 0
    @itens_para_limpar = []

    pastas_usuario.each do |raiz|
      next unless Dir.exist?(raiz)
      puts "\n🔍 Analisando: #{raiz}"

      Find.find(raiz) do |caminho|
        if File.directory?(caminho)
          tamanho_pasta = 0
          contagem_arquivos = 0

          begin
            Dir.children(caminho).each do |filho|
              item_completo = File.join(caminho, filho)
              if File.file?(item_completo)
                tamanho = File.size(item_completo)
                tamanho_pasta += tamanho
                contagem_arquivos += 1
                @total_geral += tamanho
                @contador_itens += 1
                @itens_para_limpar << item_completo
              elsif File.directory?(item_completo)
                @itens_para_limpar << item_completo
              end
            end
          rescue Errno::EACCES, Errno::ENOENT
            next
          end

          if tamanho_pasta > 0
            nivel = caminho.count('/') - raiz.count('/')
            espacos = "  " * nivel
            nome = (caminho == raiz) ? "RAIZ" : File.basename(caminho)
            puts "#{espacos}📂 #{nome} [#{contagem_arquivos} arquivos] -> #{(tamanho_pasta / 1024.0).round(2)} KB"
          end
        end
      end
    end

    puts "\n🔐 Acessando pastas de sistema..."
    if system("sudo -v")
      pastas_protegidas.each do |caminho|
        next unless Dir.exist?(caminho)
        # du -sk calcula o tamanho de forma segura para pastas protegidas
        tamanho_kb = `sudo du -sk "#{caminho}" 2>/dev/null | awk '{print $1}'`.to_i
        @total_geral += (tamanho_kb * 1024)
        puts "> #{caminho} [SISTEMA] -> #{(tamanho_kb / 1024.0).round(2)} MB"
      end
    end

    total_mb = (@total_geral / (1024.0 * 1024.0)).round(2)
    puts "\n📦 TOTAL GERAL MAPEADO: #{total_mb} MB"
    puts "-" * 50
  end

  def self.executar_limpeza!
    return puts "Nada para limpar." if @total_geral == 0

    puts "\n⚠️  Deseja apagar os #{@contador_itens} arquivos mapeados? (s/n)"
    print "> "
    if gets.chomp.downcase == 's'
      puts "🚀 Iniciando faxina pesada..."

      # Deleta itens de usuário
      @itens_para_limpar.reverse_each do |item|
        system("rm -rf '#{item}'") if File.exist?(item)
      end

      # Manutenção de Sistema
      puts "⚙️  Limpando caches globais e logs..."
      system("sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder")
      system("sudo periodic daily weekly monthly")
      pastas_protegidas.each do |p|
        system("sudo rm -rf #{p}/* 2>/dev/null")
      end

      # Som de sucesso
      system("afplay /System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag\ to\ trash.aif")
      # 2. Reinicia o Finder para atualizar o sistema
      puts "🔄 Reiniciando o Finder..."
      system("killall Finder")
      puts "✅ Seu Mac está limpo!"
    else
      puts "❌ Operação cancelada."
    end
  end
end
