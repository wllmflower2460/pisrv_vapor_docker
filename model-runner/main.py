from fastapi import FastAPI
from pydantic import BaseModel
import json, os, numpy as np, torch

MODEL_DIR = os.environ.get("MODEL_DIR", "/models")
CFG_PATH = os.path.join(MODEL_DIR, "model_config.json")
ENC_PATH = os.path.join(MODEL_DIR, "tcn_encoder_for_edgeinfer.pth")
DEV = torch.device("cpu")

# optional model config
try:
    with open(CFG_PATH) as f: CFG = json.load(f)
except Exception: CFG = {}

# load encoder (TorchScript or nn.Module / dict)
try:
    encoder = torch.jit.load(ENC_PATH, map_location=DEV)
except Exception:
    obj = torch.load(ENC_PATH, map_location=DEV)
    encoder = obj.get("model", obj) if hasattr(obj, "get") else obj
encoder.eval()

class Window(BaseModel):
    x: list[list[float]]  # (T,9) IMU window

app = FastAPI()

@app.post("/infer")
def infer(win: Window):
    import numpy as np, torch
    x = np.asarray(win.x, dtype=np.float32)      # (T,9)
    x = torch.from_numpy(x).unsqueeze(0)         # (1,T,9)
    with torch.no_grad():
        z = encoder(x)                           # (1,Z)
    z = z.squeeze(0).cpu().numpy()
    return {"latent": z.tolist(), "motif_scores": z[:12].tolist()}