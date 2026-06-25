import requests
from datetime import datetime, timezone
from PySide6.QtCore import QThread, Signal
from config import config_manager

class APISyncWorker(QThread):
    finished = Signal(dict)
    error = Signal(str)

    def run(self):
        try:
            base_url = config_manager.get("BASE_URL", "").replace("/v1", "").rstrip("/")
            api_key = config_manager.get("API_KEY", "")
            user_id = config_manager.get("USER_ID", "")
            
            if not base_url or not api_key or not user_id:
                self.error.emit("Please configure Base URL, API Key, and User ID in Settings.")
                return

            headers = {"Authorization": f"Bearer {api_key}"}
            now = datetime.now(timezone.utc)
            today_str = now.strftime("%Y-%m-%d")

            spend = 0.0
            max_budget = "No Limit"
            reset_at = None
            duration = "N/A"
            todays_spend = 0.0

            # 1. Fetch General User Info
            user_response = requests.get(f"{base_url}/user/info?user_id={user_id}", headers=headers, timeout=10)
            user_response.raise_for_status()
            info = user_response.json().get("user_info", user_response.json())

            spend = info.get("spend", 0.0)
            max_budget = info.get("max_budget", "No Limit")
            reset_at = info.get("budget_reset_at")
            duration = info.get("budget_duration", "N/A")

            # 2. Fetch Today's Activity
            try:
                activity_endpoint = f"{base_url}/user/daily/activity?user_id={user_id}&start_date={today_str}&end_date={today_str}"
                activity_response = requests.get(activity_endpoint, headers=headers, timeout=10)
                activity_response.raise_for_status()
                activity_results = activity_response.json().get("results", [])
                if activity_results:
                    todays_spend = activity_results[0].get("metrics", {}).get("spend", 0.0)
            except Exception as e:
                pass # Non-critical if we fail to fetch daily activity

            # 3. Compute Complex Pacing Metrics
            burn_percent = 0.0
            days_to_reset = 1
            total_cycle_days = 30

            if duration and str(duration).rstrip('d').isdigit():
                total_cycle_days = int(str(duration).rstrip('d'))

            if reset_at:
                try:
                    reset_date = datetime.fromisoformat(str(reset_at).replace("Z", "+00:00")) if isinstance(reset_at, str) else datetime.fromtimestamp(reset_at, tz=timezone.utc)
                    days_to_reset = max(1, (reset_date - now).days)
                except ValueError:
                    pass

            days_elapsed = max(1, total_cycle_days - days_to_reset)
            avg_spend_per_day = spend / days_elapsed

            if isinstance(max_budget, (int, float)) and max_budget > 0:
                burn_percent = (spend / max_budget) * 100
                daily_spend_left = (max_budget - spend) / days_to_reset
            else:
                daily_spend_left = 0.0

            result = {
                "user_id": user_id,
                "sync_time": now.strftime('%Y-%m-%d %H:%M:%S UTC'),
                "todays_spend": todays_spend,
                "spend": spend,
                "max_budget": max_budget,
                "burn_percent": burn_percent,
                "avg_spend_per_day": avg_spend_per_day,
                "daily_spend_left": daily_spend_left,
                "days_to_reset": days_to_reset
            }
            self.finished.emit(result)

        except requests.exceptions.RequestException as e:
            self.error.emit(f"Network error: {e}")
        except Exception as e:
            self.error.emit(f"Error fetching data: {str(e)}")
