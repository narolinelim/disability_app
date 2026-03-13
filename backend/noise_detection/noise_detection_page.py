# noise_detection.py
import threading
import time

from decibel_detector import detect_noise
from sound_classifier import classify_buffer  # 你后面写的 TFLite 分类器
from audio_service import audio_queue, start_recording

# --------------------------
# 危险声音列表
# --------------------------
DANGEROUS_LABELS = ["Fire alarm", "Crying baby", "Doorbell", "Vehicle horn"]

# --------------------------
# 核心处理函数
# --------------------------
def process_buffer(buffer):
    """
    输入：PCM buffer
    输出：db, final_alert, label
    """
    # Step 1: 分贝检测
    db, alert_db = detect_noise(buffer)

    label = "Safe"
    alert_class = False

    # Step 2: 仅当分贝超过阈值才分类
    if alert_db:
        label = classify_buffer(buffer)
        alert_class = label in DANGEROUS_LABELS

    # Step 3: 最终 alert
    final_alert = alert_db or alert_class

    return db, final_alert, label

# --------------------------
# 后台线程处理队列
# --------------------------
def start_noise_detection(audio_queue):
    """
    输入：audio_queue
    后台线程循环处理 buffer
    """
    def _run():
        print("Noise detection started... Press Ctrl+C to stop.")
        while True:
            buffer = audio_queue.get()  # 阻塞直到有数据
            db, alert, label = process_buffer(buffer)
            print(f"dB: {db:.2f}, Alert: {alert}, Label: {label}")

    thread = threading.Thread(target=_run, daemon=True)
    thread.start()
    return thread

# --------------------------
# 测试功能
# --------------------------
if __name__ == "__main__":
    # 启动录音
    start_recording()

    # 启动噪声检测后台线程
    start_noise_detection(audio_queue)

    # 主线程保持运行
    try:
        while True:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("Stopped.")