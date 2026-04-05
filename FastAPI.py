import base64
import json
import os
import re
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import APIRouter, FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq
from PIL import Image
from pydantic import BaseModel, Field

load_dotenv(dotenv_path=Path(__file__).resolve().parent / ".env")

app = FastAPI(
    title="Vision Learning API",
    version="1.3.0",
    description="Nhận ảnh để học từ vựng và hỗ trợ chat giải nghĩa hành động/đồ vật",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

health_router = APIRouter(prefix="/health", tags=["health"])
vision_router = APIRouter(prefix="/ai", tags=["vision"])
chat_router = APIRouter(prefix="/chat", tags=["chat"])

REQUIRED_FIELDS = {
    "topic": "Chủ đề từ vựng",
    "word": "Từ tiếng Anh",
    "phonetic": "Phiên âm",
    "vietnamese_meaning": "Nghĩa tiếng Việt",
    "example_sentence": "Ví dụ",
    "pronunciation_guide": "Hướng dẫn phát âm",
    "word_type": "Loại từ",
}

CHAT_REQUIRED_FIELDS = {
    "topic": "Chủ đề",
    "intent_type": "Kiểu nhận diện: action/object/other",
    "english_term": "Từ tiếng Anh chính",
    "phonetic": "Phiên âm",
    "vietnamese_meaning": "Nghĩa tiếng Việt",
    "example_sentence": "Câu ví dụ",
    "response": "Câu trả lời thân thiện cho người học",
}

ALLOWED_TOPICS = [
    "Electronics",
    "Furniture",
    "Animals",
    "Nature",
    "Technology",
    "Learning",
    "Food",
    "Vehicles",
    "Household Items",
]

TOPIC_SYNONYMS: Dict[str, str] = {
    "electronics": "Electronics",
    "electronic": "Electronics",
    "furniture": "Furniture",
    "animal": "Animals",
    "animals": "Animals",
    "nature": "Nature",
    "technology": "Technology",
    "tech": "Technology",
    "learning": "Learning",
    "education": "Learning",
    "food": "Food",
    "vehicle": "Vehicles",
    "vehicles": "Vehicles",
    "transport": "Vehicles",
    "transportation": "Vehicles",
    "household": "Household Items",
    "household items": "Household Items",
    "home": "Household Items",
    "home items": "Household Items",
}

TOPIC_KEYWORDS: Dict[str, List[str]] = {
    "Electronics": [
        r"\b(earbuds?|headphones?|airpods?|speaker|tv|monitor|camera|phone|smartphone|tablet|laptop|charger|power bank)\b",
    ],
    "Furniture": [
        r"\b(table|desk|chair|sofa|bed|wardrobe|cabinet|shelf|bookshelf|drawer)\b",
    ],
    "Animals": [
        r"\b(dog|cat|bird|fish|horse|cow|pig|rabbit|lion|tiger|elephant|monkey)\b",
    ],
    "Nature": [
        r"\b(tree|flower|river|mountain|forest|leaf|grass|sun|moon|cloud|rain|ocean|beach)\b",
    ],
    "Technology": [
        r"\b(software|hardware|app|application|code|coding|programming|algorithm|ai|robot|server|database|api)\b",
    ],
    "Learning": [
        r"\b(book|notebook|lesson|class|student|teacher|school|university|study|learn|learning|homework|exam|pen|pencil)\b",
    ],
    "Food": [
        r"\b(food|meal|rice|bread|noodle|noodles|pizza|burger|cake|fruit|vegetable|meat|drink|water|coffee|tea)\b",
    ],
    "Vehicles": [
        r"\b(car|bus|truck|motorbike|motorcycle|bike|bicycle|train|plane|airplane|airport|ship|boat|scooter)\b",
    ],
    "Household Items": [
        r"\b(cup|bottle|plate|spoon|fork|knife|bowl|toothbrush|towel|blanket|pillow|lamp|fan|remote|basket|case)\b",
    ],
}

GENERALIZATION_RULES: Dict[str, str] = {
    r"\b(dell|hp|lenovo|acer|asus|macbook)\b": "laptop",
    r"\b(iphone|samsung|oppo|xiaomi|vivo|pixel)\b": "smartphone",
    r"\b(nike|adidas|puma|reebok|new balance)\b": "shoes",
    r"\b(canon|nikon|sony|fujifilm)\b": "camera",
    r"\b(bmw|mercedes|audi|toyota|honda)\b": "car",
}

VISION_PROMPT = """
Bạn là trợ lý học từ vựng tiếng Anh có khả năng thị giác máy tính tinh bén. 
Vui lòng nhận diện RÕ RÀNG và CHÍNH XÁC NHẤT đối tượng chính trong ảnh, sau đó trả về DUY NHẤT một JSON hợp lệ gồm đúng các trường sau:
{
  "topic": string,
  "word": string,
  "phonetic": string,
  "vietnamese_meaning": string,
  "example_sentence": string,
  "pronunciation_guide": string,
  "word_type": string
}
Quy tắc quan trọng:
- "word" phải là tên loại/nhóm chung phổ biến nhất (ví dụ: ảnh 1 chiếc macbook -> laptop, chó golden -> dog). KHÔNG trả về tên thương hiệu, tên riêng.
- Phân loại RẤT CHÍNH XÁC trường "topic", BẮT BUỘC phải là một trong 9 từ khóa tiếng Anh sau: Electronics, Furniture, Animals, Nature, Technology, Learning, Food, Vehicles, Household Items.
- Không thêm bất kỳ ký tự hay chú thích nào ngoài JSON hợp lệ.
""".strip()

CHAT_PROMPT = """
Bạn là gia sư tiếng Anh vui tính cho người Việt.
Nhiệm vụ của bạn là trò chuyện, thấu hiểu ngữ cảnh và phản hồi tự nhiên.

ĐẶC BIỆT - CHẾ ĐỘ ĐỐ VUI & ÔN TẬP:
- Dựa vào danh sách từ người dùng đã quét (được cung cấp), bạn có thể gợi chuyện ôn tập kiến thức chuyên sâu.
- Bạn CÓ THỂ GỢI Ý 1 TỪ MỚI (chưa quét): Hãy đưa ra manh mối (hint) vui nhộn và đố người dùng đoán tên đồ vật/động vật đó.
- Nếu người dùng trả lời đúng câu đố, hãy chúc mừng thật nhiệt tình và BẮT BUỘC NHẮC NHỞ: "Đừng quên chụp ảnh để quét và lưu vào bộ sưu tập khi bạn vô tình gặp nó ngoài đời nhé!"

Chỉ hỗ trợ 9 chủ đề: Electronics, Furniture, Animals, Nature, Technology, Learning, Food, Vehicles, Household Items.
Hãy trả về DUY NHẤT một JSON hợp lệ với đúng các trường:
{
    "topic": string,
    "intent_type": "action" | "object" | "other",
    "english_term": string,
    "phonetic": string,
    "vietnamese_meaning": string,
    "example_sentence": string,
    "response": string
}
Yêu cầu:
- Hỏi han, đố vui, chúc mừng -> intent_type="other". Câu đố hoặc lời chúc mừng nằm trọn trong "response".
- Mô tả hành động -> intent_type="action". Mô tả đồ vật -> intent_type="object". Trò chuyện ngữ cảnh trước trong "response".
- "topic" BẮT BUỘC TRẢ VỀ TỪ KHÓA TIẾNG ANH CHUẨN từ 9 chủ đề trên. Nếu là hội thoại "other" ngoài lề, trả về "".
- Không đưa ký hiệu IPA trực tiếp vào "response", chỉ để trong trường "phonetic".
- Cấm thêm văn bản nào ngoài JSON hợp lệ.
""".strip()


class ChatMessage(BaseModel):
    role: str = Field(..., description="user hoac assistant")
    content: str


class ChatRequest(BaseModel):
    message: str
    history: List[ChatMessage] = Field(default_factory=list)
    learned_words: List[str] = Field(default_factory=list)
    unscanned_words: List[str] = Field(default_factory=list)


class ChatResponseData(BaseModel):
    topic: str
    intent_type: str
    english_term: str
    phonetic: str
    vietnamese_meaning: str
    example_sentence: str
    response: str



def get_groq_client() -> Groq:
    api_key = os.getenv("GROQ_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="Chưa cấu hình GROQ_API_KEY trong môi trường.",
        )
    return Groq(api_key=api_key)



def encode_image(image_bytes: bytes) -> str:
    return base64.b64encode(image_bytes).decode("utf-8")



def preprocess_image(image_bytes: bytes) -> str:
    try:
        img = Image.open(BytesIO(image_bytes))
        img = img.convert("RGB")
        img.thumbnail((640, 640), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=85)
        return encode_image(buffer.getvalue())
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Ảnh không hợp lệ: {exc}")



def build_vision_messages(base64_image: str) -> List[Dict[str, Any]]:
    return [
        {"role": "system", "content": VISION_PROMPT},
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "Phân tích ảnh và trả kết quả đúng format JSON đã mô tả.",
                },
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"},
                },
            ],
        },
    ]



