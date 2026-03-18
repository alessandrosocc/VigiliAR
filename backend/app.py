from fastapi import FastAPI, File, UploadFile, HTTPException, Request, Body
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fast_alpr import ALPR
from fast_alpr.base import BaseOCR, OcrResult
from io import BytesIO
from PIL import Image, UnidentifiedImageError
import tempfile, os, time, asyncio
import cv2
import numpy as np
from fast_plate_ocr import LicensePlateRecognizer
import yaml

"""
1. uvicorn app:app --host <ip> --port 8000
2. cambia ip nella app in swift



b"""
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # in prod: limita ai tuoi domini
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CompatibleOCR(BaseOCR):
    def __init__(self, hub_ocr_model: str | None = "cct-xs-v1-global-model") -> None:
        self.ocr_model = LicensePlateRecognizer(hub_ocr_model=hub_ocr_model)

    def predict(self, cropped_plate: np.ndarray) -> OcrResult | None:
        if cropped_plate is None:
            return None
        if self.ocr_model.config.image_color_mode == "grayscale":
            cropped_plate = cv2.cvtColor(cropped_plate, cv2.COLOR_BGR2GRAY)
        pred = self.ocr_model.run_one(cropped_plate, return_confidence=True)
        confidence = (
            float(np.mean(pred.char_probs))
            if pred.char_probs is not None
            else 0.0
        )
        return OcrResult(text=pred.plate, confidence=confidence)


alpr = ALPR(
    detector_model="yolo-v9-t-384-license-plate-end2end",
    ocr=CompatibleOCR("cct-xs-v1-global-model"),
)

# --- Tuning ---
MAX_W, MAX_H = 800, 600
try:
    RESAMPLE = Image.BILINEAR
except AttributeError:
    from PIL import Image as _I
    RESAMPLE = _I.Resampling.BILINEAR

JPEG_QUALITY = 50
JPEG_SUBSAMPLING = 2
JPEG_OPTIMIZE = True

LAST_REQUEST_AT = {}
MIN_INTERVAL_SEC = 0.15
CARS_FILE = os.path.join(os.path.dirname(__file__), "cars.yaml")
CARS_FILE_LOCK = asyncio.Lock()
USERS_FILE = os.path.join(os.path.dirname(__file__), "users.yaml")
USERS_FILE_LOCK = asyncio.Lock()



def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def normalize_plate(plate: str | None) -> str:
    if not plate:
        return ""
    return "".join(plate.upper().split())

def normalize_identity_value(value: str | None) -> str:
    if value is None:
        return ""
    return " ".join(str(value).strip().upper().split())

def first_present(payload: dict, keys: list[str]) -> str:
    for key in keys:
        value = payload.get(key)
        if value is not None and str(value).strip() != "":
            return str(value).strip()
    return ""

def load_users_document() -> dict:
    if not os.path.exists(USERS_FILE):
        return {"utenti": []}
    try:
        with open(USERS_FILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return {"utenti": []}

    if not isinstance(data, dict):
        return {"utenti": []}
    if not isinstance(data.get("utenti"), list):
        data["utenti"] = []
    return data

def save_users_document(data: dict) -> None:
    with open(USERS_FILE, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)

def find_user(name: str, surname: str, identifier: str) -> dict | None:
    users_document = load_users_document()
    users = users_document.get("utenti", [])
    root_name = users_document.get("Nome") or users_document.get("name")
    root_surname = users_document.get("Cognome") or users_document.get("surname")
    root_identifier = (
        users_document.get("matricola")
        or users_document.get("identificativo")
        or users_document.get("identifier")
    )
    normalized_name = normalize_identity_value(name)
    normalized_surname = normalize_identity_value(surname)
    normalized_identifier = normalize_identity_value(identifier)
    for user in users:
        if not isinstance(user, dict):
            continue
        stored_name = normalize_identity_value(
            user.get("Nome") or user.get("name") or root_name
        )
        stored_surname = normalize_identity_value(
            user.get("Cognome") or user.get("surname") or root_surname
        )
        stored_identifier = normalize_identity_value(
            user.get("matricola")
            or user.get("identificativo")
            or user.get("identifier")
            or root_identifier
        )
        if (
            stored_name == normalized_name
            and stored_surname == normalized_surname
            and stored_identifier == normalized_identifier
        ):
            return user
    return None

@app.post("/auth/login")
async def auth_login(payload: dict = Body(...)):
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="Invalid payload")

    name = first_present(payload, ["name", "Nome"])
    surname = first_present(payload, ["surname", "Cognome"])
    identifier = first_present(
        payload,
        ["identifier", "identificativo", "matricola", "Matricola"]
    )

    if not name or not surname or not identifier:
        raise HTTPException(
            status_code=400,
            detail="name, surname and identifier are required"
        )

    async with USERS_FILE_LOCK:
        matched_user = find_user(name=name, surname=surname, identifier=identifier)
        if matched_user is None:
            raise HTTPException(status_code=401, detail="Utente non autorizzato")

    return {
        "authenticated": True,
        "user": {
            "name": matched_user.get("Nome") or matched_user.get("name"),
            "surname": matched_user.get("Cognome") or matched_user.get("surname"),
            "matricola": matched_user.get("matricola"),
        },
    }

