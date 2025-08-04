#!/usr/bin/env fish

# Script para processar favoritos do Firefox e converter para tabela markdown
# Uso: ./processar_favoritos.fish

set arquivo_entrada "/home/wilsonseabra/Downloads/favoritos_04_08_2025.html"
set arquivo_saida "favoritos_tabela.md"

echo "Processando arquivo HTML de favoritos..."

# Verificar se o arquivo existe
if not test -f $arquivo_entrada
    echo "Erro: Arquivo $arquivo_entrada não encontrado!"
    exit 1
end

# Criar cabeçalho do arquivo markdown
echo "# Favoritos do Firefox" > $arquivo_saida
echo "" >> $arquivo_saida
echo "| Título | URL | Data de Adição |" >> $arquivo_saida
echo "|--------|-----|----------------|" >> $arquivo_saida

# Contador de favoritos
set contador 0

# Processar o arquivo HTML linha por linha
while read -l linha
    # Procurar por tags <A> com href
    if string match -q "*<A HREF=*" $linha
        # Extrair URL (entre aspas após HREF=)
        set url (echo $linha | sed 's/.*HREF="\([^"]*\)".*/\1/')
        
        # Extrair título (entre > e <)
        set titulo (echo $linha | sed 's/.*>\([^<]*\)<.*/\1/')
        
        # Extrair data de adição (ADD_DATE="...")
        set data_raw (echo $linha | sed 's/.*ADD_DATE="\([^"]*\)".*/\1/')
        
        # Converter timestamp para data legível se for um número
        if test -n "$data_raw" && string match -q "^*[0-9]*$" "$data_raw"
            set data (date -d @$data_raw +"%d/%m/%Y %H:%M" 2>/dev/null || echo $data_raw)
        else
            set data $data_raw
        end
        
        # Escapar caracteres especiais para markdown
        set titulo_escaped (echo $titulo | sed 's/|/\\|/g')
        set url_escaped (echo $url | sed 's/|/\\|/g')
        set data_escaped (echo $data | sed 's/|/\\|/g')
        
        # Criar linha da tabela
        echo "| [$titulo_escaped]($url) | $url_escaped | $data_escaped |" >> $arquivo_saida
        
        set contador (math $contador + 1)
    end
end < $arquivo_entrada

echo "Processamento concluído!"
echo "Arquivo salvo como: $arquivo_saida"
echo "Total de favoritos processados: $contador" 