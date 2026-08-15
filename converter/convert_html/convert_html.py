import pymupdf

def convert_pdf_to_html(pdf_file, html_file):
    doc = pymupdf.open(pdf_file)
    full_html = "<html><body>"
    for page in doc:
        # Estrae la pagina mantenendo stile, font e layout approssimativo
        full_html += page.get_text("html") 
        full_html += "<hr>" # Divisore tra pagine
    full_html += "</body></html>"
    
    with open(html_file, "w", encoding="utf-8") as f:
        f.write(full_html)
    doc.close()
    print("SUCCESS")

def convert_html_to_pdf(html_file, pdf_file):
    doc = pymupdf.open()
    with open(html_file, "r", encoding="utf-8") as f:
        html_content = f.read()
    
    # Aggiunge una nuova pagina al documento PDF
    page = doc.new_page()
    # Inserisce il contenuto HTML nella pagina
    page.insert_htmlbox(page.rect, html_content)
    
    doc.save(pdf_file)
    doc.close()
    print("SUCCESS")

if __name__ == '__main__':
    import sys
    import multiprocessing
    
    multiprocessing.freeze_support()
    
    if len(sys.argv) < 3:
        print("Errore: Argomenti mancanti")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        if input_file.lower().endswith(".pdf") and output_file.lower().endswith(".html"):
            convert_pdf_to_html(input_file, output_file)
        elif input_file.lower().endswith(".html") and output_file.lower().endswith(".pdf"):
            convert_html_to_pdf(input_file, output_file)
        else:
            print("FAILED: Direzione di conversione non supportata")
            sys.exit(1)
    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)