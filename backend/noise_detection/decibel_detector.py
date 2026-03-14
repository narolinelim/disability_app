# decibel_detector.py
import numpy as np

# --------------------------
# 配置参数
# --------------------------
DB_THRESHOLD = -85  # 超过 50 dB 认为有潜在危险，可调整

# --------------------------
# 计算分贝函数
# --------------------------
def buffer_to_db(buffer):
    """
    输入：buffer (numpy array, PCM)
    输出：近似分贝值
    """
    # RMS（均方根）计算
    rms = np.sqrt(np.mean(buffer**2))
    db = 20 * np.log10(rms + 1e-6)  # 防止 log(0)
    return db

# --------------------------
# 检测是否超过阈值
# --------------------------
def detect_noise(buffer):
    """
    输入：buffer
    输出：db 值, 是否超过阈值 (True/False)
    """
    db = buffer_to_db(buffer)
    alert = db >= DB_THRESHOLD
    return db, alert

# --------------------------
# 测试功能
# --------------------------
if __name__ == "__main__":
    # 测试用随机信号
    test_buffer = np.random.randn(16000) * 1000  # 模拟 PCM 数据
    db, alert = detect_noise(test_buffer)
    print(f"dB: {db:.2f}, Alert: {alert}")