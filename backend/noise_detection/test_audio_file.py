# test_audio_file.py
import librosa
import numpy as np
from decibel_detector import detect_noise
from sound_classifier import classify_buffer

# --------------------------
# 配置参数
# --------------------------
# FILE_PATH = "Australian Fire Alarm Sound.mp3"  # 你的音频文件
# FILE_PATH = "Bicycle bell.mp3"  # 你的音频文件
# FILE_PATH = "Baby crying.mp3"
# FILE_PATH = "Car horn.mp3"
FILE_PATH = "Dog bark.mp3"
SAMPLE_RATE = 16000                             # 模型采样率
SEGMENT_DURATION = 0.975                        # 模型底层片段长度 (秒)
DB_THRESHOLD = -100                             # 分贝阈值，可与 decibel_detector.py 保持一致

# --------------------------
# 读取音频
# --------------------------
audio, sr = librosa.load(FILE_PATH, sr=SAMPLE_RATE, mono=True)  # 转单声道，采样率16kHz
print(f"Loaded audio, length: {len(audio)/sr:.2f}s, sr: {sr}")

# --------------------------
# 计算每段的帧数
# --------------------------
segment_length = int(SAMPLE_RATE * SEGMENT_DURATION)
num_segments = len(audio) // segment_length
if len(audio) % segment_length != 0:
    num_segments += 1  # 最后一段不够长度时补零

# --------------------------
# 分段处理
# --------------------------
for i in range(num_segments):
    start = i * segment_length
    end = start + segment_length
    segment = audio[start:end]

    # 不够长度就补零
    if len(segment) < segment_length:
        segment = np.pad(segment, (0, segment_length - len(segment)), mode='constant')

    # 分贝检测
    db, alert = detect_noise(segment)

    if alert:
        # 归一化到 [-1,1]
        max_val = np.max(np.abs(segment))
        if max_val > 0:
            norm_segment = segment / max_val
        else:
            norm_segment = segment
        # 分类
        label = classify_buffer(norm_segment)
        print(f"Segment {i+1}, dB: {db:.2f}, Alert: True, Label: {label}")
    else:
        print(f"Segment {i+1}, dB: {db:.2f}, Alert: False")