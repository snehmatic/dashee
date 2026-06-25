import sys
from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                               QHBoxLayout, QLabel, QPushButton, QProgressBar, 
                               QStackedWidget, QLineEdit, QFormLayout, QFrame, QMessageBox)
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QFont, QColor, QPalette

from api import APISyncWorker
from config import config_manager

# --- Stylesheet for Premium Dark Mode ---
STYLESHEET = """
QMainWindow {
    background-color: #121212;
}
QWidget {
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}
QFrame.Card {
    background-color: #1e1e1e;
    border-radius: 12px;
    border: 1px solid #333333;
}
QLabel.Title {
    font-size: 24px;
    font-weight: bold;
    color: #ffffff;
}
QLabel.Subtitle {
    font-size: 14px;
    color: #a0a0a0;
}
QLabel.ValueLabel {
    font-size: 32px;
    font-weight: bold;
    color: #ffffff;
}
QLabel.MetricLabel {
    font-size: 13px;
    color: #888888;
    text-transform: uppercase;
    font-weight: bold;
}
QPushButton {
    background-color: #2979ff;
    color: white;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: bold;
    font-size: 14px;
    border: none;
}
QPushButton:hover {
    background-color: #448aff;
}
QPushButton:pressed {
    background-color: #2962ff;
}
QPushButton:disabled {
    background-color: #333333;
    color: #888888;
}
QPushButton.Secondary {
    background-color: transparent;
    border: 1px solid #555555;
    color: #e0e0e0;
}
QPushButton.Secondary:hover {
    background-color: #333333;
}
QLineEdit {
    background-color: #2a2a2a;
    border: 1px solid #444444;
    border-radius: 6px;
    padding: 8px;
    color: #ffffff;
    font-size: 14px;
}
QLineEdit:focus {
    border: 1px solid #2979ff;
}
QProgressBar {
    background-color: #2a2a2a;
    border-radius: 4px;
    text-align: center;
    color: transparent;
    height: 8px;
}
QProgressBar::chunk {
    background-color: #00e676; /* Default Green */
    border-radius: 4px;
}
"""

class Card(QFrame):
    def __init__(self, title, parent=None):
        super().__init__(parent)
        self.setProperty("class", "Card")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(20, 20, 20, 20)
        
        title_label = QLabel(title)
        title_label.setProperty("class", "MetricLabel")
        self.layout.addWidget(title_label)
        
        self.value_label = QLabel("--")
        self.value_label.setProperty("class", "ValueLabel")
        self.layout.addWidget(self.value_label)

    def set_value(self, value):
        self.value_label.setText(str(value))


class DashboardView(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.main_window = parent

        layout = QVBoxLayout(self)
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)

        # Header
        header_layout = QHBoxLayout()
        title_layout = QVBoxLayout()
        title = QLabel("LiteLLM Dashboard")
        title.setProperty("class", "Title")
        
        self.sync_time = QLabel("Last Sync: Never")
        self.sync_time.setProperty("class", "Subtitle")
        
        self.user_id_label = QLabel("User: Unknown")
        self.user_id_label.setProperty("class", "Subtitle")

        title_layout.addWidget(title)
        title_layout.addWidget(self.user_id_label)
        title_layout.addWidget(self.sync_time)
        header_layout.addLayout(title_layout)

        header_layout.addStretch()

        self.btn_settings = QPushButton("⚙️ Settings")
        self.btn_settings.setProperty("class", "Secondary")
        self.btn_refresh = QPushButton("↻ Refresh")
        
        header_layout.addWidget(self.btn_settings)
        header_layout.addWidget(self.btn_refresh)
        
        layout.addLayout(header_layout)

        # Primary Metric Cards
        metrics_layout = QHBoxLayout()
        self.card_today = Card("TODAY's SPEND")
        self.card_total = Card("TOTAL SPENT")
        self.card_budget = Card("MAX BUDGET")
        
        metrics_layout.addWidget(self.card_today)
        metrics_layout.addWidget(self.card_total)
        metrics_layout.addWidget(self.card_budget)
        layout.addLayout(metrics_layout)

        # Budget Pacing
        pacing_frame = QFrame()
        pacing_frame.setProperty("class", "Card")
        pacing_layout = QVBoxLayout(pacing_frame)
        pacing_layout.setContentsMargins(20, 20, 20, 20)
        
        pacing_title = QLabel("BUDGET BURN PROGRESS")
        pacing_title.setProperty("class", "MetricLabel")
        pacing_layout.addWidget(pacing_title)

        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.progress_bar.setFixedHeight(12)
        pacing_layout.addWidget(self.progress_bar)
        
        self.pacing_label = QLabel("0% (0.00 / No Limit)")
        self.pacing_label.setProperty("class", "Subtitle")
        pacing_layout.addWidget(self.pacing_label)

        layout.addWidget(pacing_frame)

        # Velocity Panel
        velocity_layout = QHBoxLayout()
        self.card_avg = Card("AVG SPEND / DAY")
        self.card_allowed = Card("ALLOWED SPEND / DAY")
        
        velocity_layout.addWidget(self.card_avg)
        velocity_layout.addWidget(self.card_allowed)
        layout.addLayout(velocity_layout)

        layout.addStretch()

    def update_metrics(self, data):
        self.sync_time.setText(f"Last Sync: {data.get('sync_time')}")
        self.user_id_label.setText(f"User: {data.get('user_id')}")
        
        self.card_today.set_value(f"${data.get('todays_spend'):.2f}")
        self.card_total.set_value(f"${data.get('spend'):.2f}")
        
        max_budget = data.get('max_budget')
        if isinstance(max_budget, (int, float)):
            self.card_budget.set_value(f"${max_budget:.2f}")
        else:
            self.card_budget.set_value(str(max_budget))
            
        self.card_avg.set_value(f"${data.get('avg_spend_per_day'):.2f}")
        self.card_allowed.set_value(f"${data.get('daily_spend_left'):.2f}")

        # Warning for today's spend exceeding daily allowance
        if data.get('todays_spend') > data.get('daily_spend_left') and data.get('daily_spend_left') > 0:
            self.card_today.value_label.setStyleSheet("color: #ff5252;") # Red
        else:
            self.card_today.value_label.setStyleSheet("color: #ffffff;")

        # Update Progress Bar Color and Value
        burn_percent = data.get('burn_percent', 0.0)
        self.progress_bar.setValue(int(burn_percent))
        
        if isinstance(max_budget, (int, float)) and max_budget > 0:
            self.pacing_label.setText(f"{burn_percent:.1f}% (${data.get('spend'):.2f} / ${max_budget:.2f}) - {data.get('days_to_reset')} days to reset")
        else:
            self.pacing_label.setText("No active budget limit.")

        # Smooth visual progress bar color-shifting
        if burn_percent >= 90:
            color = "#ff5252" # Red
        elif burn_percent >= 75:
            color = "#ffd600" # Yellow
        else:
            color = "#00e676" # Green

        self.progress_bar.setStyleSheet(f"""
            QProgressBar::chunk {{
                background-color: {color};
                border-radius: 4px;
            }}
        """)

