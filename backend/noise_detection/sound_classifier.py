# sound_classifier.py
import numpy as np
import tensorflow as tf
import csv

# --------------------------
# 模型与标签文件路径
# --------------------------
MODEL_PATH = "./1.tflite"
CLASS_MAP_PATH = "./yamnet_class_map.csv"

# --------------------------
# 加载分类标签
# --------------------------
def load_labels(csv_path):
    labels = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader)  # 跳过表头，如果有的话
        for row in reader:
            labels.append(row[2])  # 第三列是声音名字
    return labels

CLASS_LABELS = load_labels(CLASS_MAP_PATH)

# --------------------------
# 加载 TFLite 模型
# --------------------------
interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# --------------------------
# 声音分类函数
# --------------------------
def classify_buffer(buffer):
    """
    输入：buffer (numpy array, float32, 16kHz 单声道)
    输出：标签字符串
    """
    # TFLite 模型一般要求 shape = [1, n_samples]
    input_data = buffer.astype(np.float32)

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    output_data = interpreter.get_tensor(output_details[0]['index'])[0]

    # 找到概率最大类别
    top_index = np.argmax(output_data)
    label = CLASS_LABELS[top_index]

    return label


# --------------------------
# 测试功能
# --------------------------
if __name__ == "__main__":
    # 测试用随机信号
    test_buffer = np.random.randn(16000).astype(np.float32)
    label = classify_buffer(test_buffer)
    print(f"Predicted label: {label}")