def build_chat_messages(request: ChatRequest) -> List[Dict[str, str]]:
    system_content = CHAT_PROMPT
    if request.learned_words:
        system_content += f"\n\n[THÔNG TIN THÔNG MINH] Danh sách từ vựng người dùng ĐÃ QUÉT/HỌC thành công: {', '.join(request.learned_words)}."
    if request.unscanned_words:
        preview = request.unscanned_words[:120]
        system_content += (
            "\n\n[THÔNG TIN THÔNG MINH] Danh sách từ vựng người dùng CHƯA QUÉT: "
            f"{', '.join(preview)}."
            "\nKhi đố vui, ưu tiên chọn từ trong danh sách CHƯA QUÉT để người dùng có thể đi quét thật ngoài đời."
        )

    messages: List[Dict[str, str]] = [{"role": "system", "content": system_content}]

    # Lấy 6 tin nhắn gần nhất
    history_slice = request.history[-6:]
    
    # Llama/Groq yêu cầu nghiêm ngặt: tin nhắn đầu tiên sau 'system' KHÔNG được là 'assistant'
    while history_slice and history_slice[0].role != "user":
        history_slice.pop(0)

    for item in history_slice:
        role = "assistant" if item.role == "assistant" else "user"
        # Bỏ qua nếu 2 tin nhắn liên tiếp trùng role (Llama sẽ báo lỗi 400 Bad Request nếu không luân phiên)
        if len(messages) > 1 and messages[-1]["role"] == role:
            messages[-1]["content"] += f"\n{item.content}"
        else:
            messages.append({"role": role, "content": item.content})

    # Thêm tin nhắn hiện tại của người dùng (tránh trùng role user ở cuối)
    if len(messages) > 1 and messages[-1]["role"] == "user":
        messages[-1]["content"] += f"\n{request.message}"
    else:
        messages.append({"role": "user", "content": request.message})
        
    return messages



