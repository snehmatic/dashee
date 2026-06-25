import os
import json
from pathlib import Path

# Use macOS standard Application Support directory
APP_NAME = "Dashee"
CONFIG_DIR = Path.home() / "Library" / "Application Support" / APP_NAME
CONFIG_FILE = CONFIG_DIR / "config.json"

class ConfigManager:
    def __init__(self):
        self.config = {
            "BASE_URL": "",
            "API_KEY": "",
            "USER_ID": "eb4b261d-783f-45b5-b1f9-36628392d13a"
        }
        self.load_config()

    def load_config(self):
        if not CONFIG_DIR.exists():
            CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            self.save_config()
            return
            
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, 'r') as f:
                    data = json.load(f)
                    self.config.update(data)
            except Exception as e:
                print(f"Error loading config: {e}")

    def save_config(self):
        if not CONFIG_DIR.exists():
            CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        try:
            with open(CONFIG_FILE, 'w') as f:
                json.dump(self.config, f, indent=4)
        except Exception as e:
            print(f"Error saving config: {e}")

    def get(self, key, default=""):
        return self.config.get(key, default)

    def set(self, key, value):
        self.config[key] = value
        self.save_config()

config_manager = ConfigManager()
