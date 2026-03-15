from pathlib import Path
from ultralytics import YOLO
import shutil
import onnx


MAX_SUPPORTED_IR_VERSION = 9
model_name = 'yolo26n.pt'

def convert_yolo_to_onnx():
    script_dir = Path(__file__).resolve().parent

    model_path = script_dir / model_name
    model = YOLO(str(model_path))

    exported_path = Path(model.export(format='onnx', imgsz=320, opset=12, simplify=False))

    # Keep the model under Flutter asset path used by rootBundle.
    dest_dir = script_dir.parent / 'assets' / 'models'
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_path = dest_dir / 'yolo26n.onnx'

    shutil.move(str(exported_path), str(dest_path))
    print(f'ONNX model moved to: {dest_path}')


if __name__ == "__main__":
    convert_yolo_to_onnx()
