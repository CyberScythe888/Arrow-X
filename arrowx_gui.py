import sys
from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout, QPushButton, QTextBrowser, QLineEdit
from PyQt6.QtCore import QProcess
from ansi2html import Ansi2HTMLConverter

class ArrowXGUI(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.process = None
        self.ansi_converter = Ansi2HTMLConverter(inline=True)  # Force inline rendering mode
        self.full_output = ""  # Store full output before updating UI

    def init_ui(self):
        layout = QVBoxLayout()
        
        self.target_input = QLineEdit(self)
        self.target_input.setPlaceholderText("Enter target domain")
        layout.addWidget(self.target_input)
        
        self.output_box = QTextBrowser(self)
        layout.addWidget(self.output_box)
        
        self.run_button = QPushButton("Run ArrowX", self)
        self.run_button.clicked.connect(self.run_arrowx)
        layout.addWidget(self.run_button)
        
        self.setLayout(layout)
        self.setWindowTitle("ArrowX GUI")

    def run_arrowx(self):
        target = self.target_input.text().strip()
        
        self.process = QProcess(self)
        self.process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self.process.readyReadStandardOutput.connect(self.read_output)
        self.process.finished.connect(self.process_finished)
        
        self.run_button.setEnabled(False)  # Disable button while running
        self.output_box.clear()
        
        self.process.start("bash", ["arrowx.sh", "-t", target])

    def read_output(self):
        if self.process:
            text = bytes(self.process.readAllStandardOutput()).decode("utf-8")
            self.full_output += text  # Collect full output

    def process_finished(self):
        html_text = f"<pre>{self.ansi_converter.convert(self.full_output)}</pre>"
        html_text = html_text.replace("<br><br>", "<br>")  # Prevent redundant line breaks
        self.output_box.setHtml(html_text)  # Set full processed output at once
        self.run_button.setEnabled(True)  # Re-enable button after process finishes
        self.full_output = "" # Clear stored output after display is finished

app = QApplication([])
window = ArrowXGUI()
window.show()
sys.exit(app.exec())
