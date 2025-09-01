from fastapi import FastAPI
from pydantic import BaseModel
import json, os, numpy as np, torch

MODEL_DIR = os.environ.get("MODEL_DIR", "/models")
CFG_PATH = os.path.join(MODEL_DIR, "model_config.json")
ENC_PATH = os.path.join(MODEL_DIR, "tcn_encoder_for_edgeinfer.pth")
DEV = torch.device("cpu")

# Configuration constants
DEFAULT_LATENT_DIM = 32  # Default latent dimension for stub mode

try:
    with open(CFG_PATH) as f:
        CFG = json.load(f)
except Exception:
    CFG = {}

try:
    encoder = torch.jit.load(ENC_PATH, map_location=DEV)
except Exception:
    try:
        obj = torch.load(ENC_PATH, map_location=DEV)
        encoder = obj.get("model", obj) if hasattr(obj, "get") else obj
    except Exception:
        encoder = None
encoder.eval() if encoder else None

class Window(BaseModel):
    x: list[list[float]]  # (T,9) IMU window

app = FastAPI()

@app.get("/healthz")
def health():
    return {"ok": True, "loaded": bool(encoder)}

@app.post("/infer")
def infer(win: Window):
    if encoder is None:
        # Use configured latent dimension or default for stub mode
        latent_dim = CFG.get("latent_dim", DEFAULT_LATENT_DIM)
        z = np.zeros(latent_dim, dtype=np.float32)
    else:
        x = np.asarray(win.x, dtype=np.float32)
        x = torch.from_numpy(x).unsqueeze(0)
        with torch.no_grad():
            z = encoder(x)
        z = z.squeeze(0).cpu().numpy()
    motif_scores = z[:12].tolist() if z.shape[0] >= 12 else z.tolist()
    return {"latent": z.tolist(), "motif_scores": motif_scores}