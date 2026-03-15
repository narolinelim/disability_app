from pathlib import Path

import onnx
from ultralytics import YOLO


MAX_IR = 9
MAX_OPSET = 12


def export_and_make_compatible(pt_path: str, imgsz: int = 320) -> Path:
    script_dir = Path(__file__).resolve().parent
    pt_file = (script_dir / pt_path).resolve()

    # 1) Export directly from .pt to ONNX with supported opset.
    model = YOLO(str(pt_file))
    exported = Path(
        model.export(
            format="onnx",
            imgsz=imgsz,
            opset=MAX_OPSET,
            simplify=False,
        )
    ).resolve()

    # 2) Load ONNX and set IR cap.
    onnx_model = onnx.load(str(exported))
    onnx_model.ir_version = min(int(onnx_model.ir_version), MAX_IR)

    opsets = {imp.domain: imp.version for imp in onnx_model.opset_import}
    ai_onnx_opset = opsets.get("", None)
    if ai_onnx_opset is not None and ai_onnx_opset > MAX_OPSET:
        raise RuntimeError(
            f"Model opset is {ai_onnx_opset}, expected <= {MAX_OPSET}. "
            "Re-export failed to lower opset."
        )

    # 3) Save to Flutter assets/models.
    out_dir = script_dir.parent / "assets" / "models"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{pt_file.stem}_ir{onnx_model.ir_version}_opset{ai_onnx_opset}.onnx"
    onnx.save(onnx_model, str(out_path))

    print(f"Saved: {out_path}")
    print(f"IR: {onnx_model.ir_version}, opset(ai.onnx): {ai_onnx_opset}")
    return out_path


if __name__ == "__main__":
    export_and_make_compatible("yolo26n.pt", imgsz=320)