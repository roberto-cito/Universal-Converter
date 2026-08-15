import sys
import multiprocessing
import warnings

# Nascondiamo i warning inutili per non confondere Swift
warnings.filterwarnings("ignore")

from pdf2docx import Converter

def convert_pdf_to_docx(pdf_file, docx_file):
    cv = Converter(pdf_file)
    cv.convert(docx_file, start=0, end=None)
    cv.close()
    print("SUCCESS")

def convert_docx_to_pdf(docx_file, pdf_file):
    try:
        from docx2pdf import convert
        convert(docx_file, pdf_file)
        print("SUCCESS")
    except Exception as e:
        print(f"FAILED: Errore docx2pdf. {e}")

if __name__ == '__main__':
    # LA RIGA MAGICA: Impedisce ai processi paralleli di fare danni!
    multiprocessing.freeze_support()
    
    if len(sys.argv) < 3:
        print("Errore: Argomenti mancanti")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        in_doc = input_file.lower().endswith(".docx") or input_file.lower().endswith(".doc")
        
        if input_file.lower().endswith(".pdf") and output_file.lower().endswith(".docx"):
            convert_pdf_to_docx(input_file, output_file)
        elif in_doc and output_file.lower().endswith(".pdf"):
            convert_docx_to_pdf(input_file, output_file)
        else:
            print("FAILED: Direzione di conversione non supportata")
    except Exception as e:
        print(f"FAILED: {e}")