class SettingsView(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.main_window = parent
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(20)

        title = QLabel("Settings")
        title.setProperty("class", "Title")
        layout.addWidget(title)

        form_layout = QFormLayout()
        form_layout.setSpacing(15)
        
        self.input_url = QLineEdit()
        self.input_url.setText(config_manager.get("BASE_URL"))
        self.input_url.setPlaceholderText("https://your-litellm-gateway.com")
        
        self.input_key = QLineEdit()
        self.input_key.setText(config_manager.get("API_KEY"))
        self.input_key.setEchoMode(QLineEdit.Password)
        self.input_key.setPlaceholderText("sk-...")

        self.input_user = QLineEdit()
        self.input_user.setText(config_manager.get("USER_ID"))
        
        form_layout.addRow(QLabel("Base URL:"), self.input_url)
        form_layout.addRow(QLabel("API Key:"), self.input_key)
        form_layout.addRow(QLabel("User ID:"), self.input_user)
        
        layout.addLayout(form_layout)

        btn_layout = QHBoxLayout()
        self.btn_cancel = QPushButton("Cancel")
        self.btn_cancel.setProperty("class", "Secondary")
        self.btn_save = QPushButton("Save & Apply")
        
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_cancel)
        btn_layout.addWidget(self.btn_save)
        
        layout.addLayout(btn_layout)
        layout.addStretch()

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("LiteLLM Dashboard")
        self.setMinimumSize(800, 600)
        self.setStyleSheet(STYLESHEET)

        self.stacked_widget = QStackedWidget()
        self.setCentralWidget(self.stacked_widget)

        self.dashboard = DashboardView(self)
        self.settings = SettingsView(self)

        self.stacked_widget.addWidget(self.dashboard)
        self.stacked_widget.addWidget(self.settings)

        # Connections
        self.dashboard.btn_settings.clicked.connect(self.show_settings)
        self.dashboard.btn_refresh.clicked.connect(self.refresh_data)
        
        self.settings.btn_cancel.clicked.connect(self.show_dashboard)
        self.settings.btn_save.clicked.connect(self.save_settings)

        self.worker = None
        
        # Initial Check
        if not config_manager.get("BASE_URL") or not config_manager.get("API_KEY"):
            self.show_settings()
        else:
            self.refresh_data()

    def show_settings(self):
        self.stacked_widget.setCurrentWidget(self.settings)

    def show_dashboard(self):
        self.stacked_widget.setCurrentWidget(self.dashboard)

    def save_settings(self):
        config_manager.set("BASE_URL", self.settings.input_url.text().strip())
        config_manager.set("API_KEY", self.settings.input_key.text().strip())
        config_manager.set("USER_ID", self.settings.input_user.text().strip())
        
        self.show_dashboard()
        self.refresh_data()

    def refresh_data(self):
        self.dashboard.btn_refresh.setEnabled(False)
        self.dashboard.btn_refresh.setText("↻ Refreshing...")
        
        self.worker = APISyncWorker()
        self.worker.finished.connect(self.on_data_fetched)
        self.worker.error.connect(self.on_error)
        self.worker.start()

    def on_data_fetched(self, data):
        self.dashboard.update_metrics(data)
        self.reset_refresh_button()

    def on_error(self, error_msg):
        QMessageBox.warning(self, "Error", error_msg)
        self.reset_refresh_button()

    def reset_refresh_button(self):
        self.dashboard.btn_refresh.setEnabled(True)
        self.dashboard.btn_refresh.setText("↻ Refresh")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