def generalize_word(word: str) -> str:
    normalized = word.strip().lower()
    for pattern, generic in GENERALIZATION_RULES.items():
        if re.search(pattern, normalized):
            return generic
    return word



def _extract_json(raw_content: str) -> Dict[str, Any]:
    content = raw_content.strip()
    match = re.search(r"\{.*\}", content, re.DOTALL)
    if match:
        content = match.group(0)
    return json.loads(content)


def _normalize_topic(raw_topic: str) -> Optional[str]:
    key = raw_topic.strip().lower()
    if not key:
        return None
    if key in TOPIC_SYNONYMS:
        return TOPIC_SYNONYMS[key]
    for topic in ALLOWED_TOPICS:
        if key == topic.lower():
            return topic
    return None


def _infer_topic(*texts: str) -> Optional[str]:
    merged = " ".join((text or "").lower() for text in texts).strip()
    if not merged:
        return None
    for topic in ALLOWED_TOPICS:
        patterns = TOPIC_KEYWORDS.get(topic, [])
        for pattern in patterns:
            if re.search(pattern, merged):
                return topic
    return None


def _coerce_topic(raw_topic: str, *context_texts: str) -> str:
    normalized = _normalize_topic(raw_topic)
    if normalized:
        return normalized
    inferred = _infer_topic(*context_texts)
    if inferred:
        return inferred
    return "Learning"