def load_cars_by_plate() -> dict[str, dict]:
    if not os.path.exists(CARS_FILE):
        return {}
    try:
        with open(CARS_FILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return {}

    cars = data.get("cars", []) if isinstance(data, dict) else []
    cars_by_plate: dict[str, dict] = {}
    for car in cars:
        if not isinstance(car, dict):
            continue
        plate = normalize_plate(str(car.get("plate", "")))
        if plate:
            cars_by_plate[plate] = car
    return cars_by_plate

def load_cars_document() -> dict:
    if not os.path.exists(CARS_FILE):
        return {"cars": []}
    try:
        with open(CARS_FILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return {"cars": []}

    if not isinstance(data, dict):
        return {"cars": []}
    if not isinstance(data.get("cars"), list):
        data["cars"] = []
    return data

def save_cars_document(data: dict) -> None:
    with open(CARS_FILE, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)

@app.patch("/cars/{plate}")
async def update_car(plate: str, payload: dict = Body(...)):
    if not isinstance(payload, dict) or not payload:
        raise HTTPException(status_code=400, detail="Invalid update payload")

    field_aliases = {"Multa": "multa"}
    allowed_fields = {
        "multa",
        "last_seen",
        "last_revision",
        "insurance_expiration",
        "park_expiration",
        "model",
        "color",
        "year",
    }

    updates = {}
    for key, value in payload.items():
        normalized_key = field_aliases.get(key, key)
        if normalized_key in allowed_fields:
            updates[normalized_key] = value

    if not updates:
        raise HTTPException(
            status_code=400,
            detail="No valid fields to update"
        )

    normalized_plate = normalize_plate(plate)
    async with CARS_FILE_LOCK:
        data = load_cars_document()
        cars = data.get("cars", [])

        target_car = None
        for car in cars:
            if not isinstance(car, dict):
                continue
            if normalize_plate(str(car.get("plate", ""))) == normalized_plate:
                target_car = car
                break

        if target_car is None:
            raise HTTPException(status_code=404, detail="Car not found")

        target_car.update(updates)
        save_cars_document(data)

    return {
        "updated": True,
        "plate": target_car.get("plate"),
        "car_data": target_car,
    }

@app.post("/detect")
async def detect_plate(request: Request, file: UploadFile = File(...)):
    ip = request.client.host if request.client else "unknown"

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    try:
        raw = await file.read()
        image = Image.open(BytesIO(raw)).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Invalid image file")

    ow, oh = image.size
    image.thumbnail((MAX_W, MAX_H), resample=RESAMPLE)
    nw, nh = image.size
    sx = ow / max(nw, 1)
    sy = oh / max(nh, 1)

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg", dir="/tmp")
    tmp_path = tmp.name
    tmp.close()  # best practice

    try:
        image.save(
            tmp_path, "JPEG",
            quality=JPEG_QUALITY, subsampling=JPEG_SUBSAMPLING, optimize=JPEG_OPTIMIZE
        )


        results = alpr.predict(tmp_path)
        

        if not results:
            return JSONResponse(status_code=200, content={
                "detected": False, "plate": None, "confidence": 0,
                "x1": 0, "y1": 0, "x2": 0, "y2": 0,
                "car_found": False,
                "car_data": None
            })

        r0 = results[0]
        x1 = r0.detection.bounding_box.x1 * sx
        y1 = r0.detection.bounding_box.y1 * sy
        x2 = r0.detection.bounding_box.x2 * sx
        y2 = r0.detection.bounding_box.y2 * sy

        # clamp alle dimensioni originali
        x1 = clamp(x1, 0, ow); y1 = clamp(y1, 0, oh)
        x2 = clamp(x2, 0, ow); y2 = clamp(y2, 0, oh)

        # return JSONResponse(status_code=200, content={
        #     "detected": True,
        #     "plate": r0.ocr.text,
        #     "confidence": r0.ocr.confidence,
        #     "x1": x1, "y1": y1, "x2": x2, "y2": y2
        # })
        plate_text = r0.ocr.text
        cars_by_plate = load_cars_by_plate()
        car_data = cars_by_plate.get(normalize_plate(plate_text))

        return JSONResponse(status_code=200, content={
            "detected": True,
            "plate": plate_text,
            "confidence": r0.ocr.confidence,
            "car_found": car_data is not None,
            "car_data": car_data
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
