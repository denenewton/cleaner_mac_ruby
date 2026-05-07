#!/usr/bin/env ruby
require_relative 'cleaner'

# 1. Mapeia e mostra o resumo por pastas
Cleaner.mapear_tudo

# 2. Pergunta e executa a limpeza
Cleaner.executar_limpeza!