def validate_analysis(payload: Dict[str, Any]) -> Dict[str, Any]:
    # Nếu AI thiếu trả về khóa, tự động gán rỗng để tránh lỗi 502
    for field in REQUIRED_FIELDS:
        if field not in payload:
            payload[field] = ""

    payload["word"] = generalize_word(str(payload["word"]))
    payload["topic"] = _coerce_topic(
        str(payload.get("topic", "")),
        str(payload.get("word", "")),
        str(payload.get("vietnamese_meaning", "")),
        str(payload.get("example_sentence", "")),
    )
    return payload



def validate_chat_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    # Nếu AI thiếu trả về khóa, tự động gán rỗng để tránh lỗi 502
    for field in CHAT_REQUIRED_FIELDS:
        if field not in payload:
            payload[field] = ""

    intent = str(payload.get("intent_type", "other")).strip().lower()
    if intent not in {"action", "object", "other"}:
        payload["intent_type"] = "other"
    else:
        payload["intent_type"] = intent

    payload["english_term"] = str(payload.get("english_term", "")).strip()
    payload["phonetic"] = str(payload.get("phonetic", "")).strip()
    payload["vietnamese_meaning"] = str(payload.get("vietnamese_meaning", "")).strip()
    payload["example_sentence"] = str(payload.get("example_sentence", "")).strip()
    payload["response"] = str(payload.get("response", "")).strip()
    payload["topic"] = _coerce_topic(
        str(payload.get("topic", "")),
        payload["english_term"],
        payload["vietnamese_meaning"],
        payload["example_sentence"],
        payload["response"],
    )

    if not payload["response"]:
        raise HTTPException(status_code=502, detail="Groq thiếu nội dung response")

    return payload


async def call_groq_vision(base64_image: str) -> Dict[str, Any]:
    client = get_groq_client()

    def _request() -> Dict[str, Any]:
        completion = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=build_vision_messages(base64_image),
            temperature=0.35,
            max_tokens=512,
            top_p=1,
            stream=False,
        )

        raw_content = completion.choices[0].message.content or "{}"
        payload = _extract_json(raw_content)
        return validate_analysis(payload)

    try:
        return await run_in_threadpool(_request)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail=f"Groq trả về JSON không hợp lệ: {exc}")
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Lỗi gọi Groq Vision API: {exc}")
        raise HTTPException(status_code=502, detail=f"Groq lỗi: {exc}")


async def call_groq_chat(request: ChatRequest) -> Dict[str, Any]:
    client = get_groq_client()

    def _request() -> Dict[str, Any]:
        completion = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=build_chat_messages(request),
            temperature=0.45,
            max_tokens=420,
            top_p=1,
            stream=False,
        )

        raw_content = completion.choices[0].message.content or "{}"
        payload = _extract_json(raw_content)
        return validate_chat_payload(payload)

    try:
        return await run_in_threadpool(_request)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail=f"Groq trả về JSON chat không hợp lệ: {exc}")
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Lỗi gọi Groq Chat API: {exc}")
        raise HTTPException(status_code=502, detail=f"Groq chat lỗi: {exc}")


async def process_image_upload(file: UploadFile) -> Dict[str, Any]:
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="File ảnh rỗng.")

    base64_image = preprocess_image(contents)
    analysis = await call_groq_vision(base64_image)
    return {
        "status": "success",
        "data": analysis,
        "message": "Image analysis completed successfully",
    }


@health_router.get("")
async def health_check():
    return {"status": "ok"}


@vision_router.post("/analyze-image")
async def analyze_image(file: UploadFile = File(...)):
    return await process_image_upload(file)


@app.post("/analyze-image", include_in_schema=False)
async def analyze_image_legacy(file: UploadFile = File(...)):
    return await process_image_upload(file)


@chat_router.post("/respond")
async def chat_respond(request: ChatRequest):
    if not request.message.strip():
        raise HTTPException(status_code=400, detail="Message rong")

    data = await call_groq_chat(request)
    return {
        "status": "success",
        "data": ChatResponseData(**data).model_dump(),
        "message": "Chat completed successfully",
    }


@app.post("/chat", include_in_schema=False)
async def chat_legacy(request: ChatRequest):
    data = await call_groq_chat(request)
    return {"status": "success", "data": data, "message": "Chat completed successfully"}


app.include_router(health_router)
app.include_router(vision_router)
app.include_router(chat_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
