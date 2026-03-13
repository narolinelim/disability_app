# audio_service.py
import sounddevice as sd
import numpy as np
import queue
import threading
from decibel_detector import detect_noise
from sound_classifier import classify_buffer

# --------------------------
# 配置参数
# --------------------------
SAMPLE_RATE = 16000          # 采样率 16kHz
CHANNELS = 1                 # 单声道
BUFFER_DURATION = 0.975          # 每隔 1 秒生成一个 buffer
BUFFER_SIZE = int(SAMPLE_RATE * BUFFER_DURATION)  # 每个 buffer 的帧数

# --------------------------
# 队列缓存 PCM buffer
# --------------------------
audio_queue = queue.Queue()

# --------------------------
# 回调函数：实时接收音频
# --------------------------
def audio_callback(indata, frames, time, status):
    """
    sounddevice 回调函数，每次采集到音频数据就触发
    indata.shape = (frames, channels)
    """
    if status:
        print(f"Status: {status}")
    # 取单声道
    print(f"indata dtype: {indata.dtype}, shape: {indata.shape}")
    mono_data = indata[:, 0]#.astype(np.float32)
    audio_queue.put(mono_data.copy())

# --------------------------
# 开启实时录音
# --------------------------
def start_recording():
    """
    启动实时录音服务
    """
    def _record():
        print("Recording started... Press Ctrl+C to stop.")
        with sd.InputStream(
                channels=CHANNELS,
                samplerate=SAMPLE_RATE,
                blocksize=BUFFER_SIZE,
                callback=audio_callback
        ):
            while True:
                buffer = audio_queue.get()
                db, alert = detect_noise(buffer)
                if alert:
                    max_val = np.max(np.abs(buffer))
                    if max_val > 0:
                        norm_buffer = buffer / max_val
                    else:
                        norm_buffer=buffer
                    label = classify_buffer(norm_buffer)
                    print(f"Got buffer of length: {len(buffer)}, dB: {db:.2f}, Alert: {alert}, Label: {label}")
                else:
                    print(f"Got buffer of length: {len(buffer)}, dB: {db:.2f}, Alert: {alert}")
    # 用线程运行录音，防止阻塞主程序
    thread = threading.Thread(target=_record, daemon=True)
    thread.start()
    return thread  # 返回线程对象以便管理

# --------------------------
# 测试功能
# --------------------------
if __name__ == "__main__":
    start_recording()
    try:
        while True:
            pass  # 主线程保持运行
    except KeyboardInterrupt:
        print("Recording stopped.")