#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
from bs4 import BeautifulSoup
from datetime import datetime
import html

def processar_favoritos_html(arquivo_html):
    """
    Processa um arquivo HTML de favoritos do Firefox e retorna uma tabela markdown
    """
    
    # Ler o arquivo HTML
    with open(arquivo_html, 'r', encoding='utf-8') as f:
        conteudo = f.read()
    
    # Parsear o HTML
    soup = BeautifulSoup(conteudo, 'html.parser')
    
    # Lista para armazenar os favoritos
    favoritos = []
    
    # Encontrar todos os links (tags <A>)
    links = soup.find_all('a')
    
    for link in links:
        href = link.get('href', '')
        texto = link.get_text(strip=True)
        add_date = link.get('add_date', '')
        
        # Pular links vazios ou sem texto
        if not href or not texto:
            continue
        
        # Converter timestamp para data legível se disponível
        if add_date and add_date.isdigit():
            try:
                data = datetime.fromtimestamp(int(add_date))
                data_formatada = data.strftime('%d/%m/%Y %H:%M')
            except:
                data_formatada = add_date
        else:
            data_formatada = add_date if add_date else ''
        
        # Decodificar entidades HTML
        texto = html.unescape(texto)
        
        favoritos.append({
            'titulo': texto,
            'url': href,
            'data': data_formatada
        })
    
    return favoritos

def criar_tabela_markdown(favoritos):
    """
    Cria uma tabela markdown a partir da lista de favoritos
    """
    
    # Cabeçalho da tabela
    markdown = "# Favoritos do Firefox\n\n"
    markdown += "| Título | URL | Data de Adição |\n"
    markdown += "|--------|-----|----------------|\n"
    
    # Adicionar cada favorito
    for fav in favoritos:
        # Escapar pipes no título e URL
        titulo = fav['titulo'].replace('|', '\\|')
        url = fav['url'].replace('|', '\\|')
        data = fav['data'].replace('|', '\\|')
        
        # Criar link markdown
        link_markdown = f"[{titulo}]({url})"
        
        markdown += f"| {link_markdown} | {url} | {data} |\n"
    
    return markdown

def main():
    # Arquivo de entrada
    arquivo_entrada = "/home/wilsonseabra/Downloads/favoritos_04_08_2025.html"
    
    # Arquivo de saída
    arquivo_saida = "favoritos_tabela.md"
    
    try:
        # Processar o arquivo HTML
        print("Processando arquivo HTML...")
        favoritos = processar_favoritos_html(arquivo_entrada)
        
        print(f"Encontrados {len(favoritos)} favoritos")
        
        # Criar tabela markdown
        print("Criando tabela markdown...")
        tabela_markdown = criar_tabela_markdown(favoritos)
        
        # Salvar arquivo
        with open(arquivo_saida, 'w', encoding='utf-8') as f:
            f.write(tabela_markdown)
        
        print(f"Arquivo salvo como: {arquivo_saida}")
        print(f"Total de favoritos processados: {len(favoritos)}")
        
    except Exception as e:
        print(f"Erro ao processar arquivo: {e}")

if __name__ == "__main__":
    main() 